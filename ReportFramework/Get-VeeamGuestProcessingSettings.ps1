########################################
### Get-VeeamGuestProcessingSettings ###
###    lewis.connolly@zonal.co.uk    ###
########################################

# Creates report of objects processed in Veeam backup jobs and their application-aware processing settings
function Get-VeeamGuestProcessingSettings {

    # Get all onsite backups
    $onsiteJobs = Get-VBRJob | ? JobType -eq Backup
    # Get all onsite job objects
    $VSSObjects = $onsiteJobs | Get-VBRJobObject 

    $VSSObjects | % {

        # Get per object guest processing options
        $VSSOptions = $_ | Get-VBRJobObjectVssOptions
        # Get job that object is processed in
        $id = $_.JobId.Guid
        $onsiteJob = $onsiteJobs | ? Id -eq $id
        
        # Check if job object not in job exclusion list and job guest processing setting is enabled and per object guest processing setting is enabled
        if(($_.Type -ne 'Exclude') -and $onsiteJob.VssOptions.Enabled -and $VSSOptions.Enabled){
            [PSCustomObject]@{
                Name = $_.Name
                ObjectType = $_.TypeDisplayName
                Job = $onsiteJob.Name                
                GuestProcessingEnabled = $true
                GuestProxyAutoDetect  = $VSSOptions.GuestProxyAutoDetect
                UsePersistentGuestAgent = $VSSOptions.VssSnapshotOptions.UsePersistentGuestAgent
                IgnoreErrors = $VSSOptions.IgnoreErrors
                FileExcludeEnabled = $VSSOptions.GuestfsExcludeOptions.FileExcludeEnabled
                ExcludeList = $VSSOptions.GuestfsExcludeOptions.ExcludeList -join '<br>'
                IncludeList = $VSSOptions.GuestfsExcludeOptions.IncludeList -join '<br>'
                ProcessSQLTransactionLogs = (-not$_.VssOptions.VssSnapshotOptions.IsCopyOnly)
            }
        }else{
            [PSCustomObject]@{
                Name = $_.Name
                ObjectType = $_.TypeDisplayName
                Job = $onsiteJob.Name                
                GuestProcessingEnabled = $false
                GuestProxyAutoDetect  = 'NA'
                UsePersistentGuestAgent = 'NA'
                IgnoreErrors = 'NA'
                FileExcludeEnabled = 'NA'
                ExcludeList = 'NA'
                IncludeList = 'NA'
                ProcessSQLTransactionLogs = 'NA'
            }
        }
    }
}    

### Report Framework

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

$veeamGuestProcessingSettings = Get-VeeamGuestProcessingSettings

$reportContext = "ProcessSQLTransactionLogs - Truncate transaction logs after backup (True) or copy only (False)<br>
Lower level of object guest processing enablement takes precedence. For example, if a folder object has guest processing disabled but a VM object in that folder has guest processing enabled, the VM is processed"

$veeamGuestProcessingSettings |
ConvertTo-HtmlReport `
    -ReportTitle "Veeam Guest Processing Configuration" `
    -ReportDescription "Application-aware backup settings of Veeam backup targets" `
    -ReportContext $reportContext `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\Html Reports\veeamguestprocessing.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "\\dcautlprdwrk01\c$\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\wwwroot\index.html" `
    -VirtualPath "/"