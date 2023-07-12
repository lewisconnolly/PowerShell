#Requires -Modules 'VMware.VimAutomation.Core', 'VMware.VimAutomation.Storage'

<#
.SYNOPSIS
    Get the SPBM storage policy config for a VM and all of its disks
.DESCRIPTION
    Get the SPBM storage policy on a VM and all of its disks via the pipeline or using the VM parameter
    Accepts VM names (strings) and VM objects
.PARAMETER VM
    The VM(s) to get config of. Provide as VM objects or names (strings)
.OUTPUTS
    Custom object of VM storage policy configuration
.EXAMPLE    
    Get-VM MyVM | Get-VMStoragePolicy
.EXAMPLE
    Get-VMStoragePolicy -VM MyVM
.EXAMPLE
    # Verbose logging    
    
    Get-VM MyVM | Get-VMStoragePolicy -Verbose
.EXAMPLE
    # View disks config    

    Get-VM MyVM | Get-VMStoragePolicy | select DisksConfig
.EXAMPLE
    $vms = Get-VM MyVM1, MyVM2, MyVM3
    
    $vms | Get-VMStoragePolicy
.NOTES
#>
function Get-VMStoragePolicy {
    [CmdletBinding()]
    [Alias()]    
    [OutputType([PSCustomObject[]])]
    Param (                                                  
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            # Accept input VM as a string, as output from Get-VM/other VM object returning commands, and from Get-VMStoragePolicy via the VM property name in its output objects
            ($_ -is [String]) -or
            ($_ -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]) -or
            ($_.VM -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine])
        })]
        $VM


    )
    
    Begin {

        # Check a vCenter is connected
        if(!$global:DefaultVIServer){
            "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) No connected VIServers" | Write-Warning

            $VIServer = 'vcenter.zonalconnect.local'

            while($confirm -notin @('y','n')){
                $confirm = Read-Host -Prompt "`nAttempt to connect to $VIServer ? [y/n]`n"                

                # Warn on invalid input        
                if(!$confirm -or ($confirm -notin @('y','n'))){ "Invalid input, enter y or n" | Write-Warning } 
            }

            if($confirm -eq 'n'){
                "`n$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Exiting ..." | Write-Host
                $exit = $true
                return
            } else {
                "`n$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Connecting to $VIServer . Enter your credential ..." | Write-Host
                Connect-VIServer $VIServer | Out-Null
            }
        }
    }
    
    Process {                    
        
        if($exit){ return }        
        
        $VM | % {            
            if($_ -is [String]){
                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting VM(s) from string pattern `"$_`"" | Write-Verbose
                $curVM = Get-VM -Name $_
            # If VM input as VM object assign to $curVM
            }elseif($_ -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]){
                $curVM = $_
            # If VM input as object with VM property then assign value of said property to $curVM
            # (Parameter binder doesn't bind value from property name to $VM (parameter name) when using validate script and instead binds whole object to $VM)
            }else{
                $curVM = $_.VM
            }
            
            # Nested for-each loop to handle case where value provided for $VM parameter is string pattern (e.g. "lc-test*") that causes $curVM to be an array of VMs
            $curVM | % { 
                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting SpbmEntityConfiguration of $( $_.Name ) config vVol" | Write-Verbose
                $vmSpbmEntityConfig = $_ | Get-SpbmEntityConfiguration

                "$( Get-Date -Format 'dd/MM/yyyy HH:mm:ss' ) Getting SpbmEntityConfiguration of $( $_.Name ) disk vVol(s)" | Write-Verbose
                $disksSpbmEntityConfig = $_ | Get-HardDisk | Get-SpbmEntityConfiguration

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
        }
    }
}