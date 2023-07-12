function Rotate-VBRBackupJobDefragCompactDay
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [switch]$GetOnly,
        $BackupJobs = (Get-VBRJob | ? jobtype -eq 'backup')
    )

    Begin
    {
        Add-PSSnapin VeeamPSSnapin
    }

    Process
    {        
        $backupJobs = $backupJobs |
        Select Name,
        @{n='ID';e={$_.id.guid}},
        @{n='RunAt';e={(get-date ($_|Get-VBRJobScheduleOptions).StartDateTimeLocal).TimeOfDay}},
        @{n='DefragCompactDay';e={($_ | Get-VBRJobOptions).GenerationPolicy.CompactFullBackupDays}}

        [dayofweek]$day = 'Monday'
        
        if(!$GetOnly)
        {
            $backupJobs | sort RunAt | % {
            
                $job = Get-VBRJob -Name $_.Name
                $jobopt = $job | Get-VBRJobOptions
            
                if($jobopt.GenerationPolicy.CompactFullBackupDays[0] -ne $day)
                { 
                    $jobopt.GenerationPolicy.CompactFullBackupDays = $day
                
                    "Setting " | Write-Host -NoNewline
                    "$($job.name) " | Write-Host -NoNewline -ForegroundColor Green
                    "compact full backup day to " | Write-Host -NoNewline
                    "$($day.ToString())`n" | Write-Host -ForegroundColor Magenta
                
                    $job | Set-VBRJobOptions -Options $jobopt
                }

                if($day -ne 'Saturday')
                {
                    $day = $day + 1
                }
                else
                {
                    [dayofweek]$day = 'Sunday'
                }
            }
        }
        else
        {
            $backupJobs | sort RunAt
        }
    }
}
