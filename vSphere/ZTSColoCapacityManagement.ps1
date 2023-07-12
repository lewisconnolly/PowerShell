Set-ExecutionPolicy -Scope Process Bypass; Set-ExecutionPolicy -Scope LocalMachine Bypass
Connect-VIServer vcenter | Out-Null
$OMCred = Get-Credential -UserName 'lewisc@zonalconnect.local' -Message 'Enter password'
Connect-OMServer dcbutlprdvrops01 -Credential $OMCred | Out-Null
. "\\tsclient\C\Users\lewis\OneDrive\Documents\WindowsPowerShell\Modules\vSphereScripts\Get-VIFolderPath.ps1"
$ErrorActionPreference = 'Stop'
$month = 'June-23'
$infra = @()
$computeSubjects = @()
$storageSubjects = @()
$DRSubjects = @()
$failoverSubjects = @()
$backupSubjects = @()
$compSustainabilitySubjects = @()
$dcb = Get-Datacenter DCB | Get-VM | ? PowerState -eq 'PoweredOn'
$dcbReplicas = Get-Datacenter DCB | Get-VM | ? Name -Like "*_replica"
$saas = Get-Folder -Location DCA SaaS | Get-VM 
$aztec = Get-Folder Aztec -Location DCA | Get-VM | ? Name -NotMatch 'cdgt|mabprd|mabtst|stoprd|stotst|fultst|phdtst|rnktst'
$failoverVMs = $dcb + $dcbReplicas + $saas + $aztec
$cert = Get-ChildItem 'Cert:\CurrentUser\My\F210D90445B280430996B91B4C9C405954074FEB'
$pureOneApiId = Read-Host -Prompt 'Enter dcautlprdwrk01 Pure1 API ID'
$cert | New-PureOneRestConnection -pureAppID $pureOneApiId
$VMsToMeasure = Get-VM -Location DCA, DCB | ? PowerState -eq 'PoweredOn'
$VMStatTypes =
'cpu.usage.average', # CPU usage as a percentage during the interval
'cpu.usagemhz.average', # CPU usage, as measured in megahertz, during the interval
'disk.usage.average', # Aggregated disk I/O rate in KBps
'mem.usage.average', # Memory usage as percent of total configured or available memory. A value between 0 and 10,000 expressed as a hundredth of a percent (1 = 0.01%)
'mem.active.average' # Amount of memory that is actively used, as estimated by VMkernel based on recently touched memory pages, in KB
$allVMs = Get-VM -Location DCA, DCB
$AMDhost = Get-VMHost sg-b4-zhost17.zhost
$dcaHosts = Get-Cluster DCA* | Get-VMHost
$dcbHosts = Get-Cluster DCB* | Get-VMHost
$bigBlade = Get-VMHost mkhost6.zhost | select * -ExcludeProperty NumCpu | select *, @{n='NumCpu';e={18}}
$smallBlade = Get-VMHost mkhost2.zhost | select * -ExcludeProperty NumCpu | select *, @{n='NumCpu';e={18}}
$dcbFinal = $dcbHosts + $bigBlade + $bigBlade + $bigBlade + $bigBlade + $bigBlade + $bigBlade + $bigBlade + $bigBlade + $bigBlade + $bigBlade + $smallBlade + $smallBlade + $smallBlade + $smallBlade + $smallBlade + $smallBlade + $AMDhost + $AMDhost + $AMDhost
$dcaFinal = $dcaHosts
$repoInfo = Invoke-Command -ComputerName dcbutlprdvbs01 -ScriptBlock {
    Get-VBRBackupRepository | select Name,
    @{n='Size';e={$_.GetContainer().CachedTotalSpace.InBytes}},
    @{n='SizeRemaining';e={$_.GetContainer().CachedFreeSpace.InBytes}}
}

<# Infrastructure tab #>

$computeSubjects += [PSCustomObject]@{
    SubjectName = 'DCA'
    Subject = Get-Datacenter DCA
    VMs = Get-Datacenter DCA | Get-VM | ? PowerState -eq 'PoweredOn'
}

$computeSubjects += [PSCustomObject]@{
    SubjectName = 'DCB'
    Subject = Get-Datacenter DCB
    VMs = $dcb + $dcbReplicas
}

$computeSubjects += [PSCustomObject]@{
    SubjectName = 'DCA-Cluster'
    Subject = Get-Cluster DCA-Cluster
    VMs = Get-Cluster DCA-Cluster | Get-VM | ? PowerState -eq 'PoweredOn'
}

$computeSubjects += [PSCustomObject]@{
    SubjectName = 'DCA Final'    
    Subject = $dcaFinal
    VMs = Get-Datacenter DCA | Get-VM | ? PowerState -eq 'PoweredOn'
}

$computeSubjects += [PSCustomObject]@{
    SubjectName = 'DCB-ClusterIntel'
    Subject = Get-Cluster DCB-ClusterIntel
    VMs = Get-Cluster DCB-ClusterIntel | Get-VM | ? PowerState -eq 'PoweredOn'
}

$computeSubjects += [PSCustomObject]@{
    SubjectName = 'DCB-ClusterAMD'
    Subject = Get-Cluster DCB-ClusterAMD
    VMs = Get-Cluster DCB-ClusterAMD | Get-VM | ? PowerState -eq 'PoweredOn'
}

$computeSubjects += [PSCustomObject]@{
    SubjectName = 'DCB Final'    
    Subject = $dcbFinal
    VMs = $dcb + $dcbReplicas
}

$storageSubjects += [PSCustomObject]@{
    SubjectName = 'DCA'
    Subject = 'dca-flasharray1','dca-flasharray2','dca-flasharray3'
    VMs = Get-Datastore DCA-SSD*
}

$storageSubjects += [PSCustomObject]@{
    SubjectName = 'DCB'
    Subject = 'dcb-flasharray1','dcb-flasharray2'
    VMs = Get-Datastore DCB-SSD*
}

$storageSubjects += [PSCustomObject]@{
    SubjectName = 'dca-flasharray1'
    Subject = 'dca-flasharray1'
    VMs = Get-Datastore DCA-SSD*PURE1*
}

$storageSubjects += [PSCustomObject]@{
    SubjectName = 'dca-flasharray2'
    Subject = 'dca-flasharray2'
    VMs = Get-Datastore DCA-SSD*PURE2*
}

$storageSubjects += [PSCustomObject]@{
    SubjectName = 'dca-flasharray3'
    Subject = 'dca-flasharray3'
    VMs = Get-Datastore DCA-SSD*PURE3*
}

$storageSubjects += [PSCustomObject]@{
    SubjectName = 'dcb-flasharray1'
    Subject = 'dcb-flasharray1'
    VMs = Get-Datastore DCB-SSD*PURE1*
}

$storageSubjects += [PSCustomObject]@{
    SubjectName = 'dcb-flasharray2'
    Subject = 'dcb-flasharray2'
    VMs = Get-Datastore DCB-SSD*PURE2*
}

$DRSubjects += [PSCustomObject]@{
    SubjectName = 'DCB % of DCA'
    DCBSubjectCompute = Get-Datacenter DCB
    DCASubjectCompute = Get-Datacenter DCA
    DCBSubjectStorage = 'dcb-flasharray1','dcb-flasharray2'
    DCASubjectStorage = 'dca-flasharray1','dca-flasharray2','dca-flasharray3'
}

$DRSubjects += [PSCustomObject]@{
    SubjectName = 'DCB Final % of DCA Final'
    DCBSubjectCompute = $dcbFinal
    DCASubjectCompute = $dcaFinal
    DCBSubjectStorage = 'dcb-flasharray1','dcb-flasharray2'
    DCASubjectStorage = 'dca-flasharray1','dca-flasharray2','dca-flasharray3'
}

$failoverSubjects += [PSCustomObject]@{
    SubjectName = 'Aztec + SaaS Failover'
    VMs = $failoverVMs
    DCBCompute = Get-Cluster DCB*
    RemoveVMs = @()
}

$failoverSubjects += [PSCustomObject]@{
    SubjectName = 'Aztec + SaaS Failover w/ NP Powered Off'
    VMs = $failoverVMs
    DCBCompute = Get-Cluster DCB*
    RemoveVMs = Get-Folder SaaS -Location DCB | Get-VM | ? PowerState -eq 'PoweredOn'
}

$failoverSubjects += [PSCustomObject]@{
    SubjectName = 'Aztec + SaaS Failover on DCB Final'
    VMs = $failoverVMs
    DCBCompute = $dcbFinal
    RemoveVMs = @()
}

$failoverSubjects += [PSCustomObject]@{
    SubjectName = 'Aztec + SaaS Failover w/ on DCB Final and NP Powered Off'
    VMs = $failoverVMs
    DCBCompute = $dcbFinal
    RemoveVMs = Get-Folder SaaS -Location DCB | Get-VM | ? PowerState -eq 'PoweredOn'
}

$backupSubjects += [PSCustomObject]@{
    SubjectName = 'DCA'
    backupServers = 'dca-utl-nas2', 'dca-utl-nas3'
}

$backupSubjects += [PSCustomObject]@{
    SubjectName = 'DCB'
    backupServers = 'dcb-utl-nas2', 'dcb-utl-nas3', 'tf-utl-nas'
}

$backupSubjects += [PSCustomObject]@{
    SubjectName = 'dca-utl-nas2'
    backupServers = 'dca-utl-nas2'
}

$backupSubjects += [PSCustomObject]@{
    SubjectName = 'dca-utl-nas3'
    backupServers = 'dca-utl-nas3'
}

$backupSubjects += [PSCustomObject]@{
    SubjectName = 'dcb-utl-nas2'
    backupServers = 'dcb-utl-nas2'
}

$backupSubjects += [PSCustomObject]@{
    SubjectName = 'dcb-utl-nas3'
    backupServers = 'dcb-utl-nas3'
}

$backupSubjects += [PSCustomObject]@{
    SubjectName = 'tf-utl-nas'
    backupServers = 'tf-utl-nas'
}

$compSustainabilitySubjects += [PSCustomObject]@{
    SubjectName = 'vcenterc01 Hosts'
    Subject = 'vSphere World'
}

$computeSubjects | % {

    $subject = $_.Subject
    $subjectName = $_.SubjectName
    $numvCPUs = ($_.VMs | measure NumCpu -Sum).Sum
    $vmMemory = ($_.VMs | measure MemoryGB -Sum).Sum

    if($subjectName -match 'Final'){
        $ConnectionState = 'Connected', 'Disconnected', 'Maintenance', 'NotResponding'
        $vmhosts = $subject
    }else{
        $ConnectionState = 'Connected', 'NotResponding'
        $vmhosts = $subject | Get-VMHost
    }

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Number of Active Hosts'
        $month = ($vmhosts | ? ConnectionState -In $ConnectionState | measure).Count
    }
    
    $numCores = ($vmhosts | ? ConnectionState -In $ConnectionState | measure NumCpu -Sum).Sum
    $ratio = [math]::Round($numvCPUs/$numCores,2)

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'vCPU:pCPU (Target ≤ 4:1)'
        $month = $ratio
    }

    $hostMemory = ($vmhosts | ? ConnectionState -In $ConnectionState | measure MemoryTotalGB -Sum).Sum
    $memUsed = [math]::Round($vmMemory/$hostMemory*100,2)

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Used Memory %'
        $month = $memUsed
    }

    $numCoresFTT = ($vmhosts | ? ConnectionState -In $ConnectionState | measure NumCpu -Sum).Sum - ($vmhosts | ? ConnectionState -In $ConnectionState | sort NumCpu)[-1].NumCpu
    $fttRatio = [math]::Round($numvCPUs/$numCoresFTT,2)

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'vCPU:pCPU (FTT=1)'
        $month = $fttRatio
    }

    $hostMemoryFTT = ($vmhosts | ? ConnectionState -In $ConnectionState | measure MemoryTotalGB -Sum).Sum - ($vmhosts | ? ConnectionState -In $ConnectionState | sort MemoryTotalGB)[-1].MemoryTotalGB
    $fttUsedMem = [math]::Round($vmMemory/$hostMemoryFTT*100,2)

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Used Memory % (FTT=1)'
        $month = $fttUsedMem
    }

    $cpuToAddFTT = [math]::max(0, [math]::Ceiling($numvCPUs/4 - $numCoresFTT))
    
    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'pCPU to add for 4:1 (FTT=1)'
        $month = $cpuToAddFTT
    }

    $memToAddFTT = [math]::max(0, [math]::Ceiling($vmMemory*100/85 - $hostMemoryFTT))
    
    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Host memory to add for 85% (FTT=1)'
        $month = $memToAddFTT
    }

    $vcpuRemainingFTT = 4*$numCoresFTT - $numvCPUs
    
    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'vCPU remaining until 4:1 (FTT=1)'
        $month = $vcpuRemainingFTT
    }

    $vmMemRemainingFTT = 0.85*$hostMemoryFTT - $vmMemory
    if($vmMemRemainingFTT -ge 0){
        $vmMemRemainingFTT = [math]::Floor($vmMemRemainingFTT)
    }else{
        $vmMemRemainingFTT = [math]::Ceiling($vmMemRemainingFTT)
    }
    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'VM memory remaining until 85% (FTT=1)'
        $month = $vmMemRemainingFTT
    }

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Number of On VMs'
        $month = ($_.VMs | ? PowerState -eq 'PoweredOn' | measure).Count
    }

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Total On VMs vCPUs'
        $month = ($_.VMs | ? PowerState -eq 'PoweredOn' | measure NumCpu -Sum).Sum
    }

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Total On VMs MemoryGB'
        $month =  [math]::Round(($_.VMs | ? PowerState -eq 'PoweredOn' | measure MemoryGB -Sum).Sum,2)
    }

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Total On VMs UsedSpaceGB'
        $month = [math]::Round(($_.VMs | ? PowerState -eq 'PoweredOn' | measure UsedSpaceGB -Sum).Sum,2)
    }

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Total pCPUs'
        $month = $numCores
    }

    $totalMHz = ($vmhosts | ? ConnectionState -In $ConnectionState | measure CpuTotalMhz -Sum).Sum

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Total MHz'
        $month = $totalMHz
    }

    $infra += [PSCustomObject]@{
        Category = 'Compute'
        Subject = $subjectName
        Metric = 'Total MemoryGB'
        $month = [math]::Round($hostMemory,2)
    }
}

$storageSubjects | % {

    $subject = $_.Subject
    $subjectName = $_.SubjectName
    $vmClusters = $_.VMs

    $spaceMetrics = "array_system_space", "array_volume_space", "array_snapshot_space", "array_shared_space" 

    $used = ($subject | % {        
        $array = $_

        ($spaceMetrics | % {
            ((Get-PureOneMetric -ObjectName $array -MetricName $_ -StartTime (Get-Date).AddDays(-30)).data | % { ($_ -split ' ')[-1] })[-1]
        } | measure -Sum).Sum
    } | measure -Sum).Sum

    $capacity = ($subject | % {
        ((Get-PureOneMetric -ObjectName $_ -MetricName array_total_capacity -StartTime (Get-Date).AddDays(-30)).data | % { ($_ -split ' ')[-1] })[-1]
    } | measure -Sum).Sum

    $capUsed = [math]::Round($used/$capacity*100,2)

    $infra += [PSCustomObject]@{
        Category = 'Storage'
        Subject = $subjectName
        Metric = 'Capacity Usage %'
        $month = $capUsed
    }    

    $usableCap = [math]::Round($capacity/1TB,2)
    
    $infra += [PSCustomObject]@{
        Category = 'Storage'
        Subject = $subjectName
        Metric = 'Usable CapacityTB'
        $month = $usableCap
    }
    
    $spaceMetrics | ? {$_ -NotMatch 'system'} | % {
        $metric = $_
        
        $value = ($subject | % {        
            $array = $_
            ((Get-PureOneMetric -ObjectName $array -MetricName $metric -StartTime (Get-Date).AddDays(-30)).data | % { ($_ -split ' ')[-1] })[-1]            
        } | measure -Sum).Sum

        $infra += [PSCustomObject]@{
            Category = 'Storage'
            Subject = $subjectName
            Metric = $metric + ' (TB)'
            $month = [math]::Round($value/1TB,2)
        }
    }

    $loadMeters = @()
    
    $subject | % {            
        $loadMeters += Get-PureOneArrayLoadMeter -ObjectName $_ -Maximum -StartTime (Get-Date).AddDays(-30) # 3 minute granularity
    }

    $loadMeterData = $loadMeters.data | % { ($_ -split ' ')[-1] }
    
    $maxLoad = [math]::Round(($loadMeterData | measure -Maximum).Maximum*100,2)

    $infra += [PSCustomObject]@{
        Category = 'Storage'
        Subject = $subjectName
        Metric = 'Max Load Last 30d'
        $month = $maxLoad
    }

    $sequence = [Double[]]$loadMeterData | Sort-Object
    [int]$n = $sequence.Length
    [Double]$num = ($n - 1) * [Double]0.95 + 1
    $k = [Math]::Floor($num)
    [Double]$d = $num - $k
    $ninetyFifthPercentileMaxLoad = $sequence[$k - 1] + $d * ($sequence[$k] - $sequence[$k - 1])
    $ninetyFifthPercentileMaxLoad = [math]::Round($ninetyFifthPercentileMaxLoad*100,2)

    $infra += [PSCustomObject]@{
        Category = 'Storage'
        Subject = $subjectName
        Metric = '95th Percentile Max Load Last 30d'
        $month = $ninetyFifthPercentileMaxLoad
    }

    $latencyMetrics = @()

    $subject | % {
        $latencyMetrics += Get-PureOneMetric -ObjectName $_ -Average -MetricName array_read_latency_us -StartTime (Get-Date).AddDays(-30) # 30 second granularity
        $latencyMetrics += Get-PureOneMetric -ObjectName $_ -Average -MetricName array_write_latency_us -StartTime (Get-Date).AddDays(-30) # 30 second granularity
    }

    $latencyData = $latencyMetrics.data | % { ($_ -split ' ')[-1]/1000 }
    $avgLat = [math]::Round(($latencyData | measure -Average).Average,2)

    $infra += [PSCustomObject]@{
        Category = 'Storage'
        Subject = $subjectName
        Metric = 'Avg R/W LatencyMS Last 30d'
        $month = $avgLat
    }    

    $infra += [PSCustomObject]@{
        Category = 'Storage'
        Subject = $subjectName
        Metric = 'Number of On VMs'
        $month = ($vmClusters | Get-VM | ? PowerState -eq 'PoweredOn' | measure).Count
    }    
}

$DRSubjects | % {        

    if($_.SubjectName -match 'Final'){
        $ConnectionState = 'Connected', 'Disconnected', 'Maintenance', 'NotResponding'
        $DCAHosts = $_.DCASubjectCompute
        $DCBHosts = $_.DCBSubjectCompute
    }else{
        $ConnectionState = 'Connected', 'NotResponding'
        $DCAHosts = $_.DCASubjectCompute | Get-VMHost
        $DCBHosts = $_.DCBSubjectCompute | Get-VMHost
    }

    $coresPcntg = ($DCBHosts | measure NumCpu -Sum).Sum/($DCAHosts | measure NumCpu -Sum).Sum*100
    
    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'CPU Cores'
        $month = [math]::Round($coresPcntg,2)
    }
    
    $memPcntg = ($DCBHosts | ? ConnectionState -In $ConnectionState | measure MemoryTotalGB -Sum).Sum/($DCAHosts | ? ConnectionState -In $ConnectionState | measure MemoryTotalGB -Sum).Sum*100

    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'Memory'
        $month = [math]::Round($memPcntg,2)
    }
    
    $dcbTotalStor = ($_.DCBSubjectStorage | % {
        (Get-PureOneMetric -ObjectName $_ -MetricName array_total_capacity).data[-1][-1]
    } | measure -Sum).Sum

    $dcaTotalStor = ($_.DCASubjectStorage | % {
        (Get-PureOneMetric -ObjectName $_ -MetricName array_total_capacity).data[-1][-1]
    } | measure -Sum).Sum

    $storPcntg = [math]::Round($dcbTotalStor/$dcaTotalStor*100,2)

    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'Storage'
        $month = $storPcntg
    }    

    $dcaTotalBackup = ($repoInfo | ? Name -Match 'dca' | measure Size -Sum).Sum
    $dcbTotalBackup = ($repoInfo | ? Name -Match 'dcb|tf' | measure Size -Sum).Sum

    $backupPcntg = [math]::Round($dcbTotalBackup/$dcaTotalBackup*100,2)

    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'Backup'
        $month = $backupPcntg
    }   
}

$failoverSubjects | % {
    
    if($_.SubjectName -match 'Final'){
        $ConnectionState = 'Connected', 'Disconnected', 'Maintenance', 'NotResponding'
        $DCBHosts = $_.DCBCompute
    } else {
        $ConnectionState = 'Connected', 'NotResponding'
        $DCBHosts = $_.DCBCompute | Get-VMHost
    }

    $numvCPUs = ($_.VMs | measure NumCpu -Sum).Sum - ($_.RemoveVMs | measure NumCpu -Sum).Sum
    $numCores = ($DCBHosts | ? ConnectionState -In $ConnectionState | measure NumCpu -Sum).Sum
    $ratio = [math]::Round($numvCPUs/$numCores,2)

    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'DCB vCPU:pCPU'
        $month = $ratio
    }

    $vmMemory = ($_.VMs | measure MemoryGB -Sum).Sum - ($_.RemoveVMs | measure MemoryGB -Sum).Sum
    $hostMemory = ($DCBHosts | ? ConnectionState -In $ConnectionState | measure MemoryTotalGB -Sum).Sum
    $memPcntg = [math]::Round($vmMemory/$hostMemory*100,2)

    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'DCB Used Memory %'
        $month = $memPcntg
    }

    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'Total vCPUs in Failover Group'
        $month = ($_.VMs | measure NumCpu -Sum).Sum
    }

    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'Total VM MemoryGB in Failover Group'
        $month =  [math]::Round(($_.VMs | measure MemoryGB -Sum).Sum,2)
    }

    $infra += [PSCustomObject]@{
        Category = 'DR'
        Subject = $_.SubjectName
        Metric = 'Total VM UsedSpaceGB in Failover Group'
        $month = [math]::Round(($_.VMs | measure UsedSpaceGB -Sum).Sum,2)
    }
}

$backupSubjects | % {
        
    $servers = $_.backupServers    
        
    $size = ($repoInfo | ? {($_.Name -split '-repo')[0] -in $servers} | measure Size -Sum).Sum
    $sizeRemaining = ($repoInfo | ? {($_.Name -split '-repo')[0] -in $servers} | measure SizeRemaining -Sum).Sum    
    $repoCapUsedPcntg = [math]::Round((1-($sizeRemaining/$size))*100,2)

    $infra += [PSCustomObject]@{
        Category = 'Backup'
        Subject = $_.SubjectName
        Metric = 'Repo Capacity Usage %'
        $month = $repoCapUsedPcntg
    }
}

$compSustainabilitySubjects | % {
    
    $vSpherePowerUsage = (Get-OMStat -Resource $_.Subject -Key 'sustainability|power_usage' -From (Get-Date).AddMonths(-1)).Value
        
    $infra += [PSCustomObject]@{
        Category = 'Sustainability'
        Subject = $_.SubjectName
        Metric = 'Current Power Usage (KWh)'
        $month = [math]::Round($vSpherePowerUsage[-1],2)
    }

    $infra += [PSCustomObject]@{
        Category = 'Sustainability'
        Subject = $_.SubjectName
        Metric = 'Last Month Power Usage (MWh)'
        $month = [math]::Round((($vSpherePowerUsage | measure -Sum).Sum/1000),2)
    }

    $vSphereCO2Emission = (Get-OMStat -Resource $_.Subject -Key 'sustainability|co2_emission' -From (Get-Date).AddMonths(-1)).Value

    $infra += [PSCustomObject]@{
        Category = 'Sustainability'
        Subject = $_.SubjectName
        Metric = 'Current CO2 Emission (Kg)'
        $month = [math]::Round($vSphereCO2Emission[-1],2)
    }

    $infra += [PSCustomObject]@{
        Category = 'Sustainability'
        Subject = $_.SubjectName
        Metric = 'Last Month CO2 Emission (Kg)'
        $month = [math]::Round((($vSphereCO2Emission | measure -Sum).Sum),2)
    }
}

<# Clusters tab #>

$clusters = Get-Cluster -Location DCA, DCB | Get-VMHost | select @{n='Cluster'; e={ ($_ | Get-Cluster).Name }},
@{n='Host'; e={ $_.Name }},
@{n='Clock Speed GHz'; e={ [math]::Round($_.ExtensionData.Hardware.CpuInfo.Hz/1000000000,2) }},
@{n='Number of CPU Cores'; e={ $_.NumCpu }},
@{n='Total Memory GB'; e={ [math]::Round($_.MemoryTotalGB,0) }},
@{n='Status'; e={ $_.ConnectionState }}

<# Failover Workloads tab #>

$failoverVMsList = $failoverVMs | select @{n='Category'; e={
   switch ($_.Id) {
       {$_ -in $dcb.Id} { 'DCB Native' }
       {$_ -in $dcbReplicas.Id} { 'DCB Standby Replica' }
       {$_ -in $aztec.Id} { 'DCA Aztec' }
       {$_ -in $saas.Id} { 'DCA SaaS' }
       Default {}
   } 
}},
Name, NumCpu,
@{n='MemoryGB'; e={ [math]::Round($_.MemoryGB,2) }},
@{n='UsedSpaceGB'; e={ [math]::Round($_.UsedSpaceGB,2) }},
@{n='FolderPath'; e={ Get-VIFolderPath -VIObject $_ }}

<# New VMs tab #>

$newVMs = $allVMs | ? CreateDate -GE (Get-Date).AddDays(-50)

$newVMs = $newVMs | select Name, CreateDate,
@{n='Cluster';e={ $_.VMHost.Parent }},
@{n='FolderPath';e={ Get-VIFolderPath -VIObject $_ }}, NumCPU, MemoryGB, PowerState

<# VM Metrics tab #>

$VMStats = $VMStatTypes | % {
    $baseStats = Get-Stat -Entity $VMsToMeasure -Stat $_ -Start (Get-Date).AddDays(-30) -MaxSamples ([int]::MaxValue)
    $groups = $baseStats | group Entity
    
    $groups | % { 

        $_ | select @{n='Metric'; e={ $_.Group.MetricId[0] }}, Name, @{n='Value'; e={ ($_.Group.Value | measure -Average).Average }}

    } | sort Value -Descending | select -First 10
}

$VMStats | Export-CSV -NoTypeInformation .\vmstats.csv