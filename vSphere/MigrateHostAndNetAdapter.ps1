$VMHost = gvh zhost27*
$VMs = $VMHost | gvm | ? name -NotIn @('dca-ae-sql1','dca-trg-sql2','dca-f5-bip2')
$VMHostMaxCPUUsagePercent = 90
$VMHostMaxMEMUsagePercent = 90
$VMHostMaxVCpuPerCore = 7

$VMs | % {
    
    $vm = $_

    $PossibleHost = Get-VMHost `
                        | Where name -ne $VMHost.name `
                        | where {$_ -notin $ExcludedVMHost} `
                        | where connectionstate -eq "connected" `
                        | where {($_|get-cluster).name -eq ($VMHost|get-cluster).name}

    $i = 0

    $selectedVMHost = $PossibleHost | ForEach-Object {

        $i++

        $HostVM = $_ | get-vm | where powerstate -eq poweredon

        [pscustomobject]@{
            id = $i
            name = $_.name
            "ProjectedCpuUsage" = [math]::round(($_.CpuUsageMhz + $vm.ExtensionData.Runtime.MaxCpuUsage) / $_.CpuTotalMhz * 100,1)
            "ProjectedMemUsage" = [math]::round(($_.MemoryUsageMB + $vm.memoryMB) / $_.MemoryTotalMB * 100,1)
            "ProjectedVCPUperCORE" =[math]::round(($HostVM | Measure-Object -Property numcpu -Sum).sum / $_.NumCpu,1)
            "Projected#LiveVM" = $HostVM.count + 1
        }
    } | where {$_.ProjectedCpuUsage -lt $VMHostMaxCPUUsagePercent -and $_.ProjectedMemUsage -lt $VMHostMaxMEMUsagePercent -and $_.ProjectedVCPUperCORE -lt $VMHostMaxVCpuPerCore}
    
    $nics = @()
    $pgs = @()
    $SourceNetworks = @()
    $SourceVLAN = @()
    $DestVLAN = @()
    $SourceAllowPromiscuous = @()
    $DestAllowPromiscuous = @()
    $SourceForgedTransmits = @()
    $DestForgedTransmits = @()
    $SourceMacChanges = @()
    $DestMacChanges = @()
    $nicfaults = 0
    $sameTeam = $true
    $c1 = $false
    $c2 = $false
    $c3 = $false
    $c4 = $false
    $oktomig = $false
    
    $vm | Get-NetworkAdapter | % {
        if($nicfaults -eq 0){
            $nics += $_
            $netname = $_.networkname
            $stdPG = $vmhost | Get-VirtualPortGroup -Name $netname
            $stdSecPol = $stdPG | Get-SecurityPolicy
            [regex]$ptn = '[0-9]+'
            $vlan= ":$($ptn.Matches($netname).value)"
            $vdPG = Get-VDPortgroup -Name "DCA-DSw0-DPG-*$vlan"
            
            if($vdPG -eq $null)
            {
                if($stdPG.vlanid -eq 0)
                {
                    $vdPG = Get-VDPortgroup -Name "DCA*Untagged"
                }

                if($stdPG.vlanid -eq 4095)
                {
                    $vdPG = Get-VDPortgroup -Name "DCA*0-4094"
                }
            }

            $pgs += $vdPG
            $vdPgSecPol = $vdPG|  Get-VDSecurityPolicy
            $vdvlan = $vdPG.VlanConfiguration.vlanid
            
            if($vdPG.vlanconfiguration -eq $null)
            {
                $vdvlan = 0
            }
            
            if($vdPG.VlanConfiguration.Ranges.StartVlanId -eq 0 -and $vdPG.VlanConfiguration.Ranges.EndVlanId -eq 4094)
            {
                $vdvlan = 4095
            }
            
            $SourceNetworks += $netname
            $SourceVLAN += $stdPG.VlanId
            $DestVLAN +=  $vdvlan
            $SourceAllowPromiscuous += $stdSecPol.AllowPromiscuous
            $DestAllowPromiscuous += $vdPgSecPol.AllowPromiscuous
            $SourceForgedTransmits += $stdsecpol.ForgedTransmits
            $DestForgedTransmits += $vdPgSecPol.ForgedTransmits
            $SourceMacChanges += $stdSecPol.MacChanges
            $DestMacChanges += $vdPgSecPol.MacChanges

            $c1 = $stdSecPol.AllowPromiscuous -eq $vdPgSecPol.AllowPromiscuous
            $c2= $stdsecpol.ForgedTransmits -eq $vdPgSecPol.ForgedTransmits
            $c3 = $stdSecPol.MacChanges -eq $vdPgSecPol.MacChanges
            $c4 = $stdPG.VlanId -eq $vdvlan

            if(!($c1-and$c2-and$c3-and$c4-and$sameTeam))
            {
                $nicfaults++
            }
        }
    }

    if($nicfaults-eq0){$oktomig=$true}
    
    IF (!$selectedVMHost){
        Write-Warning "`nThere is no host capable of fulfilling the destination resource requirements for $($vm.name)`n"
    }
    elseif(!$oktomig){
        Write-Warning "`nDestination portgroups not compatible for $($vm.Name)`n"
    }
    else
    {
        $BestVMHost = $selectedVMHost | where id -eq ($selectedVMHost |
        select id,@{l="sum";e={$_.ProjectedCpuUsage + $_.ProjectedMemUsage}} | Sort-Object sum | select -First 1).id
        
        [pscustomobject]@{
            VM = $vm
            Destination = $BestVMHost.name
            NetworkAdapter = $nics.name -join ', '
            SourceNetworks = $SourceNetworks -join ', '
            Portgroup = $pgs.name -join ', '
            SourceVLAN = $SourceVLAN -join ', '
            DestVLAN = $DestVLAN -join ', '
            SourceAllowPromiscuous = $SourceAllowPromiscuous -join ', '
            DestAllowPromiscuous = $DestAllowPromiscuous -join ', '
            SourceForgedTransmits = $SourceForgedTransmits -join ', '
            DestForgedTransmits = $DestForgedTransmits -join ', '
            SourceMacChanges = $SourceMacChanges -join ', '
            DestMacChanges = $DestMacChanges -join ', '
        }        
        Move-VM -VM $vm -Destination $BestVMHost.name -NetworkAdapter $nics -PortGroup $pgs -Verbose
    }
}