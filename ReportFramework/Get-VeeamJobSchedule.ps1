############################
### Get-VeeamJobSchedule ###
###    lewis.connolly    ###
############################

function Get-VeeamJobSchedule {    
    
    $backupJobs = Get-VBRJob
    
    $backupJobs |
    select Name,
        @{n='IsJobEnabled';e={$_.IsScheduleEnabled}},
        @{n='IsScheduleEnabled';e={-not(($_ | Get-VBRJobOptions).JobOptions.RunManually)}},
        JobType,
        @{n='StartTime';e={
            if($_.ScheduleOptions.OptionsDaily.Enabled){
                # daily and weekly jobs
                $_.ScheduleOptions.OptionsDaily.TimeLocal.TimeOfDay.ToString()                
            }elseif($_.ScheduleOptions.OptionsMonthly.Enabled){
                # monthly jobs
                $_.ScheduleOptions.OptionsMonthly.TimeLocal.TimeOfDay.ToString()                
            }else{
                # copy jobs
                if($_.JobType -eq 'BackupSync'){
                    ($_ | Get-VBRJobOptions).GenerationPolicy.SyncIntervalStartTime.ToString()
                }else{
                    'As soon as new onsite restore point appears'
                }
            }
        }},
        @{n='DayNumberInMonth';e={if($_.ScheduleOptions.OptionsMonthly.Enabled){ $_.ScheduleOptions.OptionsMonthly.DayNumberInMonth }else{ 'NA' }}},
        @{n='Day(s)';e={
            if($_.ScheduleOptions.OptionsDaily.Enabled){
                # daily and weekly jobs
                if($_.ScheduleOptions.OptionsDaily.DaysSrv.Count -eq 7){
                    'All'
                }else{
                    ($_.ScheduleOptions.OptionsDaily.DaysSrv | % { $_.ToString().Substring(0,3) }) -join ', '
                }
            }elseif($_.ScheduleOptions.OptionsMonthly.Enabled){
                # monthly jobs
                $_.ScheduleOptions.OptionsMonthly.DayOfWeek.ToString().Substring(0,3)
            }else{
                # copy jobs - periodic (BackupSync) and immediate
                if($_.JobType -eq 'BackupSync'){
                    $genPolicy = ($_ | Get-VBRJobOptions).GenerationPolicy
                    if(($genPolicy.RecoveryPointObjectiveValue -eq 1) -and ($genPolicy.RecoveryPointObjectiveUnit -eq 'Day')){'All' }else{ 'NA' }
                }else{
                    'Any day onsite restore point appears'
                }
            }
        }},
        @{n='Period';e={
            if($_.JobType -ne 'BackupSync'){
                'NA'
            }else{
                $genPolicy = ($_ | Get-VBRJobOptions).GenerationPolicy
                "Every {0} {1}s" -f $genPolicy.RecoveryPointObjectiveValue, $genPolicy.RecoveryPointObjectiveUnit.ToString().ToLower()
            }
        }}
}

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1 -ErrorAction SilentlyContinue

$reportContext = "BackupSync - Periodically copies the latest available restore point only<br>
SimpleBackupCopyPolicy - Copies every restore point as soon as it appears in the primary backup repository<br><br>
Note: BackupSync jobs cannot be changed to SimpleBackupCopyPolicy mode (as of Veeam v11). A new job and new backup must be created."

Get-VeeamJobSchedule | Sort-Object JobType, StartTime | ConvertTo-HtmlReport `
    -ReportTitle "Veeam Job Schedule" `
    -ReportDescription "Onsite and offsite backup job schedules" `
    -ReportContext $reportContext `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\Html Reports\veeamjobschedule.html" `
    -VirtualPath "reports" 

Write-Verbose "Generating report index..."
New-HtmlReportIndex -ReportPath "\\dcautlprdwrk01\c$\inetpub\Html Reports" | ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\wwwroot\index.html" `
    -VirtualPath "/"
