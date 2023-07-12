cd $PSScriptRoot

. .\Backup-HostConfigs.ps1

Backup-HostConfigs -BackupLocation "\\zonalconnect.local\backup$\ESXi_config_backups\TF"  -FileRotation 2 -Server "vcenter" -Datacenter 'TF'  | Out-File .\Backup-TFHostConfigs.log -Append
    
if ($Error) {
        
    $MessageParameters = @{Subject = "TF host config backup";From = "ztsReports@zonalconnect.com";To = "lewis.connolly@zonal.co.uk";SmtpServer = "mail.zonalconnect.local"}
    Send-MailMessage @messageParameters -Body 'Check attachments' -Attachments .\Backup-TFHostConfigs.log
}