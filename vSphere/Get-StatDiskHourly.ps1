<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-StatDiskHourly
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$True,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
        $VM
    )

    Begin
    {
        $metrics = "disk.numberwrite.summation","disk.numberread.summation","disk.Write.average","disk.read.average"
    }
    Process
    {
        $_ | Get-Stat -stat $metrics -Realtime | where Value -ne 0 | Group-Object -Property Entity | % {
                
            $VmName = $_.Name
            $Start = ($_.Group | sort Timestamp).Timestamp[0]
            $Finish = ($_.Group | sort Timestamp).Timestamp[-1]
            $iops = $_.Group | Where-Object {$_.MetricId -match 'summation'} | Measure-Object -Property Value -Maximum -Minimum -Average -Sum
            $diskusage = $_.Group | Where-Object {($_.MetricId -match 'average') -and ($_.Instance -eq '')} | Measure-Object -Property Value -Maximum -Minimum -Average -Sum

            [PSCustomObject]@{
                "VM" = $VMName
                "Start" = $Start
                "Finish" = $Finish
                "SumOf20secAvgIopsValues" = $iops.Sum
                "MaxOf20secAvgIopsValues" = $iops.Maximum
                "MinOf20secAvgIopsValues" = $iops.Minimum
                "AvgOf20secAvgIopsValues" = $iops.Average
                "SumOf20secAvgDiskUsageValues(KBps)" = $diskusage.Sum
                "MaxOf20secAvgDiskUsageValues(KBps)" = $diskusage.Maximum
                "MinOf20secAvgDiskUsageValues(KBps)" = $diskusage.Minimum
                "AvgOf20secAvgDiskUsageValues(KBps)" = $diskusage.Average
                "AvgIOSize(AvgUsage/AvgIops)" = $diskusage.Average/$iops.Average
            }
        }
    }
 
    End
    {
    }
}

