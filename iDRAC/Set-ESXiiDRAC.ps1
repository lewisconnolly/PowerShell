function Set-ESXiiDRAC
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $IdracIP,

        [ValidateNotNullOrEmpty()]
        $Password,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiName,

        [ValidateNotNullOrEmpty()]
        $SmtpServer = '172.31.1.122'
    )
 
    Process
    {
        try
        {
            $SvcTag = (((C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $iDRACIP -u root -p $Password getsvctag) -split "\n") | where {$_ -ne ""})[-1].ToLower()
            $iDRACName = "$(($ESXiName).TrimEnd(".zhost"))-iDRAC-$SvcTag"
            $iDRACMAC = ((C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $iDRACIP -u root -p $Password get iDRAC.nic.MACAddress) -split "\n" | where {$_ -like "MACAddress=*"}).TrimStart("MACAddress=")

            C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set iDRAC.nic.DNSRacName $iDRACName | Out-Null
            C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set iDRAC.nic.DNSDomainName zhost | Out-Null
            C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set IDRAC.EmailAlert.1.Address replace@me.co.uk | Out-Null
            C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set IDRAC.EmailAlert.1.Enable Enabled | Out-Null
            C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set idrac.remotehosts.SMTPServerIPAddress $SmtpServer | Out-Null
            C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set idrac.remotehosts.SMTPPort 25 | Out-Null
            C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set idrac.ipmilan.enable enabled | Out-Null    
            C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set system.thermalsettings.thermalprofile 'Maximum Performance' | Out-Null
            #C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p $Password set bios.SysProfileSettings.WorkloadProfile VtOptimizedProfile | Out-Null

            [psobject]@{
                SvcTag = $SvcTag
                iDRACName = $iDRACName
                iDRACIP = $IdracIP 
                iDRACMAC = $iDRACMAC
            }
        }
        catch {throw}
    }
}