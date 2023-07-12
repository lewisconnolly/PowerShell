gvh | % {
    $lastoct = ($_ | get-vmhostnetworkadapter -name 'vmk0').IP.Split('.')[-1]
    $lastoct = [int]$lastoct + 1
    $idracip = "172.31.1.$lastoct"
    $idracname = $_.name.Replace('.zhost','') + "-idrac"
    $dnsname = $idracname + ".zonalconnect.local"
    Out-Default -InputObject "`nSetting idrac host name to $idracname on $($_.name)...`n"
    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip  -u root -p 'zh0st1ng' set iDRAC.nic.DNSRacName $idracname | Out-Null
    Out-Default -InputObject "`nSetting idrac dns name to $dnsname on $($_.name)...`n"
    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $IdracIP  -u root -p 'zh0st1ng' set iDRAC.nic.DNSDomainName $dnsname | Out-Null
}
