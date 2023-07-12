##################################
###   Get-VeeamBackupVMStatus  ###
### lewis.connolly@zonal.co.uk ###
##################################

# Creates report of VMs and their backup status in Veeam
function Get-VeeamBackupVMStatus {
    
    $excludedFolders = '\\NB\\|\\Graylog\\|\\Veeam\\'
    $excludedVMs = 'dca-utl-mta02', 'dcautlprdome01', 'dcautlprdvsl01'

    $taskSessions = Get-VBRBackupSession | Where-Object {$_.EndTime -ge (Get-Date).AddDays(-40)} | % {
        
        $jobType = $_.JobTypeString
        $endTime = $_.EndTime

        $_.GetTaskSessions() |
        Select-Object Name,
            JobName,
            @{n='JobType';e={$jobType}},
            @{n='EndTime';e={$endTime}},
            @{n='ReadGB';e={[math]::Round(($_.Progress.ReadSize / 1GB), 2)}},
            @{n='TransferredGB';e={[math]::Round(($_.Progress.TransferedSize / 1GB), 2)}}
    }

    $DCAVMs = Find-VBRViEntity -VMsAndTemplates | ? {$_.Path -Like "vcenter\DCA*" -and $_.Id -Like '*_vm-*'}

    $DCAVMs | % {

        if ($curVMTaskSessions = $taskSessions | ? Name -eq $_.Name) {

            $lastOnsiteSession = $curVMTaskSessions | ? JobType -eq 'Backup' | sort EndTime -Descending | select -First 1 
            $lastOffsiteSession = $curVMTaskSessions | ? JobType -ne 'Backup' | sort EndTime -Descending | select -First 1
            
            $_ |
            Select-Object @{l='Status';e={'OK'}},
                Name,
                Path,
                PowerState,
                IsTemplate,
                @{l='VMSizeGB';e={[math]::Round(($_.UsedSize / 1GB), 2)}},
                @{l='OnsiteBackupJobName';e={$lastOnsiteSession.JobName}},
                @{l='LastOnsiteBackupTime';e={$lastOnsiteSession.EndTime}},
                @{l='LastOnsiteBackupReadGB';e={$lastOnsiteSession.ReadGB}},
                @{l='LastOnsiteBackupTransferredGB';e={$lastOnsiteSession.TransferredGB}},
                @{l='OffsiteJobName';e={$lastOffsiteSession.JobName}},
                @{l='LastOffsiteBackupTime';e={$lastOffsiteSession.EndTime}}

        } else {
        
            $_ |
            Select-Object @{l='Status';e={if($_.Path -notmatch $excludedFolders -and $_.Name -notin $excludedVMs){ 'Warning' }else{ 'OK' }}},
                Name,
                Path,
                PowerState,
                IsTemplate,
                @{l='VMSizeGB';e={[math]::Round(($_.UsedSize / 1GB), 2)}},
                @{l='OnsiteBackupJobName';e={'None'}},
                @{l='LastOnsiteBackupTime';e={'NA'}},
                @{l='LastOnsiteBackupReadGB';e={'NA'}},
                @{l='LastOnsiteBackupTransferredGB';e={'NA'}},
                @{l='OffsiteJobName';e={'None'}},
                @{l='LastOffsiteBackupTime';e={'NA'}}
        }

    } | Sort-Object @{e='Status';d='True'}, VmFolderName, Name
}    


### Report Framework

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

$veeamBackupVMStatus = Get-VeeamBackupVMStatus

$reportContext = "Last 40 days of backup sessions are checked<br>
Status OK if no backup found for VMs in vCenter folders: 'NB', 'Graylog', 'Veeam'<br>
Status OK if no backup found for specific VMs: 'dca-utl-mta02', 'dcautlprdome01', 'dcautlprdvsl01'<br>
HAProxy job currently disabled because VM stunning of those VMs caused problems<br><br>
ReadGB - Amount of changed data for each VM disk read from the datastore prior to any deduplication and compression<br>
TransferredGB - Data transferred from source to repo after reductions from compression and deduplication from CBT and against previous restore point"

$veeamBackupVMStatus |
ConvertTo-HtmlReport `
    -ReportTitle "Veeam Backup VM Status" `
    -ReportDescription "Last onsite and offsite backup times for DCA VMs" `
    -ReportContext $reportContext `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\Html Reports\veeambackupstatus.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "\\dcautlprdwrk01\c$\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\wwwroot\index.html" `
    -VirtualPath "/"