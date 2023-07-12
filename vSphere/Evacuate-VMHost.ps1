Function Evacuate-VMHost {

<#

.DESCRIPTION
    Used to patch the hosts in non-prod that don't have DRS to automate the process of evacuating the VMs.
    This function allows to evacuate the VMs on a host automatically and safely by taking into account available resources on other hosts.

.EXAMPLE
    Evacuate a host ESX1 interactively with interdication to move VMs to ESX2.
    PS C:\> Evacuate-VMHost -VMHost (Get-VMHost ESX1) -ExcludedVMHost (Get-VMHost ESX2)

.EXAMPLE
    Evacuate a host ESX1 automatically with interdiction to move VM1 and VM2.
    PS C:\> Evacuate-VMHost -VMHost (Get-VMHost ESX1) -ExcludedVM (Get-vm VM1,VM2) -fullyAutomated
        
.EXAMPLE
    Evacuate ESX1 more aggressively (more dangerous, usefull if short on resources)
    PS C:\> Evacuate-VMHost -VMHost (Get-VMHost ESX1) -VMHostMaxCPUUsagePercent 85 -VMHostMaxMEMUsagePercent 90 -VMHostMaxVCpuPerCore 12

.PARAMETER VMHost
    VMHost object (Get-VMHost XY).

.PARAMETER VMHostMaxCPUUsagePercent
    Percentage of expected CPU usage above which a host won't be selected as potential destination if reached.

.PARAMETER VMHostMaxMEMUsagePercent
    Percentage of expected memory usage above which a host won't be selected as potential destination if reached.

.PARAMETER VMHostMaxVCpuPerCore
    Number of vCPUs per physical cores above which a host won't be selected as potential destination if reached.

.PARAMETER ExcludedVMHost
    VMHost object. This (These) host(s) won't be selected as potential destination hosts.

.PARAMETER ExcludedVM
    VM object. This (These) VM(s) won't be migrated off the host.

.PARAMETER WithinCluster
    If set to true, hosts not in the cluster of the evacuated host will not be considered as destinations for evacuated VMs
    If set to false, hosts not in the cluster of the evacuated host will be considered as destinations for evacuated VMs

.PARAMETER FullyAutomated
    If set to true, automates the VM placement.
    If set to false, the choice is left to the user for every VM with a recommendation made by the script.    
#>

param (
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True)]
    [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
    $VMHost,

    [ValidateRange(1,100)]
    [int]
    $VMHostMaxCPUUsagePercent = 65,

    [ValidateRange(1,100)]
    [int]
    $VMHostMaxMEMUsagePercent = 75,

    [int]
    $VMHostMaxVCpuPerCore = 9,

    [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]
    $ExcludedVMHost,

    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $ExcludedVM,

    [switch]
    $WithinCluster,

    [switch]
    $fullyAutomated,

    [switch]
    $Whatif
)

Try {

    IF ($VMHost.connectionstate -eq "connected") {

    $VM = $VMHost | Get-VM | where powerstate -eq poweredon | where {$_ -notin $ExcludedVM}

        $VM | ForEach-Object {
        
            $a++

            Write-Progress -Activity "$($VMHost.name) evacuation" -Status "$a / $($VM.count) VM : $($_.name)" -PercentComplete (($a/$VM.count)*100) -Id 50

            IF ($WithinCluster) {
                IF ($VMHost | Get-Cluster) {
                    IF (Get-Cluster | where Id -ne ($VMHost | Get-Cluster).Id) {
                        $ExcludedVMHost += Get-Cluster | where Id -ne ($VMHost | Get-Cluster).Id | Get-VMHost
                    } ELSE {Write-Warning "-WithinCluster switch is not necessary when there is only one cluster"}
                } ELSE {Write-Warning "-WithinCluster switch was specified but $($VMHost.Name) does not belong to a cluster"}
            }

            IF ((get-view $_.ExtensionData.Datastore).summary.MultipleHostAccess) {
                
                $CurVM = $_

                $PossibleHost = Get-VMHost `
                    | where name -ne $VMHost.name `
                    | where {$_ -notin $ExcludedVMHost} `
                    | where connectionstate -eq "connected" `
                    | where {(Compare-Object $CurVM.ExtensionData.network.value $_.ExtensionData.network.value).sideindicator -notcontains "<="}

                $i = 0
                $choice = "a"

                $selectedVMHost = $PossibleHost | ForEach-Object {
            
                    $i++

                    $HostVM = $_ | get-vm | where powerstate -eq poweredon

                    [pscustomobject]@{
                        id = $i
                        name = $_.name
                        "ProjectedCpuUsage" = [math]::round(($_.CpuUsageMhz + $CurVM.ExtensionData.Runtime.MaxCpuUsage) / $_.CpuTotalMhz * 100,1)
                        "ProjectedMemUsage" = [math]::round(($_.MemoryUsageMB + $CurVM.memoryMB) / $_.MemoryTotalMB * 100,1)
                        "ProjectedVCPUperCORE" =[math]::round(($HostVM | Measure-Object -Property numcpu -Sum).sum / $_.NumCpu,1)
                        "Projected#LiveVM" = $HostVM.count + 1
                    }

                } | where {$_.ProjectedCpuUsage -lt $VMHostMaxCPUUsagePercent -and $_.ProjectedMemUsage -lt $VMHostMaxMEMUsagePercent -and $_.ProjectedVCPUperCORE -lt $VMHostMaxVCpuPerCore}

                IF ($selectedVMHost) {

                    $BestVMHost = $selectedVMHost | where id -eq ($selectedVMHost | select id,@{l="sum";e={$_.ProjectedCpuUsage + $_.ProjectedMemUsage}} | Sort-Object sum | select -First 1).id

                    ($selectedVMHost | where id -eq $BestVMHost.id).id = "*"

                    IF (!$fullyAutomated) {

                        Clear-Host

                        $_ | select name,powerstate,numcpu,memorygb
                
                        $selectedVMHost | Sort-Object id | ft -au

                        Write-Host "Select host manually by its ID"
                        Write-Host "Press enter to follow the recommendation ( * )"
                        Write-Host "Enter N to skip this VM"

                        While ($choice -notin @("","n") -and $choice -notin (1..$i)) { $choice = Read-Host " " }

                        IF (!$Choice) {$selectedVMHost = $BestVMHost}
                            ELSEIF ($choice -eq "n") {Write-Warning "$($CurVM.name) skipped"}
                                ELSE {$selectedVMHost = $selectedVMHost | where id -eq $Choice}

                    } ELSE {
                        $selectedVMHost = $BestVMHost
                    }

                    IF ($choice -ne "n") {

                        Write-Host "$($CurVM.name) moving to $($selectedVMHost.name)" -ForegroundColor green

                        $params = @{VM = $_ ; Destination = get-vmhost $selectedVMHost.name}

                        IF ($Whatif) {$params.Add('whatif', $true)}

                        Move-VM @params | Out-Null

                    }

                } ELSE {Write-Warning "There is no host capable of fulfilling the destination resource requirements for $($CurVM.name)"}

            } ELSE {Write-Warning "$($_.name) is on local storage"}

        }

        Write-Progress -Activity "$($VMHost.name) evacuation complete" -Completed -Id 50

    } ELSE {Write-warning "$($VMHost.name) is in a $($VMHost.connectionstate) state"}

} CATCH {
    Write-Error $_.Exception -ErrorAction stop
}

}
