function Set-ESXiConfigiDRAC
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACIP,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $User,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Password,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHostname,

        [ValidateNotNullOrEmpty()]
        $NewiDRACIP,

        [ValidateNotNullOrEmpty()]
        $SMTPServer,

        [ValidateNotNullOrEmpty()]
        $DNS = @('172.31.6.136','172.31.6.137'),

        [ValidateNotNullOrEmpty()]
        $BootMode = 'Uefi',

        [ValidateNotNullOrEmpty()]
        $NTPServer = 'uk.pool.ntp.org',

        [ValidateNotNullOrEmpty()]
        [ValidateSet('7542', '6150')]
        [String[]]
        $Processor,

        [switch]
        $Reboot
    )

    Process
    {
        try
        {
            if(Test-Path "C:\Program` Files\Dell\SysMgt\rac5\racadm.exe")
            {                
                $racadm = "C:\Program` Files\Dell\SysMgt\rac5\racadm.exe"
                
                Start-Process $racadm -Args @("-r $iDRACIP -u $User -p $Password get idrac.info.name") -Wait -NoNewWindow `
                -RedirectStandardOutput .\racadmOutput.txt
                $racadmOutput = cat .\racadmOutput.txt
                
                if($racadmOutput -notmatch 'Login failed')
                {                    
                    $args_set = "-r $iDRACIP -u $User -p $Password set"
                    $DNSRacName = $ESXiHostname -replace '\.zhost','-idrac'                    
                    $settings =
                    @(
                        # Virtual Console
                        
                        "iDRAC.VirtualConsole.PluginType HTML5"
                      
                        # VNC Server

                        "iDRAC.VNCServer.Enable Enabled"
                        "iDRAC.VNCServer.Password $Password"

                        # Alert Configuration

                        "iDRAC.IPMILAN.AlertEnable Enabled"
                        "iDRAC.EmailAlert.1.address replace@me.co.uk"
                        "iDRAC.EmailAlert.1.Enable Enabled"
                        "iDRAC.RemoteHosts.SMTPServerIPAddress $SMTPServer"
                        "iDRAC.RemoteHosts.SenderEmail $DNSRacName@zhost.local"

                        # Remote Syslog Settings

                        "iDRAC.SysLog.Server1 172.31.11.111"
                        "iDRAC.SysLog.Port 1514"
                        "iDRAC.SysLog.SysLogEnable Enabled"

                        # Cooling Configuration

                        "System.ThermalSettings.ThermalProfile 'Maximum Performance'"
                        
                        # Memory Settings

                        "BIOS.MemSettings.MemTest Disabled"                        
                        "BIOS.MemSettings.MemOpMode OptimizerMode"
                        "BIOS.MemSettings.CorrEccSmi Enabled"
                        "BIOS.MemSettings.OppSrefEn Disabled"

                        # Processor Settings

                        "BIOS.ProcSettings.LogicalProc Enabled"
                        "BIOS.ProcSettings.ProcVirtualization Enabled"                        
                        "BIOS.ProcSettings.ProcX2Apic Enabled"

                        # SATA Settings

                        "BIOS.SataSettings.EmbSata AhciMode"
                        "BIOS.SataSettings.SecurityFreezeLock Enabled"
                        "BIOS.SataSettings.WriteCache Disabled"

                        # Boot Settings
                        
                        "iDRAC.ServerBoot.BootOnce Disabled"
                        "iDRAC.ServerBoot.FirstBootDevice SD"
                        "BIOS.BiosBootSettings.BootMode $BootMode"
                        "BIOS.BiosBootSettings.BootSeqRetry Enabled"                        
                        
                        # Integrated Devices

                        "BIOS.IntegratedDevices.UsbPorts AllOffDynamic"
                        "BIOS.IntegratedDevices.UsbEnableFrontPortsOnly Disabled"
                        "BIOS.IntegratedDevices.InternalUsb Off"
                        "BIOS.IntegratedDevices.UsbManagedPort On"
                        "BIOS.IntegratedDevices.EmbVideo Enabled"
                        "BIOS.IntegratedDevices.SriovGlobalEnable Disabled"
                        "BIOS.IntegratedDevices.InternalSdCard On"
                        "BIOS.IntegratedDevices.InternalSdCardRedundancy Mirror"
                        "BIOS.IntegratedDevices.InternalSdCardPrimaryCard SdCard1"
                        "BIOS.IntegratedDevices.OsWatchdogTimer Disabled"

                        # Serial Communication

                        "BIOS.SerialCommSettings.SerialComm Off"

                        # System Profile Settings

                        "BIOS.SysprofileSettings.SysProfile PerfOptimized"

                        # Network/Common Settings

                        "iDRAC.NIC.DNSRacName $DNSRacName"
                        "iDRAC.NIC.DNSDomainName zhost.local"
                        
                        # IPMI Settings 

                        "iDRAC.IPMILAN.Enable Enabled"

                        # OS to iDRAC Pass-through

                        "iDRAC.OS-BMC.AdminState Enabled"
                        "iDRAC.OS-BMC.PTMode usb-p2p"

                        # TLS

                        "iDRAC.WebServer.TLSProtocol 'TLS 1.2 Only'"

                        # SSH

                        "iDRAC.SSH.Enable Enabled"
                        
                        # SNMP Agent

                        "iDRAC.SNMP.AgentEnable Enabled"
                        "iDRAC.SNMP.AgentCommunity zts_community"
                        "iDRAC.SNMP.SNMPProtocol All"

                        # Automated System Recovery Agent
                         
                        "iDRAC.ASRConfig.Enable Disabled"

                        # Time Zone and NTP Settings

                        "iDRAC.Time.Timezone UTC"
                        "iDRAC.NTPConfigGroup.NTP1 $NTPServer"
                        "iDRAC.NTPConfigGroup.NTPEnable Enabled"

                        # iDRAC Service Module Setup

                        "iDRAC.ServiceModule.ServiceModuleEnable Enabled"
                        "iDRAC.ServiceModule.OSInfo Enabled"
                        "iDRAC.ServiceModule.ChipsetSATASupported Disabled"
                        "iDRAC.ServiceModule.HostSNMPAlert Disabled"
                        "iDRAC.ServiceModule.HostSNMPGet Disabled"
                        "iDRAC.ServiceModule.iDRACHardReset Disabled"
                        "iDRAC.ServiceModule.iDRACSSOLauncher Disabled"
                        "iDRAC.ServiceModule.LCLReplication Disabled"
                        "iDRAC.ServiceModule.SSEventCorrelation Disabled"
                        "iDRAC.ServiceModule.WatchdogState Disabled"
                        "iDRAC.ServiceModule.WMIInfo Disabled"            
                    )

                    if($Processor -eq '7542')
                    {
                        $settings +=
                        "BIOS.BiosBootSettings.GenericUsbBoot Disabled"
                        "BIOS.BiosBootSettings.HddPlaceholder Disabled"
                        "BIOS.IntegratedDevices.IntegratedRaid Disabled"
                        "BIOS.IntegratedDevices.EmbNic1Nic2 DisabledOs"
                        "BIOS.IntegratedDevices.PciePreferredIoDevice Disabled"
                        "BIOS.ProcSettings.IommuSupport Enabled",
                        "BIOS.ProcSettings.L1StreamHwPrefetcher Enabled",
                        "BIOS.ProcSettings.L2StreamHwPrefetcher Enabled",
                        "BIOS.ProcSettings.MadtCoreEnumeration Linear",
                        "BIOS.ProcSettings.NumaNodesPerSocket 1",
                        "BIOS.ProcSettings.CcxAsNumaDomain Enabled",
                        "BIOS.ProcSettings.CcdCores All",
                        "BIOS.ProcSettings.ProcCcds All",
                        "BIOS.ProcSettings.CpuMinSevAsid 1",
                        "BIOS.NetworkSettings.PxeDev1EnDis Enabled",
                        "BIOS.NetworkSettings.PxeDev2EnDis Enabled",
                        "BIOS.NetworkSettings.PxeDev3EnDis Enabled",
                        "BIOS.NetworkSettings.PxeDev4EnDis Enabled",
                        "BIOS.PxeDev1Settings.PxeDev1Interface NIC.Slot.2-1-1",
                        "BIOS.PxeDev2Settings.PxeDev2Interface NIC.Slot.2-2-1",
                        "BIOS.PxeDev3Settings.PxeDev3Interface NIC.Slot.3-1-1",
                        "BIOS.PxeDev4Settings.PxeDev4Interface NIC.Slot.3-2-1"
                    }

                    if($Processor -eq '6150')
                    {
                        $settings +=
                        "BIOS.MemSettings.NativeTrfcTiming Disabled",
                        "BIOS.MemSettings.AdddcSetting Enabled",
                        "BIOS.ProcSettings.ProcAdjCacheLine Enabled",
                        "BIOS.ProcSettings.ProcHwPrefetcher Enabled",
                        "BIOS.ProcSettings.ProcSwPrefetcher Enabled",
                        "BIOS.ProcSettings.DcuStreamerPrefetcher Enabled",
                        "BIOS.ProcSettings.DcuIpPrefetcher Enabled",
                        "BIOS.ProcSettings.SubNumaCluster Disabled",
                        "BIOS.ProcSettings.UpiPrefetch Enabled",
                        "BIOS.ProcSettings.ProcConfigTdp Nominal",
                        "BIOS.ProcSettings.ProcCores All"
                    }


                    function RacadmSet ($RacadmPath,$RacadmArgs,$SettingAndValue)
                    {
                        $setting = "$(($SettingAndValue -split ' ')[0])"
                        $val = $SettingAndValue -replace "$setting ",''

                        "`nSetting $setting to $val`n" | Write-Host -ForegroundColor Cyan

                        Start-Process $RacadmPath -Args @($RacadmArgs,$SettingAndValue) -Wait -NoNewWindow -RedirectStandardOutput .\racadmOutput.txt
                        $racadmOutput = cat .\racadmOutput.txt
                        if($racadmOutput -match 'successfully'){$colour='Green'}else{$colour='DarkYellow'}
                        ($racadmOutput -match '[a-z]')[2..($racadmOutput.count-1)] |
                        Write-Host -ForegroundColor $colour
                    }

                    $settings | % {
                        
                        RacadmSet -RacadmPath $racadm -RacadmArgs $args_set -SettingAndValue $_
                    }

                    if ($DNS.count -gt 1)
                    {
                        "`nSetting iDRAC.IPv4.DNS1, iDRAC.IPv4.DNS2 to $($DNS -join ', ')`n" |
                        Write-Host -ForegroundColor Cyan
                        
                        RacadmSet -RacadmPath $racadm -RacadmArgs $args_set -SettingAndValue "iDRAC.IPv4.DNS1 $($DNS[0])"
                        
                        RacadmSet -RacadmPath $racadm -RacadmArgs $args_set -SettingAndValue "iDRAC.IPv4.DNS2 $($DNS[1])"
                    }
                    else
                    {
                        "`nSetting iDRAC.IPv4.DNS1 to $DNS`n" | Write-Host -ForegroundColor Cyan

                        RacadmSet -RacadmPath $racadm -RacadmArgs $args_set -SettingAndValue "iDRAC.IPv4.DNS1 $DNS"
                    }

                    if($NewiDRACIP)
                    {
                        "`nSetting iDRAC.IPv4.Address to $NewiDRACIP`n" | Write-Host -ForegroundColor Cyan

                        RacadmSet -RacadmPath $racadm -RacadmArgs $args_set -SettingAndValue "iDRAC.IPV4.Address $NewiDRACIP"
                    }

                    Start-Process $racadm -args @(($args_set -replace 'set','jobqueue create BIOS.Setup.1-1')) -Wait -NoNewWindow

                    if($Reboot)
                    {
                        Start-Process $racadm -args @(($args_set -replace 'set','serveraction powercycle')) -Wait -NoNewWindow
                    }
                }
                else
                {
                    'Login failed - invalid username or password. Exiting...' |
                     Write-Host -ForegroundColor Red
                }
            }
            else
            {
                "`nUnable to configure $iDRACIP `n`nPlease install racadm.exe to:`n`n`tC:\Program` Files\Dell\SysMgt\rac5\racadm.exe`n" |
                Write-Warning 
            }
        }
        catch {throw}
    }
}

function Set-ESXiRoot
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $SvcTag,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiIP,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $NewPassword,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ViServer,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $DomainCred = $lcred
    )
    Process
    {
        try
        {
            $Connected = Confirm-VIServerConnection -ViServer $ViServer -Credential $DomainCred
            if ($Connected -eq $null) {
                $VMHostNames = (Get-VMHost).Name
                if ($VMHostNames -notcontains $ESXiName){
                    Connect-VIServer $ESXiIP -User root -Password ($SvcTag.ToUpper()) | Out-Null
                    Get-VMHostAccount -Server $ESXiIP -User root | Set-VMHostAccount -Password $NewPassword | Out-Null
                    
                    Disconnect-VIServer -Server $ESXiIP -Confirm:$false | Out-Null
                } else {Write-Host 'Host with same name already in cluster.'}
            } else {Write-Host 'Host domain name, search domain, password, cluster and DNS not set.'}
        }
        catch {throw}
    }
}

function Add-ESXiHost 
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Password,

        [ValidateNotNullOrEmpty()]
        $ViServer = 'dca-vcenter',
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $DatacenterName,

        [ValidateNotNullOrEmpty()]
        $ClusterName,

        [ValidateNotNullOrEmpty()]
        $DomainCred = $lcred
    )
    Process
    {
        try
        {
            $Connected = Confirm-VIServerConnection -ViServer $ViServer -Credential $DomainCred
            if ($Connected -eq $null) {
                $VMHostNames = (Get-VMHost).Name
                if ($VMHostNames -notcontains $ESXiName){
                    
                    $Location = Get-Datacenter $DatacenterName
                    if($ClusterName){
                        $Location = Get-Cluster $ClusterName
                    }
                    Add-VMHost -Name $ESXiName -User root -Password $Password -Location $Location -Force | Out-Null #Force ignores self-signed cert warning
                    $ESXiHost = Get-VMHost $ESXiName 
                    [psobject]@{
                        ESXiHost = $ESXiHost
                        ESXiParent = $Location
                    }

                } else {Write-Host 'Host with same name already in vCenter.'}
            } else {Write-Host 'Host not added.'}
        }
        catch {throw}
    }
}

function Set-ESXiMaintenanceMode
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,
        
        [Parameter(ParameterSetName='enter')]
        [switch]$Enter,
        
        [Parameter(ParameterSetName='exit')]
        [switch]$Exit
    )

    Process {
        TRY
        {
            if ($Enter) {
                $ESXiHost | Set-VMHost -State Maintenance
            } elseif ($Exit) {
                $ESXiHost | Set-VMHost -State Connected
            }
        } catch {throw}
    }
}

function Set-ESXiPowerManagement
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost
    )
    Process
    {
        try
        {
            Get-VMHost $ESXiHost | % {

                $HostPowerSystem = Get-view (get-vmhost $_).ExtensionData.ConfigManager.PowerSystem
                $HostPowerSystem.ConfigurePowerPolicy(1) | Out-Null
                $HostPowerSystem.Info.CurrentPolicy
            }
        } catch {throw}      
    }
}

function Set-ESXiIPMIInfo
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        $ESXiHostname,
        [Parameter(Mandatory=$true)]
        $iDRACIP,
        [Parameter(Mandatory=$true)]
        $User,
        [Parameter(Mandatory=$true)]
        $Password
    )
    Process
    {
        try
        {
            if(!(Test-Path "C:\Program` Files\Dell\SysMgt\rac5\racadm.exe"))
            {
                "`n`nUnable to configure $_ `n`nPlease install racadm.exe to:`n`n`tC:\Program` Files\Dell\SysMgt\rac5\racadm.exe" |
                Write-Warning 

                break
            }
            else
            {
                Get-VMHost $ESXiHostname | % {

                    [regex]$ptn = '[A-Za-z0-9]{2}:[A-Za-z0-9]{2}:[A-Za-z0-9]{2}:[A-Za-z0-9]{2}:[A-Za-z0-9]{2}:[A-Za-z0-9]{2}'

                    $mac = . "C:\Program` Files\Dell\SysMgt\rac5\racadm.exe" -r $iDRACIP -u $User -p $Password get iDRAC.nic.MACAddress
                    $mac = $ptn.Matches($mac -join "`n").Value
                
                    $HostConfig = Get-view (get-vmhost $_)
                    $ipmiinfo = New-Object VMware.Vim.HostIpmiInfo
                    $ipmiinfo.BmcIpAddress=$iDRACIP
                    $ipmiinfo.BmcMacAddress=$mac
                    $ipmiinfo.Login = $User
                    $ipmiinfo.Password = $Password
                    $HostConfig.UpdateIpmi($ipmiinfo)
                    $_.config.ipmi

                    $ipmiinfo
                }
            }
        } catch {throw}      
    }
}

function Set-ESXiSSH
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,

        [ValidateNotNullOrEmpty()]
        $AuthenticatedIPs = @('172.31.6.133',
                            '172.30.6.133')
    )
    Process
    {
        try
        {
            Get-VMHost $ESXiHost | % {
                
                $SshService = $_ | Get-VMHostService | where Key -eq 'TSM-SSH'
                Set-VMHostService -HostService $SshService -policy 'on' -Confirm:$false
                Start-VMHostService -HostService $SshService -Confirm:$false

                $_ | Get-AdvancedSetting -name 'UserVars.SuppressShellWarning' |
                ? Value -ne '1' | Set-AdvancedSetting -Value '1' -Confirm:$false
                
                $_ | Get-AdvancedSetting -Name 'UserVars.ESXiShellInteractiveTimeOut' |
                ? Value -ne 86400 | Set-AdvancedSetting -Value 86400 -Confirm:$false
                
                if($AuthenticatedIPs) {
                    $HostFirewallSystem = Get-View $_.ExtensionData.ConfigManager.FirewallSystem
                
                    $HostFirewallRulesetIpSpec = New-Object VMware.Vim.HostFirewallRulesetRulesetSpec
                    $HostFirewallRulesetIpList = new-object VMware.Vim.HostFirewallRulesetIpList 
                    $HostFirewallRulesetIpList.IpAddress = $AuthenticatedIPs
                    $HostFirewallRulesetIpSpec.AllowedHosts = $HostFirewallRulesetIpList

                    $HostFirewallSystem.UpdateRuleset('sshServer',$HostFirewallRulesetIpSpec)
                }
            }
        } catch {throw}
    }
}

function Set-ESXiNTP
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,

        [ValidateNotNullOrEmpty()]
        $NTP
    )
    Process
    {
       try
        {
            Get-VMHost $ESXiHost | % {
                
                $NtpService = $_ | Get-VMHostService | where Key -eq 'ntpd'
                Set-VMHostService -HostService $NtpService -policy 'on' -Confirm:$false

                $HostDateTimeSystem = Get-View (Get-VMHost $_).ExtensionData.ConfigManager.DateTimeSystem

                $HostDateTimeConfig = New-Object VMware.Vim.HostDateTimeConfig
                $HostNtpConfig = New-Object VMware.Vim.HostNtpConfig
                $HostNtpConfig.server = $NTP
                $HostDateTimeConfig.NtpConfig = $HostNtpConfig

                $HostDateTimeSystem.UpdateDateTimeConfig($HostDateTimeConfig)
            
                Start-VMHostService -HostService $NtpService -Confirm:$False
            }
        } catch {throw}
    }
}

function Set-ESXiSNMP
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,

        [ValidateNotNullOrEmpty()]
        $Community = 'zts_community'
    )
    Process
    {
       try
        {
            $ESXiHost | % {
                
                $esxcli = Get-EsxCli -VMHost $_ -V2 

                $args = $esxcli.system.snmp.set.CreateArgs() 

                $args.enable = $true 

                $args.communities = $Community 

                $esxcli.system.snmp.set.Invoke($args) | Out-Null

                $esxcli.system.snmp.get.Invoke() 
            }
        } catch {throw}
    }
}

function Set-ESXiServices
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,
  
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ReferenceHost
    )
    Process
    {
        try {
            foreach ($esxi in $ESXiHost) {

                $Services = Get-VMHostService -VMHost $ReferenceHost
                Get-VMHostService -VMHost $esxi |
                % {
                    $RefSvc = ($Services| ? key -eq $_.key)
                    $Svc = $_
                    
                    if ($RefSvc) {
                        $Svc |
                        Set-VMHostService -Policy $RefSvc.Policy -ErrorAction SilentlyContinue
                
                        if ($RefSvc.Running -eq $true){
                            $Svc | Start-VMHostService -Confirm:$false
                        } else {$Svc | Stop-VMHostService -Confirm:$false} 
                    }
                }
            }
        } catch {throw}
    }      
}

function Set-ESXiFirewall
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,
  
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ReferenceHost
    )
    Process
    {
        try{
            $Exceptions =  Get-VMHostFirewallException -VMHost $ReferenceHost
            
            foreach ($esxi in $ESXiHost) {

                Get-VMHostFirewallException -VMHost $esxi |
                % {
                    $curRule = $_
                    if (($Exceptions | ? name -eq $curRule.name).name) {
                        Get-VMHostFirewallException -VMHost $esxi -Name ($Exceptions | ? name -eq $curRule.name).name |
                        Set-VMHostFirewallException -Enabled ($Exceptions | ? name -eq $curRule.name).Enabled
                    }
                }
            }
        } catch {throw}
    }      
}

function Add-ESXiSwitches 
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,

        [ValidateNotNullOrEmpty()]
        $NoOfVswitches = 1
    )
    Process
    {
        try
        {
            $ESXiHost | % {
                
                if ((Get-VirtualSwitch -VMHost $_ -Name vSwitch0).nic -notcontains 'vmnic1') {
                    $Vswitch0 = $ESXiHost | Get-VirtualSwitch -name vswitch0
                    $Vswitch0 | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic `
                    (Get-VMHostNetworkAdapter -VMHost $_ -Name vmnic1) -Confirm:$False
                    $Vswitch0 | Set-VirtualSwitch -Mtu 1500 -Confirm:$False
                }
                
                for ($i=1; $i -le $NoOfVswitches; $i++){
                    $VswitchName = New-InputBox -Title "vSwitch$i" -Text "Enter vSwitch$i name:" -DefaultInput "vSwitch$i"
                    $Vswitch = New-VirtualSwitch -Name $vSwitchName -VMHost $_
                    $MTU = New-InputBox -Title 'MTU' -Text 'Enter MTU:' -DefaultInput '9000'
                    $Adapter = Get-VMHostNetworkAdapter -VMHost $_ | ogv -PassThru -Title 'Select adapter'
                    $Vswitch | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $Adapter -Confirm:$false
                    $Vswitch | Set-VirtualSwitch -Mtu $MTU -Confirm:$false
                }
            }
        } catch {throw}
    }
}

function Add-ESXiPortGroups
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        $ESXiHost,
        
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        $NoOfPortGroups = 4
    )
    Process
    {
        try
        {
            $ESXiHost | % {
                
                for ($i=1; $i -le $NoOfPortGroups; $i++){
                        
                    $PortGroupsName = New-InputBox -Title 'PortGroup name' -Text "Enter PortGroup name $i :" -DefaultInput ''
                    $VlanIdStart = New-InputBox -Title 'Start VLAN ID' -Text 'Enter start VLAN ID:' -DefaultInput ''
                    $VlanIdEnd = New-InputBox -Title 'End VLAN ID' -Text 'Enter end VLAN ID:' -DefaultInput ''
                    $VlanIds = @($VlanIdStart..$VlanIdEnd)
                    $Vswitch = Get-VMHost $_ | Get-VirtualSwitch | ogv -PassThru -Title 'Select virtual switch'
                    if($VlanIds.Count -gt 1){
                        $VlanIds | % {New-VirtualPortGroup -Name "$PortGroupsName $_" -VirtualSwitch $Vswitch -VLanId $_}
                    } else {
                        $PortGroup = New-VirtualPortGroup -Name "$PortGroupsName" -VirtualSwitch $Vswitch -VLanId $VlanIds[0]
                        
                        $ActiveAdapters = Get-VMHostNetworkAdapter -VMHost $_ -VirtualSwitch $Vswitch -Physical |
                        ogv -PassThru -Title 'Select active adapter'
                        $UnusedAdapters = Get-VMHostNetworkAdapter -VMHost $_ -VirtualSwitch $Vswitch -Physical |
                        ogv -PassThru -Title 'Select unused adapter'

                        if ($ActiveAdapters) {
                            $PortGroup | Get-NicTeamingPolicy |
                            Set-NicTeamingPolicy -MakeNicActive $ActiveAdapters -Confirm:$False
                        }
                        if ($UnusedAdapters) {
                            $PortGroup | Get-NicTeamingPolicy |
                            Set-NicTeamingPolicy -MakeNicUnused $UnusedAdapters -Confirm:$False
                        }   
                    }
                }           
            }
        } catch {throw}
    }
}

function Add-ESXiVmks
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        $ESXiHost,
        
        [ValidateNotNullOrEmpty()]
        $NoOfVmks = 3
    )
    Process
    {
        try
        {
            $ESXiHost | % {
                
                for ($i=1; $i -le $NoOfVmks; $i++){
                        
                    $IP = New-InputBox -Title 'IP' -Text 'Enter IP:' -DefaultInput ''
                    $PortGroup = Get-VMHost $_ | Get-VirtualPortGroup | ogv -PassThru -Title 'Select port group'
                    $Vswitch = $PortGroup.VirtualSwitch
                    
                    if($PortGroup.name -match 'vMotion'){
                        New-VMHostNetworkAdapter -VMHost $_ -PortGroup $PortGroup -virtualSwitch $Vswitch `
                        -IP $IP -SubNetMask '255.255.255.0' -MTU 9000 -vMotionEnabled:$True
                    } else {
                        New-VMHostNetworkAdapter -VMHost $_ -PortGroup $PortGroup -virtualSwitch $Vswitch `
                        -IP $IP -SubNetMask '255.255.255.0' -MTU 9000 
                    }
                }   
            }           
        } catch {throw}
    }
}

function Add-ESXiPureFlashArray
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ESXiHostname,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $HBADevice,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $FlashArray,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $FlashArrayHostGroup,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $DomainCredential

    )
    Process
    {
        try
        {
            $ESXiHostname | % {
                
                $IQN = (Get-VMHost $_ | Get-VMHostHba -Device $HBADevice).IScsiName
                $FA = New-PfaArray `
                    -EndPoint $FlashArray `
                    -UserName $DomainCredential.UserName `
                    -Password $DomainCredential.Password `
                    -IgnoreCertificateError
                
                $PfaHost = $_.TrimEnd('.zhost')
                
                $PfaHostEntry = Get-PfaHost -Array $FA -Name $PfaHost -ErrorAction Ignore

                if($PfaHostEntry -eq $null)
                {
                    New-PfaHost -Array $FA -Name $PfaHost
                    Add-PfaHostIqns -Array $FA -Name $PfaHost -AddIqnList $IQN
                }
                else
                {
                    "`nHost already exists`n" | Write-Host -ForegroundColor DarkYellow
                    
                    $PfaHostEntry
                }

                if($_ -notin (Get-PfaHostGroup -Array $FA -Name $FlashArrayHostGroup).hosts)
                {
                    Add-PfaHosts -Array $FA -Name $FlashArrayHostGroup -HostsToAdd $PfaHost
                }
                else
                {
                    "`nHost already added`n" | Write-Host -ForegroundColor DarkYellow

                    Get-PfaHostGroup -Array $FA -Name $FlashArrayHostGroup |
                    select @{n='host';e={$_.hosts |? {$_ -eq $PfaHost}}},name
                }
            }
        }
        catch {throw}
    }
}

function Set-ESXiPersonalityPureFlashArray{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ESXiHostname,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $FlashArray,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $DomainCredential

    )
        
    $ESXiHostname | % {
        
        $FA = New-PfaArray `
            -EndPoint $FlashArray `
            -UserName $DomainCredential.UserName `
            -Password $DomainCredential.Password `
            -IgnoreCertificateError
        
        $PfaHost = $_.TrimEnd('.zhost')
        
        $PfaHostEntry = Get-PfaHost -Array $FA -Name $PfaHost -ErrorAction Ignore

        if($PfaHostEntry){
            
            Set-PfaPersonality -Array $FA -Name $PfaHost -Personality 'esxi'
        }
        else{
            "`nHost $PfaHost doesn't exist`n" | Write-Host -ForegroundColor DarkYellow                    
        }                
    }            
}

function Add-ESXiIscsiNetwork
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        $ESXiHost,
        
        [ValidateNotNullOrEmpty()]
        $TargetIPs = @('172.31.254.254','172.31.254.201'),
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $DomainCred = $lcred
    )
    Process
    {
        try
        {
            $ESXiHost | % {
                
                if ((Get-VMHostStorage -VMHost $_).SoftwareIScsiEnabled -eq $false){
                    Get-VMHostStorage -VMHost $_ | Set-VMHostStorage -SoftwareIScsiEnabled $true
                }
                $IscsiHBA = Get-VMHostHba -Type iscsi -VMHost $_ | where model -match 'software'

                Add-ESXiToPure -ESXiHost $_ -DomainCred $lcred
                
                Read-Host -Prompt "Enter to continue when $($ESXiHost.Name) IQN:`n$($IscsiHBA.IscsiName)`nis added to EqualLogic and Pure"
                
                $ESXiCli = Get-EsxCli -VMHost $_ -V2
                $IscsiVmks = Get-VMHostNetworkAdapter -VMHost $_ -PortGroup *iSCSI*

                $HostStorageSystem = Get-View (Get-VMHost $_).ExtensionData.configmanager.Storagesystem

                #bind vmks
                $IscsiVmks | % {
                
                    $Args = $ESXiCli.iscsi.networkportal.add.CreateArgs()
                    $Args.nic =  $_.Name
                    $Args.adapter = $IscsiHBA.Device
                    $ESXiCli.iscsi.networkportal.add.Invoke($Args)
                }

                $TargetIPs | % {
                    $IscsiHBA | New-IScsiHbaTarget -Address $_ -Port '3260'  -Type Send
                }
            }                   
        } catch {throw}
    }
}

function Add-ESXiIscsiDynamicTarget
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        $ESXiHost,
        
        [ValidateNotNullOrEmpty()]
        $TargetIPs = @('172.31.254.254','172.31.254.201')
    )
    Process
    {
        try
        {
            $ESXiHost | % {
                
                $IscsiHBA = Get-VMHostHba -Type iscsi -VMHost $_ | where model -match 'software'

                $TargetIPs | % {
                    $IscsiHBA | New-IScsiHbaTarget -Address $_ -Port '3260' -Type Send
                }
            }                   
        } catch {throw}
    }
}

function Set-ESXiHBATargetAdvancedSetting
{
    
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [Parameter(ParameterSetName='Targeted')]
        [Parameter(ParameterSetName='Non-targeted')]
        [ValidateNotNullOrEmpty()]
        [string] $ESXiHostname,
        
        [Parameter(Mandatory=$true)]
        [Parameter(ParameterSetName='Targeted')]
        [Parameter(ParameterSetName='Non-targeted')]
        [ValidateNotNullOrEmpty()]
        [string] $HBADevice,

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='Targeted')]
        $TargetIPs,
        
        [Parameter(Mandatory=$true)]
        [Parameter(ParameterSetName='Targeted')]
        [Parameter(ParameterSetName='Non-targeted')]
        [ValidateNotNullOrEmpty()]
        [string] $Setting,
        
        [ValidateNotNullOrEmpty()]
        [Parameter(
            ParameterSetName='Targeted',
            Mandatory=$true
        )]
        [boolean] $IsInherited = $true,
        
        [Parameter(Mandatory=$true)]
        [Parameter(ParameterSetName='Targeted')]
        [Parameter(ParameterSetName='Non-targeted')]
        [ValidateNotNullOrEmpty()]
        $Value 
    )
    Process {
        try
        {
            $ESXiHostname | % {

                $HostStorageSystem = Get-View (Get-VMHost $_).ExtensionData.configmanager.Storagesystem

                $HBA = Get-VMHost $_ | Get-VMHostHba -Device $HBADevice

                if ($TargetIPs){
                    
                    $Targets = @()
                    
                    foreach ($IP in $TargetIPs){
                        $Targets += $HBA.ExtensionData.ConfiguredSendTarget | ? address -eq $IP
                    }

                    $Targets | % {
                        if ($_.AdvancedOptions | ? key -eq $Setting) {
            
                            # targetset object
                            $TargetSet = New-Object VMware.Vim.HostInternetScsiHbaTargetSet 

                            # add target to target set
                            $TargetSet.SendTargets = $_

                            # advanced setting object
                            $TargetParam = New-Object VMware.Vim.HostInternetScsiHbaParamValue

                            $TargetParam.IsInherited = $IsInherited
                            $TargetParam.Key = $Setting
                            $TargetParam.Value = $Value

                            # update advanced setting
                            $HostStorageSystem.UpdateInternetScsiAdvancedOptions($HBA,$TargetSet,$TargetParam)
                        }
                    }

                    $Targets = @()

                    foreach ($IP in $TargetIPs){
                        $Targets += $HBA.ExtensionData.ConfiguredSendTarget | ? address -eq $IP
                    }
                    
                    $Targets | % {
                    
                        [pscustomobject]@{
                            IP = $_.Address
                            AdvancedOptions = $_.AdvancedOptions
                        }
                    }

                } else {
                    $AdvParam = New-Object VMware.Vim.HostInternetScsiHbaParamValue

                    $AdvParam.Key = $Setting
                    $AdvParam.Value = $Value

                    $HostStorageSystem.UpdateInternetScsiAdvancedOptions($HBA,$null,$AdvParam)

                    $HBA = Get-VMHost $_ | Get-VMHostHba -Device $HBADevice
                    
                    [pscustomobject]@{
                        vmhba = $HBA.Device
                        AdvancedOptions = $HBA.ExtensionData.AdvancedOptions
                    }
                }
            }
        }
        catch {throw}
    }
}

function Add-ESXiVDNetworking
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $vmk0PortGroup,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Datacenter
    )
    Process
    {
       try
        {
            $ESXiHost | % {
                
                $curHost = $_
                
                if((Get-VDPortgroup $vmk0PortGroup | Get-VDUplinkTeamingPolicy).LoadBalancingPolicy -ne 'LoadBalanceIp')
                {
                    $VDSwitches = Get-Datacenter $Datacenter | Get-VDSwitch | ? name -NotMatch 'LAG'
                }
                else
                {
                    $VDSwitches = Get-Datacenter $Datacenter | Get-VDSwitch |
                    ? name -ne (Get-Datacenter $Datacenter | Get-VDSwitch | ? name -match 0 | ? name -NotMatch 'LAG').Name
                    $LAG = $true
                }
                
                $VDSwitches | % {
                    
                    if($curHost -notin ($_ | Get-VMHost))
                    {
                        Add-VDSwitchVMHost -VDSwitch $_ -VMHost $curHost
                    }
                }

                $VDSwitch0 = $VDSwitches | ? Name -Like *0*
                                    
                $Dswitch0Nics = $curHost | Get-VirtualSwitch -Standard -Name *0 | Get-VMHostNetworkAdapter | ? Id -match 'PhysicalNic'
                
                $vmk0 = $curHost | Get-VMHostNetworkAdapter -Name vmk0

                if(($VDSwitch0 | Get-VMHostNetworkAdapter | ? uid -eq $vmk0.uid) -eq $null)
                {
                    $pg = $VDSwitch0 | Get-VDPortgroup $vmk0PortGroup
                
                    if($Dswitch0Nics.count -gt 0)
                    {
                        if($Dswitch0Nics.count -eq 1)
                        {   
                            Add-VDSwitchPhysicalNetworkAdapter `
                            -DistributedSwitch $VDSwitch0 `
                            -VMHostPhysicalNic $Dswitch0Nics `
                            -VMHostVirtualNic $vmk0 `
                            -VirtualNicPortgroup $vmk0PortGroup `
                            -Confirm:0
                        }
                        elseif($LAG){
                            Add-VDSwitchPhysicalNetworkAdapter `
                            -DistributedSwitch $VDSwitch0 `
                            -VMHostPhysicalNic $Dswitch0Nics `
                            -VMHostVirtualNic $vmk0 `
                            -VirtualNicPortgroup $vmk0PortGroup `
                            -Confirm:0
                        }else{
                            Add-VDSwitchPhysicalNetworkAdapter `
                            -DistributedSwitch $VDSwitch0 `
                            -VMHostPhysicalNic $Dswitch0Nics[0] `
                            -VMHostVirtualNic $vmk0 `
                            -VirtualNicPortgroup $vmk0PortGroup `
                            -Confirm:0

                            sleep 10
                        
                            Add-VDSwitchPhysicalNetworkAdapter `
                            -DistributedSwitch $VDSwitch0 `
                            -VMHostPhysicalNic $Dswitch0Nics[1..($Dswitch0Nics.Count-1)] `
                            -Confirm:0
                        }
                    }
                }
                
                # Add physical nics to VDSwitch1

                $iSCSISwitch = $VDSwitches | ? MTU -eq 9000

                if($Datacenter.Name -eq 'TF'){

                    # In TF, management and customer VLANs are on separate switches
                    # Add NICs to customer VDSwitch

                    $VDSwitch1 = Get-VDSwitch -Name TF*Switch1                    
                    $Dswitch1Nics = $curHost | Get-VMHostNetworkAdapter -Name vmnic1, vmnic5

                    if($Dswitch1Nics.count -gt 0){
                        Add-VDSwitchPhysicalNetworkAdapter `
                        -DistributedSwitch $VDSwitch1 `
                        -VMHostPhysicalNic $Dswitch1Nics `
                        -Confirm:0
                    }

                    $iSCSISwitchNics = $curHost | Get-VMHostNetworkAdapter -Physical | ? fullduplex -eq $true |
                    ? name -NotIn ($VDSwitch0 | Get-VMHostNetworkAdapter -Physical | ? VMhost -eq $curHost).Name |
                    ? name -NotIn ($VDSwitch1 | Get-VMHostNetworkAdapter -Physical | ? VMhost -eq $curHost).Name 
                }else{
                    $iSCSISwitchNics = $curHost | Get-VMHostNetworkAdapter -Physical | ? fullduplex -eq $true |
                    ? name -NotIn ($VDSwitch0 | Get-VMHostNetworkAdapter -Physical | ? VMhost -eq $curHost).Name
                }

                if($iSCSISwitchNics.count -gt 0){
                    Add-VDSwitchPhysicalNetworkAdapter `
                    -DistributedSwitch $iSCSISwitch `
                    -VMHostPhysicalNic $iSCSISwitchNics `
                    -Confirm:0
                }
            }
        } catch {throw}
    }
}

function Set-ScratchLocation
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,
  
        [ValidateNotNullOrEmpty()]
        $ScratchDatastore = 'RDG1'
    )
    Process
    {
        try {
            $ESXiHost | % {
                $ScratchDatastore = get-datastore $ScratchDatastore
                $Folder = "zHost$($_.ToString() -replace '[zhost.]')"
                $Path = $ScratchDatastore.DatastoreBrowserPath

                New-Item -Name $Folder -ItemType Directory -Path "$Path\zHostLogs\"
                New-Item -Name 'Scratch' -ItemType Directory -Path "$Path\zHostLogs\$Folder\"
        
                $_ | Get-AdvancedSetting *scratch*ure* | Set-AdvancedSetting -value "/vmfs/volumes/$($ScratchDatastore.ExtensionData.info.vmfs.uuid)/zHostLogs/$Folder/Scratch" -Confirm:$false
                #$_ | Get-AdvancedSetting 'Syslog.global.logDir' | Set-AdvancedSetting -value “[$($ScratchDatastore.Name)] zHostLogs/$Folder” -Confirm:$false
                $_ | Restart-VMHost -Confirm:$false
            
                Read-Host -Prompt "Enter to continue when $($_.Name) DCUI available"

                if (($_| Get-AdvancedSetting *scratch*cur*).Value -eq "/vmfs/volumes/$($ScratchDatastore.ExtensionData.info.vmfs.uuid)/zHostLogs/$Folder/Scratch"){
                    Write-Host "$($_.Name) scratch location set successfully"
                } else {Write-Warning "$($_.Name) location not set"}
            }
        }catch {throw}
    }      
}

function Export-ESXiBackupConfig
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,
  
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Path = 'C:\Users\Lewisc\Desktop\EsxiBackups\'
    )
    Process
    {
        try {
            $ESXiHost | % {
            
                New-Item -ItemType Directory -Path $Path -Name "$($ESXiHost.name)"
                Get-VMHostFirmware -VMHost $_ -BackupConfiguration -DestinationPath "$Path\$($ESXiHost.name)"
            }
        }catch{throw}
    }      
}

function Install-ESXiMemPlugin
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost
    )

    Begin
    {
        $MemPlugin = Get-Baseline -name "mem 1.4*"
    }
    Process
    {
        try{
            $ESXiHost | % {
            
                $_ | Get-AdvancedSetting 'net.tcpipdeflroenabled' | Set-AdvancedSetting -Value 0 -Confirm:$false
            
                Attach-Baseline -Entity $_ -Baseline $MemPlugin
                Stage-Patch -Entity $_ -Baseline $MemPlugin
                Update-Entity -Entity $_ -Baseline $MemPlugin -Confirm:$false -RunAsync
            
                Read-Host -Prompt "Enter to continue when $($_.Name) DCUI available"
            
                $ESXiCli = Get-EsxCli -V2 -VMHost $_

                sleep 60

                if($ESXiCli.software.vib.list.Invoke()|? {$_.Id -match '1.4.0-426823'}) {
                    $ESXiCli.software.vib.list.Invoke()|? {$_.Id -match '1.4.0-426823'}
                } else {Write-Warning "Unable to verify MEM plugin installed for $($_.Name)"}
            }
        }catch{throw}
    }      
}

function Update-ESXiVUMBaseline
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ESXiHostname,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Baseline,

        [ValidateNotNullOrEmpty()]
        [bool] $Reboot
    )
    
    Process
    {   
    try {
            Get-VMHost $ESXiHostname | % {
                
                Attach-Baseline -Entity $_ -Baseline $Baseline
                Scan-Inventory -Entity $_ -UpdateType HostPatch
                Stage-Patch -Entity $_ -Baseline $Baseline
                If($Reboot)
                {
                    Update-Entity -Entity $_ -Baseline $Baseline -Confirm:$false -RunAsync
                }
                else
                {
                    "`"$($Basline.name)`" patches staged and ready to install on $($_.name)" |
                    Write-Host -ForegroundColor Black
                }
            }
        } catch {throw}
    }      
}

function Enable-ESXiNetworkCoreDump
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,
  
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $VcenterIP
    )
    Process
    {
        try{
            $ESXiHost | % {

                $ESXiCli = Get-EsxCli -VMHost $_ -V2
                $Args = $ESXiCli.system.coredump.network.set.CreateArgs()
                $Args.interfacename = 'vmk0'
                $Args.serveripv4 =  $VcenterIP
                $Args.serverport = '6500'
                $Args = $ESXiCli.system.coredump.network.set.Invoke($Args)
                $Args = $ESXiCli.system.coredump.network.set.CreateArgs()
                $Args.enable = 'true'
                $Args = $ESXiCli.system.coredump.network.set.Invoke($Args)
            }
        }catch{throw}
    }      
}

function Confirm-VIServerConnection
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ViServer,
  
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Credential = $lcred
    )
    Process
    {
        try {
            if ($global:DefaultVIServer){

                if ($global:DefaultVIServer.name -ne $ViServer) {
                    Disconnect-VIServer -Confirm $false | Out-Null
                    Connect-VIServer -Server $ViServer -Credential $Credential -WarningAction SilentlyContinue | Out-Null
                }
            } else {Connect-VIServer -Server $ViServer -Credential $Credential -WarningAction SilentlyContinue | Out-Null}
        }catch{throw}
    }      
}

