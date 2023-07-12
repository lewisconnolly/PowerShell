##################################
### Get-VeeamOnsiteJobSettings ###
### lewis.connolly@zonal.co.uk ###
##################################

# Creates report of backup jobs on dcbutlprdvbs01 and most of their non-default settings
function Get-VeeamOnsiteJobSettings {
    
    Get-VBRJob | ? JobType -eq Backup | select Name,
        Description,
        @{n='Enabled';e={$_.IsScheduleEnabled}},
        # If object is folder - get location, split path to get last two folders then rejoin. Else output name (of VM or tag)
        @{n='TargetVCFolderOrVMOrTag';e={
            ($_.GetObjectsInJob() | ? Type -eq Include | % {                
                if($_.TypeDisplayName -eq 'Folder'){
                    ($_.Location -split '\\|/')[-2..-1] -join '\'
                }else{
                    $_.Name
                }
            }) -join ', '
        }},
        @{n='ExcludedVCFolderOrVMOrTag';e={
            ($_.GetObjectsInJob() | ? Type -eq Exclude | % {                
                if($_.TypeDisplayName -eq 'Folder'){
                    ($_.Location -split '\\|/')[-2..-1] -join '\'
                }else{
                    $_.Name
                }
            }) -join ', '
        }},
        @{n='BackupRepo';e={$_.GetBackupTargetRepository().Name}},
        @{n='Retention';e={
            if($_.BackupStorageOptions.RetentionType -eq 'Cycles'){ $_.BackupStorageOptions.RetainCycles }
            if($_.BackupStorageOptions.RetentionType -eq 'Days'){ $_.BackupStorageOptions.RetainDays }
        }},
        @{n='RetentionType';e={$_.BackupStorageOptions.RetentionType}},        
        IsForeverIncremental,
        @{n='CompressionLevel';e={$_.BackupStorageOptions.CompressionLevel}},
        @{n='StorageBlockSize';e={$_.BackupStorageOptions.StgBlockSize}},        
        @{n='RemoveDelVMsFromBackup';e={$_.BackupStorageOptions.EnableDeletedVmDataRetention}},        
        @{n='UpdateVMAttribute';e={$_.ViSourceOptions.SetResultsToVmNotes}},
        @{n='VMAttributeToUpdate';e={$_.ViSourceOptions.VmAttributeName}},
        @{n='AppendToAttribute';e={$_.ViSourceOptions.VmNotesAppend}},
        @{n='FailoverToHostBackupFromSAN';e={$_.Options.SanIntegrationOptions.FailoverFromSan}},
        @{n='MultipleStorageSnapshots';e={$_.Options.SanIntegrationOptions.MultipleStorageSnapshotEnabled}},
        @{n='UseCBT';e={$_.ViSourceOptions.UseChangeTracking}},
        @{n='EnableCBTOnVMs';e={$_.ViSourceOptions.EnableChangeTracking}},
        @{n='AutoDetectBackupProxies';e={$_.SourceProxyAutoDetect}},
        @{n='AutoDetectGuestProxies';e={$_.VssOptions.GuestProxyAutoDetect}}
}

### Report Framework

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

$veeamOnsiteJobSettings = Get-VeeamOnsiteJobSettings

$reportContext = "Cycles = Restore Points<br>
CompressionLevel: -1 = Auto, 0 = None, 4 = Dedupe-friendly, 5 = Optimal, 6 = High, 9 = Extreme<br>
StorageBlockSize: KbBlockSize256 = WAN Target, KbBlockSize512 = LAN target, KbBlockSize1024 = Local Target, KbBlockSize4096 = Local Target (large blocks)<br>
FailoverToHostBackupFromSAN - If backup from storage snapshots fails, back up via ESXi host's management interface<br>
MultipleStorageSnapshots - Limit the number of VMs that can be backed up from the same storage snapshot"

$veeamOnsiteJobSettings |
ConvertTo-HtmlReport `
    -ReportTitle "Veeam Onsite Job Configuration" `
    -ReportDescription "Pertinent settings of onsite backup jobs on dcbutlprdvbs01 (DCA backup server)" `
    -ReportContext $reportContext `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\Html Reports\veeamonsitejobconfig.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "\\dcautlprdwrk01\c$\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\wwwroot\index.html" `
    -VirtualPath "/"