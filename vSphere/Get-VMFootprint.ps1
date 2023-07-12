function Get-VMFootprint
{
    [CmdletBinding(DefaultParameterSetName='byOption')]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$True,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [Parameter(ParameterSetName='byMetric')]
        [Parameter(ParameterSetName='byOption')]
        $VM,

        [Parameter(ParameterSetName='byMetric')]
        [Parameter(ParameterSetName='byOption')]
        [System.DateTime]
        $Start = (Get-Date).AddSeconds(-40),        

        [Parameter(ParameterSetName='byMetric')]
        [Parameter(ParameterSetName='byOption')]
        [System.DateTime]
        $Finish = (Get-Date),

        [Parameter(ParameterSetName='byMetric')]
        $Metric = @('cpu.usagemhz.average','cpu.usagemhz.maximum','mem.usage.average','disk.usage.average','disk.maxTotalLatency.latest','net.usage.average'),

        [Parameter(ParameterSetName='byOption')]
        [switch]
        $Cpu,

        [Parameter(ParameterSetName='byOption')]
        [switch]
        $Memory,

        [Parameter(ParameterSetName='byOption')]
        [switch]
        $Disk,

        [Parameter(ParameterSetName='byOption')]
        [switch]
        $Network
    )

    Begin
    {   
        #Change output field seperator
        $OFS=', '
        Out-Default -InputObject ""
        Out-Default -InputObject "`tvSphere performance counters documentation:"
        Out-Default -InputObject ""
        Write-Host "`thttps://www.vmware.com/support/developer/converter-sdk/conv50_apireference/vim.PerformanceManager.html"`
        -ForegroundColor Cyan
        Out-Default -InputObject ""
        Out-Default -InputObject ""

        if($Cpu-or$Memory-or$Disk-or$Network){
            $Metric=@()
            if($Cpu){$Metric+='cpu.usagemhz.average','cpu.usagemhz.maximum'}
            if($Memory){$Metric +='mem.usage.average'}
            if($Disk){$Metric += 'disk.usage.average','disk.maxTotalLatency.latest'}
            if($Network){$Metric += 'net.usage.average'}
        }
    }

    Process
    {
        foreach ($v in $VM){
            $v = Get-VM $v
            $Stats = $v | Get-Stat -Stat $Metric -Start $Start -Finish $Finish -ErrorAction SilentlyContinue
            $ComputerName = $v.Guest.Hostname
                
            $VMstats =
            [pscustomobject]@{
                Name = $v.Name
                PowerState = $v.PowerState
                VMHost= $v.VMhost.Name
                Folder= Get-VIFolderPath -VIObject $v -ErrorAction SilentlyContinue
                ComputerName= if($ComputerName){$ComputerName.Split('.')[0]}else{'?'}
                numCpu=$v.NumCpu
                MemGB=$v.MemoryGB
                ProvisionedGB=$v.ProvisionedSpaceGB
                UsedGB=$v.UsedSpaceGB
            }

            if($Stats-ne$null){
                $VMstats | Add-Member -MemberType NoteProperty -Name 'StatsCollected' -Value $true -Force
                
                $StartTimeStamp = ($Stats | Sort Timestamp | Select -first 1).timestamp
                $FinishTimeStamp = ($Stats | Sort Timestamp | Select -last 1).timestamp
                   
                $VMstats | Add-Member -MemberType NoteProperty -Name 'StartTime' -Value $StartTimeStamp -Force
                $VMstats | Add-Member -MemberType NoteProperty -Name 'FinishTime' -Value $FinishTimeStamp -Force

                foreach ($m in $Metric) {
                    
                    $MetricSamples = $Stats | ? {($_.MetricId -eq $m) -and ($_.Instance -eq '')} -ErrorAction SilentlyContinue

                    if ($MetricSamples)
                    {
                        switch ($m) {
                            {($_ -eq 'cpu.usagemhz.average')-or($_ -eq 'cpu.usagemhz.maximum')} {$u = 'MHz'}
                            {$_ -eq 'mem.usage.average'} {$u = '%'}
                            {($_ -eq 'disk.usage.average')-or($_ -eq 'net.usage.average')} {$u = 'KB/s'}
                            {$_ -eq 'disk.maxTotalLatency.latest'} {$u = 'ms'}
                        }
                        
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)Last5" -Value ([string]$MetricSamples[0..4].Value) -Force
                        
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)Avrg" -Value ($MetricSamples | Measure-Object -Property Value -Average).Average -Force
                        
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)Max" -Value ($MetricSamples | Measure-Object -Property Value -Maximum).Maximum -Force
                         
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)Min" -Value ($MetricSamples | Measure-Object -Property Value -Minimum).Minimum -Force
                        
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)SampleSecs" -Value ($MetricSamples.IntervalSecs | Select -Unique) -Force
                    } else {
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)Last5" -Value 'unavailable' -Force
                        
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)Avrg" -Value 'unavailable' -Force
                        
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)Max" -Value 'unavailable' -Force
                         
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)Min" -Value 'unavailable' -Force
                        
                        $VMstats | Add-Member -MemberType NoteProperty -Name "$m$($u)SampleSecs" -Value 'unavailable' -Force
                    }
                }
            } else {   
                Write-Warning -Message "Stats unavailable for $($v.Name)`n"
                $VMstats | Add-Member -MemberType NoteProperty -Name 'StatsCollected' -Value $false -Force
            }
                
            $VMstats
        }
    }
}