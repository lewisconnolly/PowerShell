Function Get-AdmissionControlPercentage {

param(
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]
    $Cluster,
    [int]
    $FailuresToTolerate = 1
)

    if ($cluster.ExtensionData.Configuration.DasConfig.AdmissionControlPolicy.CpuFailoverResourcesPercent) {

        $VMHost = $Cluster | Get-VMHost

        $CPUCluster = $VMHost | Measure-Object -Property CpuTotalMhz -sum | select -ExpandProperty sum
        $MEMCluster = $VMHost | Measure-Object -Property memorytotalgb -sum | select -ExpandProperty sum

        $CPUReserve = $VMHost | Sort-Object -Property CpuTotalMhz | select -ExpandProperty CpuTotalMhz -last $FailuresToTolerate | Measure-Object -Sum | select -ExpandProperty sum
        $MEMReserve = $VMHost | Sort-Object -Property memorytotalgb | select -ExpandProperty memorytotalgb -last $FailuresToTolerate | Measure-Object -Sum | select -ExpandProperty sum

        $CPUPercentRecom = [math]::Ceiling($CPUReserve/$CPUCluster * 100)
        $MEMPercentRecom = [math]::Ceiling($MEMReserve/$MEMCluster * 100)
        $CPUPercentConfig = $cluster.ExtensionData.Configuration.DasConfig.AdmissionControlPolicy.CpuFailoverResourcesPercent
        $MEMPercentConfig = $cluster.ExtensionData.Configuration.DasConfig.AdmissionControlPolicy.MemoryFailoverResourcesPercent

        if ($CPUPercentConfig -ge $CPUPercentRecom -and $MEMPercentConfig -ge $MEMPercentRecom) {
            $HACompliant = $True
            if ($CPUPercentConfig -gt $CPUPercentRecom -or $MEMPercentConfig -gt $MEMPercentRecom) {
                $Optimized = $False
            } else {$Optimized = $True}

        } ELSE {
            $HACompliant = $False
            $Optimized = $False
        }

        [pscustomobject]@{
            CpuFailoverCapacityConfigured = $CPUPercentConfig
            MemoryFailoverCapacityConfigured = $MEMPercentConfig
            CpuFailoverCapacityRecommended = $CPUPercentRecom
            MemoryFailoverCapacityRecommended = $MEMPercentRecom
            CpuAvailableFailoverPercent = $Cluster.ExtensionData.Summary.AdmissionControlInfo.CurrentCpuFailoverResourcesPercent
            MemoryAvailableFailoverPercent = $Cluster.ExtensionData.Summary.AdmissionControlInfo.CurrentMemoryFailoverResourcesPercent
            HACompliant = $HACompliant
            Optimized = $Optimized
        }

    } else {Write-Warning "Admission control policy is not cluster percentage based"} 

}