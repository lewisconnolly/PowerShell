cd $PSScriptRoot

. .\Backup-HostConfigs.ps1

Backup-HostConfigs -BackupLocation "\\path_to_backup_location"  -FileRotation 2 -Server "vcenter" -Datacenter 'DCB'  | Out-File .\Backup-DCBHostConfigs.log -Append
    
if ($Error) {
        
    $MessageParameters = @{Subject = "DCB host config backup";From = "replace@me.com";To = "replace@me.co.uk";SmtpServer = "mail.replace.me"}
    Send-MailMessage @messageParameters -Body 'Check attachments' -Attachments .\Backup-DCBHostConfigs.log
}
