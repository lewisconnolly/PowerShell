function Get-iDRACConfiguration {

    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACName,

        $ptpwd
    )

    BEGIN {
        
        $WarningPreference = 'SilentlyContinue'
        $ErrorActionPreference = 'Stop'
    }

    PROCESS{
        $iDRACName | % {
            try{
                $iDrac = $_
                <#if(($iDrac -like "mkhost*")-or($iDrac -like "zhost*")){
                    $secpasswd = ConvertTo-SecureString -String (get-content $env:USERPROFILE\Documents\dc.txt)
                    $tempcred = New-Object System.Management.Automation.PSCredential ('temp', $secpasswd)
                    $ptpwd = $tempcred.GetNetworkCredential().Password
                }elseif($iDrac -like "zts*"){
                    $secpasswd = ConvertTo-SecureString -String (get-content $env:USERPROFILE\Documents\tf.txt)
                    $tempcred = New-Object System.Management.Automation.PSCredential ('temp', $secpasswd)
                    $ptpwd = $tempcred.GetNetworkCredential().Password
                }#>
                
                $iDracSettingsReport = [pscustomobject]@{}

                $iDracSettings = @(
                    'iDRAC.nic.DNSRacName'
                    'iDRAC.nic.DNSDomainName'
                    'idrac.info.ServerGen'
                    'iDRAC.IPv4.Address'
                    'System.ServerInfo.ServiceTag'
                    'iDRAC.IPv4.Gateway'
                    'iDRAC.IPv4.Netmask'
                    'iDRAC.IPv4.DNS1'
                    'iDRAC.IPv4.DNS2'
                    'iDRAC.Info.Version'
                    'idrac.ipmilan.AlertEnable'
                    'idrac.remotehosts.SMTPServerIPAddress'
                    'iDRAC.VirtualConsole.PluginType'
                    'bios.satasettings.WriteCache'
                    'bios.biosbootsettings.BootMode'
                    'bios.sysprofilesettings.SysProfile'
                    'system.thermalsettings.ThermalProfile'
                    'iDRAC.ipmilan.enable'
                    'iDRAC.SSH.enable'
                    'iDRAC.users'
                    'iDRAC.Time.Timezone'
                    'iDRAC.NTPConfigGroup.NTP1'
                    'idrac.NTPConfigGroup.NTPEnable'
                )

                $iDracSettings | % {
                    $Gen = ((C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $iDrac -u root -p $ptpwd get idrac.info.ServerGen) |
                    ? {$_ -like "ServerGen*"})
                    if(($_ -like "*ServiceTag")-and($Gen -notlike "*14G")){
                        $ServiceTag = ((C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $iDrac -u root -p $ptpwd getsvctag) |
                        ? {$_.length -eq 7})
                        $iDracSettingsReport | Add-Member -MemberType NoteProperty -Name 'ServiceTag' -Value $ServiceTag
                    }elseif($_ -like "*users"){
                        $i=1
                        $UserName = ''
                        while(($i -le 16)-and($UserName-notlike "*tsuser")){
                            $UserName = (C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $iDrac -u root -p $ptpwd get idrac.users.$i.UserName)|
                            ? {$_ -like "UserName*"}
                            $i++
                        }
                        if($UserName-notlike"*tsuser"){
                            $iDracSettingsReport | Add-Member -MemberType NoteProperty -Name 'tsuser' -Value 'Not created'    
                        }else {$iDracSettingsReport | Add-Member -MemberType NoteProperty -Name 'tsuser' -Value 'Created'}
                    }elseif(($_ -like "*WriteCache*")-and($Gen -like "*12G")) {
                        $iDracSettingsReport | Add-Member -MemberType NoteProperty -Name 'WriteCache' -Value 'Not available'
                    }else{
                        $ShortName = $_.split('.')[-1]

                        gv -Name $ShortName,"$($ShortName)Str" -ErrorAction SilentlyContinue | Remove-variable -ErrorAction SilentlyContinue
                        
                        nv -Name "$($ShortName)Str" -Value ((C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $iDrac -u root -p $ptpwd get $_) |
                        ? {$_ -like "$ShortName*"})
                        
                        $Str = (gv -Name "$($ShortName)Str").Value
                        nv -Name $ShortName -Value $Str.Substring($Str.IndexOf('=')+1)

                        switch((gv -Name $ShortName).Value){
                            {($Str -like "Plugin*")-and ($_ -eq '0')} { sv -Name $ShortName -Value 'ActiveX' }
                            {($Str -like "Plugin*")-and($_ -eq '1')} { sv -Name $ShortName -Value 'Java' }
                            {($Str -like "Plugin*")-and($_ -eq '2')} { sv -Name $ShortName -Value 'HTML5' }
                            Default {}
                        }
                        
                        if($_ -like "*ipmilan.enable"){
                            $iDracSettingsReport | Add-Member -MemberType NoteProperty -Name 'IPMILAN' -Value (gv -Name $ShortName).value    
                        }elseif($_ -like "*ssh.enable"){
                            $iDracSettingsReport | Add-Member -MemberType NoteProperty -Name 'SSH' -Value (gv -Name $ShortName).value    
                        }else{
                            $iDracSettingsReport | Add-Member -MemberType NoteProperty -Name $ShortName -Value (gv -Name $ShortName).value
                        }
                    }
                }
                #gv -Name $secpasswd,$tempcred,$ptpwd -ErrorAction SilentlyContinue | Remove-variable -ErrorAction SilentlyContinue
                $iDracSettingsReport
            }catch{throw}
        }
    }
    #END {}
}