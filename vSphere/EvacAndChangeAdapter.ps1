function Migrate-NetAdapter ($VM,$Destination){

    gvm $VM | % {
    
        $vmhost = $_ | gvh
        $vm = $_
        $nics = @()
        $pgs = @()

        $nicfaults = 0
        $sameTeam = $true
        $c1 = $false
        $c2 = $false
        $c3 = $false
        $c4 = $false
        $oktomig = $false
        
        "`n$($vm.Name)" | Write-Host -ForegroundColor Green        

        $vm | Get-NetworkAdapter | % {
            if($nicfaults -eq 0){
                $nics += $_
                $netname = $_.networkname
                $stdPG = $vmhost | Get-VirtualPortGroup -Name $netname
                $stdSecPol = $stdPG | Get-SecurityPolicy
                $stdTeam = $stdPG | Get-NicTeamingPolicy
                [regex]$ptn = '[0-9]+'
                $vlan= ":$($ptn.Matches($netname).value)"
                $vdPG = Get-VDPortgroup -Name "DCA*$vlan"
                
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
                $vdTeam = $vdPG| Get-VDUplinkTeamingPolicy

                "`n$netname to $($vdpg.name)`n" | Write-Host -ForegroundColor Cyan
                
                $vdvlan = $vdPG.VlanConfiguration.vlanid
                
                if($vdPG.vlanconfiguration -eq $null)
                {
                    $vdvlan = 0
                }
                
                if($vdPG.VlanConfiguration.Ranges.StartVlanId -eq 0 -and $vdPG.VlanConfiguration.Ranges.EndVlanId -eq 4094)
                {
                    $vdvlan = 4095
                }
                
                "VLAN: $($stdPG.VlanId) - $vdvlan" | Write-Host -ForegroundColor Magenta
                "AllowPromiscuous: $($stdSecPol.AllowPromiscuous) - $($vdPgSecPol.AllowPromiscuous)" | Write-Host -ForegroundColor Magenta
                "ForgedTransmits: $($stdsecpol.ForgedTransmits) - $($vdPgSecPol.ForgedTransmits)" | Write-Host -ForegroundColor Magenta
                "MacChanges: $($stdSecPol.MacChanges) - $($vdPgSecPol.MacChanges)" | Write-Host -ForegroundColor Magenta
                "ActiveNics: $($stdTeam.ActiveNic -join ', ') - $($vdTeam.ActiveUplinkPort -join ', ')" | Write-Host -ForegroundColor Magenta

                if($stdTeam.ActiveNic.count -ne $vdTeam.ActiveUplinkPort.count)
                {
                    $sameTeam=$false
                }
                else
                {
                    for($i=0;$i-lt($stdTeam.ActiveNic.count-1);$i++)
                    {
                    
                        if($sameTeam -ne $false)
                        {
                            if($stdTeam.ActiveNic.IndexOf(($vdTeam.ActiveUplinkPort[$i] -replace 'D','')) -eq -1)
                            {
                                $sameTeam = $false
                            }
                        }
                    }
                }

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
    
        if ($oktomig)
        {
            "`nMigrating $($vm.Name) to $($Destination.name)`n" | Write-Host -ForegroundColor Green
            move-vm -VM $vm -Destination $Destination -NetworkAdapter $nics -PortGroup $pgs
            sleep 7
        }
        else
        {
            "`nNot migrating $($vm.Name)`n"|Write-Host -ForegroundColor DarkRed
        }
    }
}

$ExcludedVMHost = gvh zhost10*,zhost18*,zhost19*,zhost20*
$VMHostMaxCPUUsagePercent = 85
$VMHostMaxMEMUsagePercent = 85
$VMHostMaxVCpuPerCore = 7
$ExcludedVMs = gvm dca-sta02_v11, dca-utl-gw1

gvh zhost26* | gvm | ? {$_ -notin $ExcludedVMs} | % {
    IF ((get-view $_.ExtensionData.Datastore).summary.MultipleHostAccess) {
                
        $CurVM = $_
        $VMHost = $_ | gvh

        $PossibleHost = Get-VMHost `
            | Where name -ne $VMHost.name `
            | where {$_ -notin $ExcludedVMHost} `
            | where connectionstate -eq "connected" `
            | where {$_.parent.name -eq ($CurVM|get-cluster).name}
            #| where {(Compare-Object $CurVM.ExtensionData.network.value $_.ExtensionData.network.value).sideindicator -notcontains "<="}

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
            
            $selectedVMHost = $BestVMHost

            Migrate-NetAdapter -VM $_ -Destination (gvh $selectedVMHost.Name)

        } ELSE {Write-Warning "There is no host capable of fulfilling the destination resource requirements for $($CurVM.name)"}

    } ELSE {Write-Warning "$($_.name) is on local storage"}
}