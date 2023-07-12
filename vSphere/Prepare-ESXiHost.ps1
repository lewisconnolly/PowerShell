Import-Module 'C:\Users\Lewisc\OneDrive\Documents\WindowsPowerShell\Scripts\xa modules\XavPowerCLI.psm1' -Force
#Import-Module 'PATHtoESXIconfigModule' -Force
<#
Set-NewHostParameters
Set-iDRAC
Add-HostDNSRecords
Set-VMHostMgmtInfo
#>

Function Prepare-ESXiHost {

<#

.DESCRIPTION
Before running these conditions must be met:
    - The right IP / Netmask / Gateway
    - iDRAC network settings configured

Post-run:
    - iDRAC Alerts
    - iDRAC tsuser

.EXAMPLE
> Prepare-ESXiHost -VMHost zhost99.zhost -Set_SSH -Set_NTP -Set-vSwitchAndPG -VMHostIP "172.31.1.198" -VMotionIP "172.50.1.99" -iscsi1ip "172.31.254.99" -iscsi2ip "172.31.254.100" -idracip "172.50.1.199"
#>

[CmdletBinding()]

Param(
   [ValidateNotNullOrEmpty()]
   [Parameter(Mandatory=$true)]
   [string]$VMHost,

   [switch]$Set_SSH = $true,

   [switch]$Set_NTP = $true,

   [ValidateNotNullOrEmpty()]
   [string]$NTPAddress = "uk.pool.ntp.org",

   [Switch]$Set_vSwitchAndPG = $true,

   [ValidateNotNullOrEmpty()]
   [System.Array]$CustVlanRange = (11..79),

   [ValidateNotNullOrEmpty()]
   [string[]]$DNS = ("172.31.6.136","172.31.6.137"),

   [ValidateNotNullOrEmpty()]
   [string]$DefaultGateway = "172.31.1.219",
   
   [ValidateNotNullOrEmpty()]
   [string]$VMHostIP,
   
   [ValidateNotNullOrEmpty()]
   [string]$VMotionIP,

   [ValidateNotNullOrEmpty()]
   [string]$iscsi1ip,

   [ValidateNotNullOrEmpty()]
   [string]$iscsi2ip,

   [ValidateNotNullOrEmpty()]
   [string]$idracip

)
<#
   $VMHost = "zhost18.zhost"

   $Set_SSH = $true

   $Set_NTP = $true

   
   $NTPAddress = "uk.pool.ntp.org"

   $Set_vSwitchAndPG = $true

   
   $CustVlanRange = (11..79)

   
   $DNS = ("172.31.6.136","172.31.6.137")

   
   $DefaultGateway = "172.31.1.219"
   
   
   $VMHostIP = "172.31.1.88"
   
   
   $VMotionIP = "172.50.1.18"

   
   $iscsi1ip = "172.31.254.128"

   
   $iscsi2ip = "172.31.254.129"

   
   $idracip = "172.31.1.89"
#>

####################################
$Skip = Read-Host -Prompt 'Once iDRAC accessible, any key and enter to continue or "skip" to move to next step'
####################################
    
$svctag = (((C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng getsvctag) -split "\n") | where {$_ -ne ""})[-1].ToLower()

$idracName = "$(($VMHost).TrimEnd(".zhost"))-idrac-$svctag"

$idracMAC = ((C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng get iDRAC.nic.MACAddress) -split "\n" | where {$_ -like "MACAddress=*"}).TrimStart("MACAddress=")

if ($Skip -ne 'skip') {
    
    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng set iDRAC.nic.DNSRacName $idracName
    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng set iDRAC.nic.DNSDomainName zhost

    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng set IDRAC.EmailAlert.1.Address zts@zonal.co.uk
    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng set IDRAC.EmailAlert.1.Enable Enabled
    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng set idrac.remotehosts.SMTPServerIPAddress 172.31.1.122
    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng set idrac.remotehosts.SMTPPort 25
    C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng set idrac.ipmilan.enable enabled
}

####################################
$Skip = Read-Host -Prompt 'Add tsuser and enable email alerts on idrac then any key and enter to add DNS records for host and idrac or "skip" to move to next step' 
####################################

$HostName = $VMHost.TrimEnd(".zhost")

if ($Skip -ne 'skip') {
    $dcsesh = New-PSSession -ComputerName "dca-utl-dc1" -Credential $lcred
    Invoke-Command -Session $dcsesh -ArgumentList $HostName,$VMHostIP,$idracName,$idracip -ScriptBlock {
        Add-DnsServerResourceRecordA -CreatePtr -Name $args[0] -IPv4Address $args[1] -ZoneName zhost
        Add-DnsServerResourceRecordA -CreatePtr -Name $args[2] -IPv4Address $args[3] -ZoneName zhost
    }
}

####################################
# Check Parameters
#################################### 

    IF ($VMHostIP) { while (-not(($VMHostIP -as [ipaddress]) -as [bool])) {$VMHostIP = Read-Host "Host IP Invalid, re-enter"}}
    IF ($VMotionIP) { while (-not(($VMotionIP -as [ipaddress]) -as [bool])) {$VMotionIP = Read-Host "VMotion IP Invalid, re-enter"}}
    IF ($iscsi1ip) { while (-not(($iscsi1ip -as [ipaddress]) -as [bool])) {$iscsi1ip = Read-Host "ISCSI 1 IP Invalid, re-enter"}}
    IF ($iscsi2ip) { while (-not(($iscsi2ip -as [ipaddress]) -as [bool])) {$iscsi2ip = Read-Host "ISCSI 2 IP Invalid, re-enter"}}
    IF ($idracip) { while (-not(($idracip -as [ipaddress]) -as [bool])) {$idracip = Read-Host "iDRAC IP Invalid, re-enter"}}

    $script:ErrorActionPreference = "Stop"

####################################
$Skip = Read-Host -Prompt 'Set root password, hostname, domain name, dns and add host to vcenter or "skip"' 
####################################
if ($Skip -ne 'skip') {
    Connect-VIServer $VMHostIP -User root -Password ($svctag.ToUpper())
    Get-VMHostNetwork | Set-VMHostNetwork -HostName $VMHost -DomainName "zhost" #Change to Get-VMHostNetworkAdapter
    Get-VMHostNetwork | Set-VMHostNetwork -SearchDomain zhost
    get-VMHostAccount -User root | Set-VMHostAccount -Password "zH0st1ng"
    Disconnect-VIServer -Confirm:$false
    
    Connect-VIServer dca-vcenter -Credential $lcred

    $DCAcluster = Get-Cluster
    Add-VMHost -Name $VMHost -User root -Password "zH0st1ng" -Location $DCAcluster -Force
Read-Host -Prompt 'Enter to continue after host registered in cluster' 
    $ESXiHost = Get-VMHost $VMHost
    $ESXiHost | Get-VMHostNetwork | Set-VMHostNetwork -DnsAddress $DNS
}

$DCAcluster = Get-Cluster
$ESXiHost = Get-VMHost $VMHost

####################################
$DoubleCheck = Read-Host "$($VMHost.name) enter Maintenance mode : Continue ? (y/n) [n]"
####################################
    
    IF ($DoubleCheck -ne "n") {    
        $ESXiHost | Set-VMHost -State 'Maintenance'
    }

####################################
Read-Host -Prompt 'Set NTP' 
####################################

    IF ($Set_NTP) {
    
    Write-Host "Configuring NTP" -ForegroundColor Green

    TRY {
        $ESXiHost | Add-VMHostNtpServer -NtpServer $NTPAddress -Confirm:$false 

        $NTPDService = $ESXiHost | Get-VMHostService | where {$_.Key -eq 'ntpd'} 

        Set-VMHostService -HostService $NTPDService -policy "on" 3>&1 | Out-Null

        Start-VMHostService -HostService $NTPDService -Confirm:$false 3>&1 | Out-Null

        #$ESXiHost | Get-VMHostService | where {$_.Key -eq 'ntpd'} | Restart-VMHostService -Confirm:$False
    }

    Catch {
        Write-Error "NTP configuration error : $($_.Exception.Message)"
    }

    } ELSE {Write-Warning "NTP configuration skipped"}
    
####################################
Read-Host -Prompt "Set SSH" 
####################################

    IF ($Set_SSH) {
    
    Write-Host "Configuring SSH" -ForegroundColor Green

    TRY {
        $SSHService = $ESXiHost | Get-VMHostService | where {$_.Key -eq 'TSM-SSH'}

        Set-VMHostService -HostService $SSHService -policy "on" 3>&1 | Out-Null
    
        Start-VMHostService -HostService $SSHService -Confirm:$false  3>&1 | Out-Null

        Get-AdvancedSetting -Entity $ESXiHost | Where {$_.Name -eq "UserVars.SuppressShellWarning"} | Set-AdvancedSetting -Value "1" -Confirm:$false 3>&1 | Out-Null
        
        Set-VMHostSSHAuthorizedIP -VMHost $ESXiHost -IPs '10.40.110.71','10.40.110.73','10.40.110.94','10.40.110.35','10.40.110.78' -Authorized "true"

        Set-VMHostSSHTimeout -VMHost $ESXiHost -Timeout 300


    }
    Catch {
        Write-Error "SSH configuration error : $($_.Exception.Message)"
    }

    } ELSE {Write-Warning "SSH configuration skipped"}

    
####################################
Read-Host -Prompt "Continue to configure vSwitches" 
####################################

    IF ($Set_vSwitchAndPG) {
    
    Write-Host "Creating virtual switches" -ForegroundColor Green

    TRY {
        $Vswitch0 = $ESXiHost | Get-VirtualSwitch -name vswitch0
        
        $Vswitch0 | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic (Get-VMHostNetworkAdapter -VMHost $ESXiHost -Name vmnic0,vmnic1) -Confirm:$False
        $Vswitch0 | Set-VirtualSwitch -Mtu 1500 -Confirm:$False

        $Vswitch1 = $ESXiHost | New-VirtualSwitch -name vSwitch1 
        $Vswitch1 | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic (Get-VMHostNetworkAdapter -VMHost $ESXiHost -Name vmnic2,vmnic3) -Confirm:$False
        $Vswitch1 | Set-VirtualSwitch -mtu 9000 -Confirm:$False
    }
    Catch {
        Write-Error "vSwitch creation error : $($_.Exception.Message)"
    }

####################################
$Skip = Read-Host -Prompt "Set portgroups or skip" 
####################################
if ($Skip -ne 'skip') {
    Write-Host "Creating port groups" -ForegroundColor Green

    TRY {
        $CustVlanRange | ForEach-Object {New-VirtualPortGroup -Name "VM Customer $_" -VirtualSwitch $Vswitch0 -VLanId $_ -Confirm:$False} 3>&1 | Out-Null

        New-VirtualPortGroup -Name "VMkernel vMotion" -VirtualSwitch $Vswitch1 -VLanId 0 -confirm:$False 3>&1 | Out-Null

        New-VirtualPortGroup -Name "iSCSI1" -VirtualSwitch $Vswitch1 -VLanId 0 -confirm:$False 3>&1 | Out-Null

        New-VirtualPortGroup -Name "iSCSI2" -VirtualSwitch $Vswitch1 -VLanId 0 -confirm:$False 3>&1 | Out-Null
    }
    Catch {
        Write-Error "PortGroup creation error : $($_.Exception.Message)"
    }

    TRY {
        
        Get-VirtualPortGroup -VMHost $ESXiHost -Name "Management Network" | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive (Get-VMHostNetworkAdapter -VMHost $ESXiHost -Name vmnic0,vmnic1) -Confirm:$False 3>&1 | Out-Null
        
        Get-VirtualPortGroup -VMHost $ESXiHost -Name iSCSI1 | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive (Get-VMHostNetworkAdapter -VMHost $ESXiHost -Name vmnic2) -MakeNicUnused (Get-VMHostNetworkAdapter -VMHost $ESXiHost -Name vmnic3) -Confirm:$False 3>&1 | Out-Null

        Get-VirtualPortGroup -VMHost $ESXiHost -Name iSCSI2 | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive (Get-VMHostNetworkAdapter -VMHost $ESXiHost -Name vmnic3) -MakeNicUnused (Get-VMHostNetworkAdapter -VMHost $ESXiHost -Name vmnic2) -Confirm:$False 3>&1 | Out-Null
    }
    Catch {
        Write-Error "Nic teaming policy  error : $($_.Exception.Message)"
    }

    } ELSE {Write-Warning "vSwitchs and port groups configuration skipped"}
}
####################################
$Skip = Read-Host -Prompt "Set vmk adapters or skip" 
####################################
if ($Skip -ne 'skip') {    
    TRY {
        IF ($VMotionIP) {
            Write-Host "Creating VMotion VMKernel" -ForegroundColor Green
            New-VMHostNetworkAdapter -vmhost $ESXiHost -portgroup "VMkernel vMotion" -virtualSwitch (Get-VirtualSwitch -VMHost $ESXiHost -Name vSwitch1) -IP $VMotionIP -SubNetMask "255.255.255.0" -MTU 9000 -vMotionEnabled:$True 3>&1 | Out-Null
        } ELSE {Write-Warning "VMotion interface not configured"}

        IF ($iscsi1ip) {
            Write-Host "Creating ISCSI1 VMKernel" -ForegroundColor Green
            $iVMK1 = New-VMHostNetworkAdapter -vmhost $ESXiHost -portgroup "iSCSI1" -virtualSwitch (Get-VirtualSwitch -VMHost $ESXiHost -Name vSwitch1) -IP $iscsi1ip -SubNetMask "255.255.255.0" -MTU 9000 3>&1 | Out-Null
        } ELSE {Write-Warning "ISCSI1 interface not configured"}

        IF ($iscsi2ip) {
            Write-Host "Creating ISCSI2 VMKernel" -ForegroundColor Green
            $iVMK2 = New-VMHostNetworkAdapter -vmhost $ESXiHost -portgroup "iSCSI2" -virtualSwitch (Get-VirtualSwitch -VMHost $ESXiHost -Name vSwitch1) -IP $iscsi2ip -SubNetMask "255.255.255.0" -MTU 9000 3>&1 | Out-Null
        } ELSE {Write-Warning "ISCSI2 interface not configured"}
    }
    Catch {
        Write-Error "VMkernel adapter error : $($_.Exception.Message)"
    }
}
####################################
$Skip = Read-Host -Prompt "Configure storage or skip" 
####################################
if ($Skip -ne 'skip') {    
    Write-Host "Configuring iSCSI storage" -ForegroundColor Green

    TRY{
        if ((Get-VMHostStorage -VMHost $ESXiHost).SoftwareIScsiEnabled -eq $false){
            Get-VMHostStorage -VMHost $ESXiHost | Set-VMHostStorage -SoftwareIScsiEnabled $true
        }

Read-Host -Prompt "Enter to continue when ISCSI adapter enabled and added to EQL" 

        $esxcli = Get-EsxCli -VMHost $ESXiHost -V2
        $IscsiHBA = Get-VMHostHba -Type iscsi -VMHost $ESXiHost | where model -match "software"
        $iVMK1 = Get-VMHostNetworkAdapter -vmhost $ESXiHost -virtualSwitch (Get-VirtualSwitch -VMHost $ESXiHost -Name vSwitch1) -VMKernel vmk2
        $iVMK2 = Get-VMHostNetworkAdapter -vmhost $ESXiHost -virtualSwitch (Get-VirtualSwitch -VMHost $ESXiHost -Name vSwitch1) -VMKernel vmk3
        
        $cArgs = $esxCLI.iscsi.networkportal.add.CreateArgs()
        $cArgs.nic =  $iVMK1.Name
        $cArgs.adapter = $IscsiHBA.Device
        $esxCLI.iscsi.networkportal.add.Invoke($cArgs)
        
        $cArgs = $esxCLI.iscsi.networkportal.add.CreateArgs()
        $cArgs.nic =  $iVMK2.Name
        $cArgs.adapter = $IscsiHBA.Device
        $esxCLI.iscsi.networkportal.add.Invoke($cArgs)

        $cArgs = $esxCLI.iscsi.adapter.param.set.CreateArgs()
        $cArgs.adapter = "vmhba64" 
        $cArgs.key =  "DelayedAck"
        $cArgs.value =  "false"
        $esxCLI.iscsi.adapter.param.set.CreateArgs($cArgs)

        $cArgs = $esxCLI.iscsi.adapter.param.set.CreateArgs()
        $cArgs.adapter = "vmhba64" 
        $cArgs.key =  "LoginTimeout"
        $cArgs.value =  "60"
        $esxCLI.iscsi.adapter.param.set.CreateArgs($cArgs)

        $cArgs = $esxCLI.iscsi.adapter.param.set.CreateArgs()
        $cArgs.adapter = "vmhba64" 
        $cArgs.key =  "NoopOutTimeout"
        $cArgs.value =  "30"
        $esxCLI.iscsi.adapter.param.set.CreateArgs($cArgs)

        $iscsihba | New-IScsiHbaTarget -Address "172.31.254.254" -Port "3260"  -Type Send
        $iscsihba | New-IScsiHbaTarget -Address "172.31.254.201" -Port "3260"  -Type Send

        $cArgs = $esxCLI.iscsi.adapter.discovery.sendtarget.param.set.CreateArgs()
        $cArgs.adapter = "vmhba64" 
        $cArgs.address =  "172.31.254.201"
        $cArgs.inherit =  "false"
        $cArgs.key =  "LoginTimeout"
        $cArgs.value =  "30"
        $esxCLI.iscsi.adapter.discovery.sendtarget.param.set.Invoke($cArgs)

        $cArgs = $esxCLI.storage.nmp.satp.rule.add.CreateArgs()
        $cArgs.satp = "VMW_SATP_ALUA" 
        $cArgs.vendor =  "PURE"
        $cArgs.model =  "FlashArray"
        $cArgs.psp =  "VMW_PSP_RR"
        $cArgs.pspoption =  "iops=1"
        $cArgs.description = "Pure Storage FlashArray - RR every 1 IO"
        $cArgs = $esxCLI.storage.nmp.satp.rule.add.Invoke($cArgs)    
        
        $ESXiHost | Get-VMHostStorage -RescanAllHba -RescanVmfs

    }

    Catch {
        Write-Error "Storage/Network configuration error : $($_.Exception.Message)"
    }
}
####################################
$Skip = Read-Host -Prompt "Set scratch and log location or skip" 
####################################
if ($Skip -ne 'skip') {    
    $zhostfolder = "zHost$($ESXiHost.ToString() -replace '[zhost.]')"
    New-Item -Name $zhostfolder -ItemType Directory -Path "vmstores:\dca-vcenter@443\DCA\RDG1\zHostLogs\"
    New-Item -Name "Scratch" -ItemType Directory -Path "vmstores:\dca-vcenter@443\DCA\RDG1\zHostLogs\$zhostfolder\"
    $ESXiHost | Get-AdvancedSetting *scratch*ure* | Set-AdvancedSetting -value "/vmfs/volumes/51fb9543-0aac360f-a642-a41f72d33041/zHostLogs/$zhostfolder/Scratch" -Confirm:$false
    $ESXiHost | Get-AdvancedSetting "Syslog.global.logDir" | Set-AdvancedSetting -value “[RDG1] zHostLogs/$zhostfolder” -Confirm:$false
    $ESXiHost | Restart-VMHost -Confirm:$false
Read-Host -Prompt "Enter to continue when host DCUI available"
    if (($ESXiHost | Get-AdvancedSetting *scratch*cur*).Value -eq "/vmfs/volumes/51fb9543-0aac360f-a642-a41f72d33041/zHostLogs/$zhostfolder/Scratch"){
        Write-Host "Scratch location configured successfully"
    } else {Write-Host "Scratch location not set"}

    Get-VMHostFirmware -VMHost $ESXiHost -BackupConfiguration -DestinationPath C:\Users\Lewisc\Desktop\EsxiBackups\
}
####################################
$Skip = Read-Host -Prompt "Install critical and non-critical ESX patches or skip" 
####################################
if ($Skip -ne 'skip') {    
    $critpatch = Get-Baseline -name "zts*crit*6.5*"
    Attach-Baseline -Entity $ESXiHost -Baseline $critpatch[0]
    Update-Entity -Entity $ESXiHost -Baseline $critpatch[0] -Confirm:$false -RunAsync
Read-Host -Prompt "Enter to continue when host DCUI available" 
    Attach-Baseline -Entity $ESXiHost -Baseline $critpatch[1]
    Update-Entity -Entity $ESXiHost -Baseline $critpatch[1] -Confirm:$false -RunAsync
}
####################################
$Skip = Read-Host -Prompt "Install MEM plugin or skip" 
####################################
if ($Skip -ne 'skip') {        
    $memVUMbaseline = Get-Baseline -name "mem 1.4*"    
    Attach-Baseline -Entity $ESXiHost -Baseline $memVUMbaseline
    Update-Entity -Entity $ESXiHost -Baseline $memVUMbaseline -Confirm:$false -RunAsync
Read-Host -Prompt "Enter to continue when host DCUI available" 
    $cred = New-Cred -User root -Password "zH0st1ng"
    $SeSSHion = New-SSHSession -ComputerName $VMHostIP -Credential $cred -AcceptKey
    $command = Invoke-SSHCommand -SSHSession $SeSSHion -Command "esxcli software vib list | grep 1.4.0-426823"
    if ($command.Output -ne ""){Write-Host "$($command.Output) `n MEM plugin installed successfully"} else {Write-Host "Unable to verify MEM plugin installed"}

    $ESXiHost | Get-AdvancedSetting "net.tcpipdeflroenabled" | Set-AdvancedSetting -Value 0
}
####################################
$Skip = Read-Host -Prompt "Enable network core dump or skip" 
####################################
if ($Skip -ne 'skip') {
    $esxcli = Get-EsxCli -VMHost $ESXiHost -V2        
    $cArgs = $esxCLI.system.coredump.network.set.CreateArgs()
    $cArgs.interfacename = "vmk0"
    $cArgs.serveripv4 =  "172.31.1.5"
    $cArgs.serverport = "6500"
    $cArgs = $esxCLI.system.coredump.network.set.Invoke($cArgs)
    $cArgs = $esxCLI.system.coredump.network.set.CreateArgs()
    $cArgs.enable = "true"
    $cArgs = $esxCLI.system.coredump.network.set.Invoke($cArgs)
}
####################################
$Skip = Read-Host -Prompt "Configure IPMI and Power Management or skip" 
####################################
if ($Skip -ne 'skip') {
    $ESXiHost = Get-VMHost $VMHost    
    $idracMAC = ((C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $idracip -u root -p zh0st1ng get iDRAC.nic.MACAddress) -split "\n" | where {$_ -like "MACAddress=*"}).TrimStart("MACAddress=")
    $HostView = get-view $ESXiHost.Id
    $ipmiinfo = new-object vmware.vim.hostipmiinfo
    $ipmiinfo.bmcipaddress = $idracip
    $ipmiinfo.bmcmacaddress = $idracMAC
    $ipmiinfo.login = "root"
    $ipmiinfo.password="zh0st1ng"
    $HostView.updateipmi($ipmiinfo)
    $HostPowerSysView = get-view $ESXiHost.ExtensionData.ConfigManager.PowerSystem
    $HostPowerSysView.ConfigurePowerPolicy(1)
    
    $HostView.ReconfigureHostForDAS()
}    

####################################
$Skip = Read-Host -Prompt "Exit maintenance mode or skip" 
####################################
if ($Skip -ne 'skip') {    
    Set-VMHost -VMHost $ESXiHost -State Connected
    Disconnect-VIServer
    Write-Host "Configuration completed" -ForegroundColor Green
}
}