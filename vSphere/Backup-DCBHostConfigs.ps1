cd $PSScriptRoot

. .\Backup-HostConfigs.ps1

Backup-HostConfigs -BackupLocation "\\zonalconnect.local\backup$\ESXi_config_backups\DCB"  -FileRotation 2 -Server "vcenter" -Datacenter 'DCB'  | Out-File .\Backup-DCBHostConfigs.log -Append
    
if ($Error) {
        
    $MessageParameters = @{Subject = "DCB host config backup";From = "ztsReports@zonalconnect.com";To = "lewis.connolly@zonal.co.uk";SmtpServer = "mail.zonalconnect.local"}
    Send-MailMessage @messageParameters -Body 'Check attachments' -Attachments .\Backup-DCBHostConfigs.log
}
