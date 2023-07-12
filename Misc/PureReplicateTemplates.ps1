$ErrorActionPreference = 'Stop'
Import-Module VMware.PowerCLI | Out-Null
Import-Module PureStoragePowerShellSDK | Out-Null

$templateDsName = 'STORE'

$user = Read-Host -Prompt 'Enter zonalconnect username'
$pw = Read-Host -AsSecureString -Prompt 'Enter zonalconnect password'
$cred = New-Object System.Management.Automation.PSCredential ($user, $pw)

if(-not$global:DefaultVIServer){
    
    "Connecting to vcenter ..." | Write-Host
    
    Connect-VIServer vcenter -Credential $cred | Out-Null
}

"Connecting to dca-flasharray2 ..." | Write-Host

$fa2 = New-PfaArray -EndPoint dca-flasharray2 -UserName $user -Password $pw -IgnoreCertificateError

"Connecting to dcb-flasharray1 ..." | Write-Host

$dcbfa = New-PfaArray -EndPoint dcb-flasharray1 -UserName $user -Password $pw -IgnoreCertificateError

"Checking templates not in use in DCB before replication ..." | Write-Host

# Get registered DCB templates that are in VM state

$dcbTemplateVMs = Get-Datastore $templateDsName -Location DCB | Get-VM | ? {($_.ExtensionData.LayoutEx.File[0].Name -split '/')[0] -eq "[$templateDsName] Templates"}
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()    

while($dcbTemplateVMs -and $stopwatch.IsRunning){
    
    "DCB $templateDsName templates are in VM state. Waiting for them to be converted to templates to start replication ..." | Write-Warning
    
    if($stopwatch.Elapsed.TotalSeconds -ge 120){
        
        "It has been at least 120 seconds. Confirm if you want to convert DCB $templateDsName template VMs to templates" | Write-Host
        
        Get-Datastore $templateDsName -Location DCB | Get-VM | ? {($_.ExtensionData.LayoutEx.File[0].Name -split '/')[0] -eq "[$templateDsName] Templates"} |
        Set-VM -ToTemplate -Confirm:1                
        
        $stopwatch.Stop()
    }

    sleep 5

    $dcbTemplateVMs = Get-Datastore $templateDsName -Location DCB | Get-VM | ? {($_.ExtensionData.LayoutEx.File[0].Name -split '/')[0] -eq "[$templateDsName] Templates"}    
}

# Check if templates not converted

if(Get-VM -Id $dcbTemplateVMs.Id -ErrorAction Ignore){
    
    "DCB templates are still in VM state. Exiting ..." | Write-Warning
    
    return
}

# Check for unexpected VMs

if(Get-Datastore $templateDsName | Get-VM){

    "There are registered VMs on DCB $templateDsName not in the expected Templates folder" | Write-Host
    "Confirm their deregistration or script will exit" | Write-Host

    while($confirm -notin @('y','n')){
        $confirm = Read-Host -Prompt 'Deregister?'
       
        # Warn on invalid input
    
        if(!$confirm -or ($confirm -notin @('y','n'))){ "Invalid input, enter y or n" | Write-Warning } 
    }

    if($confirm -ne 'y'){ return }
}

# Check for unexpected templates

$confirm = ''
$otherTemplates = Get-Datastore $templateDsName -Location DCB | Get-Template | ? {($_.ExtensionData.LayoutEx.File[0].Name -split '/')[0] -ne "[$templateDsName] Templates"}

if($otherTemplates){

    "There are registered templates on DCB $templateDsName not in the expected Templates folder" | Write-Host
    "Confirm their deregistration or script will exit" | Write-Host
    
    while($confirm -notin @('y','n')){
        $confirm = Read-Host -Prompt 'Deregister?'
       
        # Warn on invalid input
    
        if(!$confirm -or ($confirm -notin @('y','n'))){ "Invalid input, enter y or n" | Write-Warning } 
    }
    
    if($confirm -ne 'y'){ return }
}

# Check if templates have associated tasks running

$dcbTemplateIds = (Get-Datastore $templateDsName -Location DCB | Get-Template).Id
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

while(Get-Task -Server vcenter | ? Name -eq 'CloneVM_Task' | ? ObjectId -in $dcbTemplateIds | ? State -ne 'Success'){
    
    "DCB $templateDsName templates are currently being used to create VMs. Waiting for tasks to complete to start replication ..." | Write-Warning
    
    if($stopwatch.Elapsed.TotalSeconds -ge 600){
        
        "It has been at least 600 seconds and templates are still in use. Try again when tasks finish. Exiting ... " | Write-Warning
        
        $stopwatch.Stop()
        
        return
    }

    sleep 5
}

$stopwatch.Stop()

# Get paths of remaining registered VMs and templates then remove

$dcbVmxFileRegPaths = @()

if((Get-Datastore $templateDsName -Location DCB | Get-Template) -or (Get-Datastore $templateDsName -Location DCB | Get-VM)){    
    
    Get-Datastore $templateDsName -Location DCB | Get-Template | % { $dcbVmxFileRegPaths += $_.ExtensionData.LayoutEx.File[0].Name }
    Get-Datastore $templateDsName -Location DCB | Get-VM | % { $dcbVmxFileRegPaths += $_.ExtensionData.LayoutEx.File[0].Name }
    
    "Removing DCB $templateDsName VMs and templates from inventory ..." | Write-Host

    Get-Datastore $templateDsName -Location DCB | Get-Template | Remove-Template -Confirm:0 | Out-Null
    Get-Datastore $templateDsName -Location DCB | Get-VM | Remove-Template -Confirm:0 | Out-Null
}

# Check VMs and templates were removed successfully and no tasks have been kicked off since last check

if(-not
    (
        (Get-Datastore $templateDsName -Location DCB | Get-VM) `
        -or
        (Get-Datastore $templateDsName -Location DCB | Get-Template) `
        -or
        (Get-Task -Server vcenter | ? Name -eq 'CloneVM_Task' | ? ObjectId -in $dcbTemplateIds | ? State -ne 'Success')
    )
){

    Read-Host -Prompt "Confirm no DCB $templateDsName templates are currently being used to create VMs then press any key to continue or Ctrl+C to exit"
    
    $ds = Get-Datastore $templateDsName -Location DCB 
    $dsUuid = $ds.ExtensionData.Info.Vmfs.Uuid
    
    Get-VMHost -Location DCB | % {
    
        $vmhost = $_

        if(($ds.ExtensionData.Host | ? Key -eq $vmhost.id).MountInfo.Mounted){
            
            "Unmounting " + $ds.Name + " from " + $vmhost.Name + " ..." | Write-Host

            $storageSystem = Get-View $_.ExtensionData.ConfigManager.StorageSystem 
            $storageSystem.UnmountVmfsVolume($dsUuid)
        }

        "Removing DCB $templateDsName ..." | Write-Host

        $_ | Get-VMHostStorage -RescanAllHba -RescanVmfs -Refresh | Out-Null
    }

    if(-not(Get-Datastore $templateDsName -Location DCB -ErrorAction Ignore)){
        
        "Creating new $templateDsName snapshot and replicating to dcb-flasharray1 ..." | Write-Host
        
        $newPgSnap = New-PfaProtectionGroupSnapshot -Array $fa2 -Protectiongroupname 'Templates-ReplOnDemand-NoSnap' -ReplicateNow -ApplyRetention
        $newPgSnapOnTgt = Get-PfaProtectionGroupSnapshots -Array $dcbfa -Name 'dca-flasharray2:Templates-ReplOnDemand-NoSnap' | ? Name -eq "dca-flasharray2:$( $newPgSnap.name )"

        do {
            "Waiting on new snapshot to finish replicating ..." | Write-Host
            sleep 5
        } until((Get-PfaProtectionGroupSnapshotReplicationStatus -Array $dcbfa -Name $newPgSnapOnTgt.name).progress -eq 1.0)

        $source = Get-PfaProtectionGroupVolumeSnapshots -Array $dcbfa -Name 'dca-flasharray2:Templates-ReplOnDemand-NoSnap'  | select -Last 1

        "$templateDsName snapshot replicated to dcb-flasharray1:" | Write-Host
        $source

        "Overwriting dcb-flasharray1 $templateDsName with snapshot ...`n" | Write-Host

        New-PfaVolume -Array $dcbfa -VolumeName $templateDsName -Source $source.name -Overwrite

        "Rescanning DCB hosts' storage adapters ..." | Write-Host

        Get-VMHost -Location DCB | % {            
            $_ | Get-VMHostStorage -RescanAllHba -RescanVmfs -Refresh | Out-Null
        }

        Get-VMHost -Location DCB | % {
            
            $esxcli = $_ | Get-EsxCli -V2 
            
            "Mounting DCB $templateDsName volume to " + $_.Name + ' ...'
            
            $esxcli.storage.vmfs.snapshot.mount.Invoke(@{'volumelabel'=$templateDsName}) | Out-Null
        }

        "Waiting for $templateDsName to be mounted on all hosts..." | Write-Host
        sleep 300

        if(Get-Datastore $templateDsName -Location DCB -ErrorAction Ignore){
            
            if($dcbVmxFileRegPaths){
                
                $dcbHosts = Get-VMHost -Location DCB | sort Name
                
                "Re-adding DCB $templateDsName children to inventory ..." | Write-Host

                $dcbVmxFileRegPaths | % {
                    if($_ -like "*.vmtx"){ New-Template -TemplateFilePath $_ -Location (Get-Folder Templates -Location DCB) -VMHost $dcbHosts[0]}
                    if($_ -like "*.vmx"){ New-VM -VMFilePath $_ -Location (Get-Folder Templates -Location DCB) -VMHost $dcbHosts[0]}
                }

                "Regenerating UUIDs on newly replicated DCB $templateDsName children ...`n" | Write-Host
                
                Get-Datastore $templateDsName -Location DCB | Get-Template | % {

                    $vm = $_ | Set-Template -ToVM
                    $newUuid = ([guid]::NewGuid()).guid
                    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                    $spec.uuid = $newUuid    
                    $vm.ExtensionData.ReconfigVM_Task($spec)
                    $vm | Set-VM -ToTemplate -Confirm:0 | Out-Null
                }

                Get-Datastore $templateDsName -Location DCB | Get-VM | % {
                
                    $newUuid = ([guid]::NewGuid()).guid
                    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                    $spec.uuid = $newUuid    
                    $vm.ExtensionData.ReconfigVM_Task($spec)
                }
            }
        } else { "Failed to mount DCB $templateDsName. Exiting ..." | Write-Warning }
    } else { "Failed to remove DCB $templateDsName. Exiting ..." | Write-Warning }
} else { "Unable to remove all VMs and templates from $templateDsName or templates currently have associated tasks running. Exiting ..." | Write-Warning } 