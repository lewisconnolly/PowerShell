function Get-VMLimits ($VMs,$ExcludeDefault,$ShowRelevant)
{
    $VMs | % {
        $CPU = $_.numcpu
        $MemoryGB = $_.MemoryGB
        $DiskKeys = @()
        $_ | Get-HardDisk | % {
            $DiskKeys +=
            [pscustomobject]@{
                id = ($_.Id -split '/')[1]
                name = $_.Name
            }
        }
        
        $ResConf = $_ | Get-VMResourceConfiguration |
        Select VM, {$CPU},{$MemoryGB},
        @{n='CpuShares';e={if($_.CpuSharesLevel -eq 'Normal'){$_.CpuSharesLevel}else{$_.NumCpuShares}}},
        @{n='CpuReserveMHz';e={if($_.CpuReservationMhz -eq 0){'None'}else{$_.CpuReservationMhz}}},
        @{n='CpuLimMHz';e={if($_.CpuLimitMhz -eq -1){'None'}else{$_.CpuLimitMhz}}},
        @{n='MemShares';e={if($_.MemSharesLevel -eq 'Normal'){$_.MemSharesLevel}else{$_.NumMemShares}}},
        @{n='MemReserveGB';e={if($_.MemReservationGB -eq 0){'None'}else{$_.MemReservationGB}}},
        @{n='MemLimGB';e={if($_.MemLimitGB -eq -1){'None'}else{$_.MemLimitGB}}},
        @{n='DiskShares';e={
            $DskShares = @()
            $_.DiskResourceConfiguration | % {
                $id = $_.Key
                if($_.DiskSharesLevel -ne 'Normal'){
                    $shares = $_.NumDiskShares
                }else{$shares = $_.DiskSharesLevel}
                $disk = ($DiskKeys | ? id -eq $id).name
                $DskShares += "$disk - $shares"
            }
            $DskShares -join "`n"
        }},
        @{n='DiskLimit';e={
            $DskLims = @()
            $_.DiskResourceConfiguration | % {
                $id = $_.Key
                if($_.DiskLimitIOPerSecond -ne -1){
                    $lim = $_.DiskLimitIOPerSecond
                }else{$lim = 'None'}
                $disk = ($DiskKeys | ? id -eq $id).name
                $DskLims += "$disk - $lim"
            }
            $DskLims -join "`n"
        }}
        
        if(!$ExcludeDefault){
            $ResConf
        }else{
            $ResConf | ? {($_.CpuShares -ne 'Normal') -or ($_.CpuReserveMHz -ne 'None') -or ($_.CpuLimMHz -ne 'None') -or
            ($_.MemShares -ne 'Normal') -or ($_.MemReserveGB -ne 'None') -or ($_.MemLimGB -ne 'None') -or
            ($_.DiskShares -Match '- [0-9]+') -or ($_.DiskLimit -match '- [0-9]+')}
        }
    
    }
}