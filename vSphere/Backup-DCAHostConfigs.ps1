cd $PSScriptRoot

. .\Backup-HostConfigs.ps1

Backup-HostConfigs -BackupLocation "\\zonalconnect.local\backup$\ESXi_config_backups\DCA"  -FileRotation 2 -Server "vcenter" -Datacenter 'DCA'  | Out-File .\Backup-DCAHostConfigs.log -Append
    
if ($Error) {
        
    $MessageParameters = @{Subject = "DCA host config backup";From = "ztsReports@zonalconnect.com";To = "lewis.connolly@zonal.co.uk";SmtpServer = "mail.zonalconnect.local"}
    Send-MailMessage @messageParameters -Body 'Check attachments' -Attachments .\Backup-DCAHostConfigs.log
}