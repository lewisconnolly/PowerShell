#Requires -Modules 'VMware.VimAutomation.Core', 'VMware.VimAutomation.Storage'

<#
.SYNOPSIS
    Set the SPBM storage policy on a VM and all of its disks
.DESCRIPTION
    Set the SPBM storage policy on a VM and all of its disks via the pipeline or using the VM parameter
    Accepts VM names (strings), VM objects and output from Get-VMStoragePolicy as inputs
.PARAMETER VM
    The VM(s) to change policies of. Provide as VM objects, names (strings), or Get-VMStoragePolicy objects.
    If not passed via pipeline then it must be a named parameter
.PARAMETER StoragePolicy
    The policy to set on VM(s) and disks. Provide as Get-SpbmStoragePolicy object or policy name (string)
.OUTPUTS
    Custom object of VM storage policy configuration
.EXAMPLE    
    Get-VM MyVM1 | Set-VMStoragePolicy MyPolicy
.EXAMPLE    
    # Preview action    
    
    Get-VM MyVM1, MyVM2 | Set-VMStoragePolicy MyPolicy -WhatIf
.EXAMPLE    
    # Confirm action    
    
    Get-VM MyVM1 | Set-VMStoragePolicy MyPolicy -Confirm:$true
.EXAMPLE    
    # Verbose logging    
    
    Get-VM MyVM1 | Set-VMStoragePolicy MyPolicy -Verbose
.EXAMPLE
    Set-VMStoragePolicy -VM MyVM1 -StoragePolicy MyPolicy
.EXAMPLE
    Set-VMStoragePolicy MyPolicy -VM MyVM1, MyVM2
.EXAMPLE
    Get-VMStoragePolicy MyVM1 | Set-VMStoragePolicy MyPolicy
.EXAMPLE
    $vmPolicyConfig = Get-VM MyVM1, MyVM2, MyVM3 | Get-VMStoragePolicy

    $vmPolicyConfig | Set-VMStoragePolicy MyPolicy
.EXAMPLE
    Set-VMStoragePolicy -VM MyVM* -StoragePolicy MyPolicy
.EXAMPLE
    $vms = Get-VM MyVM1, MyVM2, MyVM3
    $policy = Get-SpbmStoragePolicy MyPolicy
    
    Set-VMStoragePolicy $policy -VM $vms
.NOTES
#>
function Set-VMStoragePolicy {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [Alias()]    
    [OutputType([PSCustomObject[]])]
    Param (                                                  
        [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            # Accept input VM as a string, as output from Get-VM/other VM object returning commands, and from Get-VMStoragePolicy via the VM property name in its output objects
            ($_ -is [String]) -or
            ($_ -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]) -or
            ($_.VM -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine])
        })]        
        $VM,
        
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            ($_ -is [String]) -or
            ($_ -is [VMware.VimAutomation.Storage.Types.V1.Spbm.SpbmStoragePolicy])
        })]
        $StoragePolicy
    )
    
    Begin {

        # Check a vCenter is connected
        if(!$global:DefaultVIServer){
            "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) No connected VIServers" | Write-Warning

            $VIServer = 'vcenter'

            while($confirm -notin @('y','n')){
                $confirm = Read-Host -Prompt "`nAttempt to connect to $VIServer ? [y/n]`n"                

                # Warn on invalid input        
                if(!$confirm -or ($confirm -notin @('y','n'))){ "Invalid input, enter y or n" | Write-Warning } 
            }

            if($confirm -eq 'n'){
                "`n$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Exiting" | Write-Host
                $exit = $true
                return
            } else {
                "`n$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Connecting to $VIServer . Enter your credential" | Write-Host
                Connect-VIServer $VIServer | Out-Null
            }
        }
        
        # Check storage policy exists
        "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Checking storage policy exists in connected servers" | Write-Verbose
        if($verifiedPolicy = Get-SpbmStoragePolicy $StoragePolicy){
            if(Get-SpbmCompatibleStorage -StoragePolicy $verifiedPolicy){                

                # Get datastores and key by ID
                $datastores = @{}
                
                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting datastores and IDs" | Write-Verbose
                Get-Datastore | % { $datastores[$_.Id] = $_ }

                # If policy has a protection group requirement, find the matching SpbmReplicationGroups
                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Checking if storage policy has Pure Storage Protection Group requirement" | Write-Verbose
                if($verifiedPolicy.AnyOfRuleSets.AllOfRules.Capability.Name -contains 'com.purestorage.storage.replication.ReplicationConsistencyGroup'){
                    # Get replication groups
                    "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting SpbmReplicationGroups that comply with policy" | Write-Verbose
                    $groups = Get-SpbmReplicationGroup -StoragePolicy $verifiedPolicy

                    if(-not$groups){
                        Write-Error -Message "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) No matching SpbmReplicationGroups for $( $verifiedPolicy.Name ) could be found"
                        $exit = $true
                    }
                }
            }else{
                Write-Error -Message "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) No compatible storage for $( $verifiedPolicy.Name ) could be found"
                $exit = $true
            }
        }else{$exit = $true}
    }
    
    Process {                    
        
        if($exit){ return }          
        
        # For-each loop used to support passing arrays both via pipeline and not (Process block processes one object at a time when using pipeline and whole array when not)
        $VM | % {

            if($_ -is [String]){
                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting VM(s) from string pattern `"$_`"" | Write-Verbose
                $curVM = Get-VM -Name $_
            # If VM input as VM object assign to $curVM
            }elseif($_ -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]){
                $curVM = $_
            # If VM input as object with VM property then assign value of said property to $curVM
            # (Parameter binder doesn't bind value from property name to $VM (parameter name) when using ValidateScript and instead binds whole object to $VM)
            }else{
                $curVM = $_.VM
            }
            
            # Nested for-each loop to handle case where value provided for $VM parameter is string pattern (e.g. "lc-test*") that causes $curVM to be an array of VMs
            $curVM | % { 
                # Another VM variable is required to be set to $_ ($PSItem) in order to reference VM in catch block where $_ refers to the caught exception
                $catchBlockCurVM = $_
                $datastoreId = $_.DatastoreIdList
                
                if($datastores[$datastoreId].Type -eq 'VVOL'){                
                    if($PSCmdlet.ShouldProcess($_.Name, "Set SPBM storage policy of config vVol and disk vVol(s) to `"$( $verifiedPolicy.Name )`"")){
                        # Use try/catch block and -ErrorAction Stop on Set-SpbmEntityConfiguration commands to stop if there's an error setting configurations then get the current configurations in the catch block
                        try{
                            if($groups){
                                # Get replication group for array of VM
                                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting SpbmReplicationGroup that complies with policy for array of VM $( $_.Name )" | Write-Verbose
                                $group = $groups | ? {$_.FaultDomain.Name -eq $datastores[$datastoreId].ExtensionData.Info.VvolDS.StorageArray.Name}

                                if($group){                                
                                    "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Setting SpbmEntityConfiguration of $( $_.Name ) config vVol to selected policy and replication group" | Write-Verbose
                                    $vmSpbmEntityConfig = $_ | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $verifiedPolicy -ReplicationGroup $group -Confirm:0 -ErrorAction Stop

                                    "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Setting SpbmEntityConfiguration of $( $_.Name ) disk vVol(s) to selected policy and replication group" | Write-Verbose
                                    $disksSpbmEntityConfig = $_ | Get-HardDisk | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $verifiedPolicy -ReplicationGroup $group -Confirm:0 -ErrorAction Stop

                                }else{
                                    $storageArray = $datastores[$datastoreId].ExtensionData.Info.VvolDS.StorageArray.Name
                                    "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) No $storageArray SpbmReplicationGroup that satisfies Protection Group requirement of policy $( $verifiedPolicy.Name ) could be found. No action taken on $( $_.Name )" |
                                    Write-Warning

                                    "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting SpbmEntityConfiguration of $( $_.Name ) config vVol" | Write-Verbose
                                    $vmSpbmEntityConfig = $_ | Get-SpbmEntityConfiguration
                                    "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting SpbmEntityConfiguration of $( $_.Name ) disk vVol(s)" | Write-Verbose
                                    $disksSpbmEntityConfig = $_ | Get-HardDisk | Get-SpbmEntityConfiguration
                                }
                            } else {
                                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Setting SpbmEntityConfiguration of $( $_.Name ) config vVol to selected policy" | Write-Verbose
                                $vmSpbmEntityConfig = $_ | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $verifiedPolicy -Confirm:0 -ErrorAction Stop

                                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Setting SpbmEntityConfiguration of $( $_.Name ) disk vVol(s) to selected policy" | Write-Verbose
                                $disksSpbmEntityConfig = $_ | Get-HardDisk | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $verifiedPolicy -Confirm:0 -ErrorAction Stop
                            }
                        }catch{
                            "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) An error occurred setting SpbmEntityConfiguration of $( $_.Name ):" | Write-Host -ForegroundColor Red
                            $_ | Write-Host -ForegroundColor Red

                            "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting SpbmEntityConfiguration of $( $_.Name ) config vVol" | Write-Verbose
                            $vmSpbmEntityConfig = $catchBlockCurVM | Get-SpbmEntityConfiguration
                            "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting SpbmEntityConfiguration of $( $_.Name ) disk vVol(s)" | Write-Verbose
                            $disksSpbmEntityConfig = $catchBlockCurVM | Get-HardDisk | Get-SpbmEntityConfiguration
                        }                        
                                                
                        if($vmSpbmEntityConfig){                            
                            $disksConfig = @()
                            if($disksSpbmEntityConfig){                                
                                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Enumerating disk vVol SpbmEntityConfigurations" | Write-Verbose
                                $disksSpbmEntityConfig | % {
                                    $disksConfig +=
                                    [PSCustomObject]@{
                                        Disk = $_.Entity
                                        VMId = $_.Entity.ParentId
                                        StoragePolicy = $_.StoragePolicy
                                        ReplicationGroup = $_.ReplicationGroup
                                        ComplianceStatus = $_.ComplianceStatus
                                        TimeOfCheck = $_.TimeOfCheck
                                    }    
                                }
                            }

                            [PSCustomObject]@{
                                VM = $vmSpbmEntityConfig.Entity
                                StoragePolicy = $vmSpbmEntityConfig.StoragePolicy
                                ReplicationGroup = $vmSpbmEntityConfig.ReplicationGroup
                                ComplianceStatus = $vmSpbmEntityConfig.ComplianceStatus
                                TimeOfCheck = $vmSpbmEntityConfig.TimeOfCheck
                                DisksConfig = $disksConfig
                            }
                        }
                        
                        $vmSpbmEntityConfig = $disksSpbmEntityConfig = $null
                    }
                }else{ "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Skipping $( $_.Name ) because it is not a vVols VM" | Write-Warning }
            }
        }
    }
}