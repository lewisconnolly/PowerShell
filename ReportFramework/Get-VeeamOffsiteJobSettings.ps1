###################################
### Get-VeeamOffsiteJobSettings ###
### lewis.connolly@zonal.co.uk  ###
###################################

# Creates report of copy jobs on dcbutlprdvbs01 and their pertinent settings
function Get-VeeamOffsiteJobSettings {
    
    $allJobs = Get-VBRJob
        
    Get-VBRJob | ? JobType -ne Backup | select Name,
        Description,
        @{n='Enabled';e={$_.IsScheduleEnabled}},
        @{n='LinkedOnsiteJob';e={$id = $_.LinkedJobIds.Guid; ($allJobs | ? Id -eq $id).Name -join ', '}},
        @{n='ImmediateCopy';e={-not$_.IsBackupSync}},
        @{n='BackupRepo';e={$_.GetBackupTargetRepository().Name}},
        @{n='Retention';e={
            if($_.BackupStorageOptions.RetentionType -eq 'Cycles'){ $_.BackupStorageOptions.RetainCycles }
            if($_.BackupStorageOptions.RetentionType -eq 'Days'){ $_.BackupStorageOptions.RetainDays }
        }},
        @{n='RetentionType';e={$_.BackupStorageOptions.RetentionType}},        
        @{n='LinkedOnsiteRetention';e={
            $id = $_.LinkedJobIds.Guid
            $onsite = ($allJobs | ? Id -eq $id)

            if($onsite.BackupStorageOptions.RetentionType -eq 'Cycles'){
                '{0} Cycles' -f $onsite.BackupStorageOptions.RetainCycles
            }

            if($onsite.BackupStorageOptions.RetentionType -eq 'Days'){
                '{0} Days' -f $onsite.BackupStorageOptions.RetainDays
            }
        }},        
        @{n='RemoveDelVMsFromBackup';e={$_.Options.GenerationPolicy.EnableDeletedVmDataRetention}}                
}

### Report Framework

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

$veeamOffsiteJobSettings = Get-VeeamOffsiteJobSettings

$reportContext = "Cycles = Restore Points<br>
ImmediateCopy - Copy jobs can either copy the new onsite backup as soon as it has been created or check for it at a certain time each day"

$veeamOffsiteJobSettings |
ConvertTo-HtmlReport `
    -ReportTitle "Veeam Offsite Job Configuration" `
    -ReportDescription "Pertinent settings of offsite backup copy jobs on dcbutlprdvbs01 (DCA backup server)" `
    -ReportContext $reportContext `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\Html Reports\veeamoffsitejobconfig.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "\\dcautlprdwrk01\c$\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\wwwroot\index.html" `
    -VirtualPath "/"