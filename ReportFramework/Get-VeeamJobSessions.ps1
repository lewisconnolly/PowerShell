##################################
###    Get-VeeamJobSessions    ###
### lewis.connolly@zonal.co.uk ###
##################################

# Creates report of Veeam job sessions with last session and yearly metrics
function Get-VeeamJobSessions {

    $sessionsLastYear = Get-VBRBackupSession | ? CreationTime -gt (Get-Date).AddYears(-1)
    $groupedSessions = $sessionsLastYear | group JobName
    $allJobs = Get-VBRJob

    $groupedSessions |  % {
    
        $sessions = $_.Group
        $incrementalSessions = ($sessions | ? Name -match 'Incremental' | ? Result -eq 'Success')
        $lastSession = ($sessions | sort CreationTime -Descending)[0]

        [PSCustomObject]@{
            JobName = $_.Name
            JobType = $lastSession.JobType
            BackupRepo = ($allJobs | ? Id -eq $lastSession.JobId).GetBackupTargetRepository().Name
            BackupRepoDescription = ($allJobs | ? Id -eq $lastSession.JobId).GetBackupTargetRepository().Description
            YrAverageDuration = (New-TimeSpan -Seconds ($incrementalSessions.WorkDetails.WorkDuration.TotalSeconds | measure -Average).Average).ToString()
            YrAvgReadGB = [math]::Round((($incrementalSessions.Progress.ReadSize | measure -Average).Average / 1GB),2)
            YrAvgTransferredGB = [math]::Round((($incrementalSessions.Progress.TransferedSize | measure -Average).Average / 1GB),2)
            YrAvgSpeedMBps = [math]::Round((($incrementalSessions.Progress.AvgSpeed | measure -Average).Average / 1MB),2)
            # Get everything after the first space from the session name then remove brackets (resulting in session type string. e.g. Increment, Full, Increment Retry 1)
            LastSessionType = $lastSession.Name.Substring($lastSession.Name.IndexOf(' ')).Trim() -replace '[()]'
            LastSessionDuration = $lastSession.WorkDetails.WorkDuration            
            LastSessionState = $lastSession.State
            LastSessionResult = $lastSession.Result
            LastSessionCreationTime = $lastSession.CreationTime
            LastSessionEndTime = $lastSession.EndTime
            LastSessionDataGB = [math]::Round(($lastSession.BackupStats.DataSize / 1GB), 2)
            LastSessionReadGB = [math]::Round(($lastSession.Progress.ReadSize / 1GB), 2)
            LastSessionCompressionRatio = $lastSession.BackupStats.CompressRatio
            LastSessionTransferredGB = [math]::Round(($lastSession.Progress.TransferedSize / 1GB), 2)
            LastSessionDedupRatio = $lastSession.BackupStats.DedupRatio            
            LastSessionBackupGB = [math]::Round(($lastSession.BackupStats.BackupSize / 1GB), 2)            
            LastSessionTotalObjects = $lastSession.Progress.TotalObjects
            LastSessionProcessedObjects = $lastSession.Progress.ProcessedObjects                        
            LastSessionAvgSpeedMBps = [math]::Round(($lastSession.Progress.AvgSpeed / 1MB), 2)
            LastSessionTotalVMGB = [math]::Round(($lastSession.Progress.TotalSize / 1GB), 2)
            LastSessionTotalVMDKGB = [math]::Round(($lastSession.Progress.TotalUsedSize / 1GB), 2)            
        }
    }
}    

### Report Framework

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

$veeamJobSessions = Get-VeeamJobSessions

$reportContext = "TransferredGB - Data transferred from source to repo after reductions from compression and deduplication from CBT and against previous restore point<br>
ReadGB - Amount of changed data for each VM disk read from the datastore prior to any deduplication and compression<br>
DataGB - Data size after filtering out unchanged blocks and blocks in previous restore point but prior to pre-transfer compression and deduplication at the level of the backup chain on the repo<br>
BackupSizeGB - Final size of backup file on repo after compression and all deduplication<br>
TotalVMGB - Amount of data used by VMs in job on datatstore<br>
TotalVMDKGB - Amount of data used by disks of VMs in job on datastore or if copy job - the same as last non-zero ReadGB (if copy job is periodic and had nothing to copy, such as when monthly or weekly, then ReadGB is 0)"

$veeamJobSessions |
ConvertTo-HtmlReport `
    -ReportTitle "Veeam Job Sessions" `
    -ReportDescription "Metrics of last Veeam job sessions and per job last year averages" `
    -ReportContext $reportContext `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\Html Reports\veeamsessions.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "\\dcautlprdwrk01\c$\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\wwwroot\index.html" `
    -VirtualPath "/"