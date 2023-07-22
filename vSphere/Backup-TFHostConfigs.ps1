cd $PSScriptRoot

. .\Backup-HostConfigs.ps1

Backup-HostConfigs -BackupLocation "\\path_to_backup_location"  -FileRotation 2 -Server "vcenter" -Datacenter 'TF'  | Out-File .\Backup-TFHostConfigs.log -Append
    
if ($Error) {
        
    $MessageParameters = @{Subject = "TF host config backup";From = "replace@me.com";To = "replace@me.co.uk";SmtpServer = "mail.replace.me"}
    Send-MailMessage @messageParameters -Body 'Check attachments' -Attachments .\Backup-TFHostConfigs.log
}