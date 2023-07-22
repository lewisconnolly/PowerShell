function Start-ESXiBuildProcess
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [ValidateSet("6.7","7")]
        $ESXiVersion = '7',

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ESXiHostname,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Password,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiIP,

        [ValidateNotNullOrEmpty()]
        $ESXiNetmask = '255.255.255.0',

        [ValidateNotNullOrEmpty()]
        $ESXiGateway = '172.31.1.219',

        [ValidateNotNullOrEmpty()]
        $ESXiVLANID,

        [ValidateNotNullOrEmpty()]
        $ESXiDNS = '172.31.6.136',

        [ValidateNotNullOrEmpty()]
        $ESXiMgmtNic = 'vmnic0',

        [ValidateNotNullOrEmpty()]
        $DNS = @('172.31.6.136','172.31.6.137'),

        [ValidateNotNullOrEmpty()]
        $vmk0PortGroup,

        [ValidateNotNullOrEmpty()]
        $ESXiIPiSCSI,

        [ValidateNotNullOrEmpty()]
        $ESXiIPiSCSINetMask,
        
        [ValidateNotNullOrEmpty()]
        $ESXiHBATargets = @('172.31.254.205','172.31.254.213'),
        
        [ValidateNotNullOrEmpty()]
        $FlashArrays = @('dca-flasharray1','dca-flasharray2','dca-flasharray3'),

        [ValidateNotNullOrEmpty()]
        $FlashArrayHostGroup = 'DCA-VMHosts',
        
        [ValidateNotNullOrEmpty()]
        $ESXiIPvMotion1,
        
        [ValidateNotNullOrEmpty()]
        $ESXiIPvMotion2,

        [ValidateNotNullOrEmpty()]
        $ESXiIPvMotion2NetMask,

        [ValidateNotNullOrEmpty()]
        $ESXivMotionGateway = '172.31.9.1',
        
        [ValidateNotNullOrEmpty()]
        $SysLogDatastore = 'DCA-SSD-PURE101',

        [ValidateNotNullOrEmpty()]
        $SysLogServer = '172.31.11.111',
        
        [ValidateNotNullOrEmpty()]
        $ISOPath =
        "\\dca-utl-nas.domain.local\f$\infra-backups\ESXi_ks\DCA\VMware-VMvisor-Installer-6.7.0.update02-13006603.x86_64.iso",

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACIP,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACUser,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACPassword,

        [ValidateNotNullOrEmpty()]
        $FirstBootDevice,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $DomainCredential,

        [ValidateNotNullOrEmpty()]
        $DomainController = 'dca-utl-dc1',

        [ValidateNotNullOrEmpty()]
        $vCenter = 'vcenter',

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Datacenter,

        [ValidateNotNullOrEmpty()]
        $Cluster = 'DCA-Cluster',
        
        [ValidateNotNullOrEmpty()]
        $Baseline,

        [ValidateNotNullOrEmpty()]
        $SMTP = 'mail.domain.local',

        [ValidateNotNullOrEmpty()]
        $AlertDestination = 'lewis.connolly@zonal.co.uk',
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $JoinDomainCredential
    )
    Process
    {

    ### Create custom ESXi ISO and do a fresh install on host
    
        "`nCreating custom ISO for $ESXiHostname clean install`n" | Write-Host -ForegroundColor Green

        $NewKickstart = @{

            ESXiVersion = $ESXiVersion
            ESXiHostname = $ESXiHostname
            Password = $Password 
            Datacenter = $Datacenter 
            ESXiIP = $ESXiIP 
            ESXiNetmask = $ESXiNetmask 
            ESXiGateway = $ESXiGateway 
            ESXiDNS = $ESXiDNS 
            ESXiMgmtNic = $ESXiMgmtNic
            iDRACIP = $iDRACIP 
            iDRACUser = $iDRACUser
            iDRACPassword = $iDRACPassword
            ISOPath = $ISOPath 
            DomainCredential = $DomainCredential 
        }

        if($ESXiVLANID){ $NewKickstart.Add('ESXiVLANID',$ESXiVLANID) }

        if($FirstBootDevice){ $NewKickstart.Add('FirstBootDevice',$FirstBootDevice) }

        New-ESXiKickstartISOInstall @NewKickstart
    
        while((Test-NetConnection $ESXiHostname).PingSucceeded -eq $false){

            "`nWaiting on installation to finish`n" | Write-Host -ForegroundColor Green
            sleep 15
        }
        
        "`n$ESXiHostname is pingable. Continue?`n" | Write-Host -ForegroundColor Green
        
        Send-MailMessage -From ("$ENV:USERNAME@$ENV:COMPUTERNAME.$ENV:USERDNSDOMAIN").tolower() -Subject "$ESXiHostname has finished installing"`
        -SmtpServer $SMTP -To $AlertDestination
        
        $ans = Read-Host -Prompt '[y/n]'

        if($ans -ne 'y')
        {
            "`nQuitting...`n" | Write-Host -ForegroundColor Green
            break
        }
    
    ### Add host
        
        $ESXiHost = Get-VMHost -Name $ESXiHostname -ErrorAction Ignore

        if($ESXiHost -eq $null)
        {
            "`nAdding $ESXiHostname to $vCenter`n" | Write-Host -ForegroundColor Green

            Add-VMHost -Name $ESXiHostname -User 'root' -Password $Password -Location $Cluster -Force
        }
        
    ### Disable alarm actions

        "`nSetting $ESXiHostname alarm actions disabled`n" | Write-Host -ForegroundColor Green

        Set-VIAlarmActions -Entity (Get-VMHost $ESXiHostname) -Enabled $false

    ### Put host into maintenance mode
    
        $ESXiHost = Get-VMHost -Name $ESXiHostname -ErrorAction Ignore
    
        if($ESXiHost.ConnectionState -ne 'Maintenance')
        {
            "`nPutting $ESXiHostname into maintenance mode`n" | Write-Host -ForegroundColor Green

            Get-VMHost $ESXiHostname | Set-VMHost -State Maintenance -Confirm:0
        }
        
    ### Add second DNS server

        "`nSetting $ESXiHostname DNS to $($DNS -join ', ')`n" | Write-Host -ForegroundColor Green

        Get-VMHost $ESXiHostname | Get-VMHostNetwork | Set-VMHostNetwork -DnsAddress $DNS

    ### Enable SNMP

        "`nEnabling $ESXiHostname SNMP`n" | Write-Host -ForegroundColor Green

        Set-ESXiSNMP -ESXiHost (Get-VMHost $ESXiHostname)

    ### Set VMNICs to auto-neg

        "`nSetting $ESXiHostname VMNICs to auto-negotiate`n" | Write-Host -ForegroundColor Green

        Get-VMHost $ESXiHostname | Get-VMHostNetworkAdapter -Physical |
        Set-VMHostNetworkAdapter -AutoNegotiate -Confirm:0

    ### Add virtual networking

        "`nAdding $ESXiHostname to $($Datacenter.Name) distributed networking`n" |
        Write-Host -ForegroundColor Green

        if($vmk0PortGroup -eq $null){ $vmk0PortGroup = 'DCA-DSw0-DPG-VMHostManagement' }

        Add-ESXiVDNetworking `
        -ESXiHost (Get-VMHost $ESXiHostname) `
        -Datacenter $Datacenter `
        -vmk0PortGroup $vmk0PortGroup
        
        read-host -Prompt "`nConfirm all vmnics have been added to virtual switches and $ESXiHostname is still accessible over the network. [enter] to continue`n"    
        
        $vSwitch0Standard = Get-VMHost $ESXiHostname | Get-VirtualSwitch -Name 'vSwitch0' -ErrorAction Ignore

        if($vSwitch0Standard -ne $null){ $vSwitch0Standard | Remove-VirtualSwitch -Confirm:0 }
        
    ### Add VMKs

        "`nAdding $ESXiHostname vmks`n" | Write-Host -ForegroundColor Green

        # Add iSCSI VMKs
    
        $pgs = Get-VDPortgroup |? Name -Match "$($Datacenter.name).*iSCSI[0-9]{1}"
        
        $VDSwitch1 = Get-VMHost -Name $ESXiHostname  | Get-VDSwitch |? Name -Like "*1"

        if($Datacenter.Name -eq 'TF'){
            $iSCSISwitch = Get-VMHost -Name $ESXiHostname  | Get-VDSwitch |? Name -Like "*2"
        }else{
            $iSCSISwitch = $VDSwitch1
        }

        $i = 0
        $ESXiIPiSCSI | % {

            $vmk = Get-VMHost -Name $ESXiHostname | Get-VMHostNetworkAdapter | ? IP -eq $_ 

            if($vmk -eq $null)
            {
                New-VMHostNetworkAdapter `
                -VMHost (Get-VMHost $ESXiHostname) `
                -PortGroup $pgs[$i] `
                -VirtualSwitch $iSCSISwitch `
                -IP $_ `
                -SubnetMask $ESXiIPiSCSINetMask `
                -Mtu 9000 `
                -Confirm:0
            }
            
            $i++
        }        

        $pgs = $ESXiHost | Get-VDSwitch |
        Get-VDPortgroup |? Name -Match "$($Datacenter.name).*vMotion.*" | Sort -Descending
        
        $vmo1 = Get-VMHost -Name $ESXiHostname | Get-VMHostNetworkAdapter | ? IP -eq $ESXiIPvMotion1
      
        if($vmo1 -eq $null){

            $vmo1 = New-Object VMware.Vim.HostVirtualNicSpec
            $dvPort = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
            $networkSystem = Get-View (Get-VMHost $ESXiHost).ExtensionData.ConfigManager.NetworkSystem

            $vmo1.DistributedVirtualPort = $dvPort
            $vmo1.DistributedVirtualPort.PortgroupKey = $pgs[0].Key
            $vmo1.DistributedVirtualPort.SwitchUuid = $pgs[0].VirtualSwitch.Key
            $vmo1.NetStackInstanceKey = 'vmotion'
            $vmo1.Mtu = 9000
            $ip = New-Object VMware.Vim.HostIpConfig
            $ip.subnetMask = $ESXiIPiSCSINetMask
            $ip.ipAddress = $ESXiIPvMotion1
            $ip.dhcp = $false
            $ip.ipV6Config = New-Object VMware.Vim.HostIpConfigIpV6AddressConfiguration
            $ip.ipV6Config.dhcpV6Enabled = $false
            $ip.ipV6Config.autoConfigurationEnabled = $false
            $vmo1.Ip = $ip

            $networkSystem.AddVirtualNic('', $vmo1)

        }else{ $vmo1 }
    
        $vmo2 = Get-VMHost -Name $ESXiHostname | Get-VMHostNetworkAdapter | ? IP -eq $ESXiIPvMotion2
        
        $esxcli = Get-EsxCli -VMHost (Get-VMHost $ESXiHostname) -V2        
    
        if($vmo2 -eq $null){

            $vmotion2 = New-VMHostNetworkAdapter `
            -VMHost (Get-VMHost $ESXiHostname) `
            -PortGroup $pgs[1] `
            -VirtualSwitch $pgs[1].VDSwitch `
            -IP $ESXiIPvMotion2 `
            -SubnetMask $ESXiIPvMotion2NetMask `
            -Mtu 1500 `
            -Confirm:0
    
            $vmk = $esxcli.network.ip.interface.ipv4.get.Invoke() |? name -eq $vmotion2.name
            $esxcli_args = $esxcli.network.ip.interface.ipv4.set.CreateArgs()
            $esxcli_args.interfacename = $vmk.Name
            $esxcli_args.gateway = $ESXivMotionGateway
            $esxcli_args.type = 'static'
            $esxcli_args.netmask = $vmk.IPv4Netmask
            $esxcli_args.ipv4 = $vmk.IPv4Address

            $esxcli.network.ip.interface.ipv4.set.Invoke($esxcli_args) | Out-Null

            Get-VMHost $ESXiHostname | Get-VMHostNetworkAdapter -Id $vmotion2.Id

        }else{ $vmo2 }

    ### Configure HBA

        # Enable software iSCSI HBA

        if('iSCSI Software Adapter' -notin (Get-VMHost $ESXiHostname | Get-VMHostHba).model){

            Get-VMHost $ESXiHostname | Get-VMHostStorage |
            Set-VMHostStorage -SoftwareIScsiEnabled $true | Out-Null
            $HBA = Get-VMHost $ESXiHostname | Get-VMHostHba | ? status -eq online
        }
    
        $HBA = Get-VMHost $ESXiHostname | Get-VMHostHba | ? status -eq online
    
        "`nConfiguring storage on $ESXiHostname and HBA: $($HBA.Device)`n" |
        Write-Host -ForegroundColor Green

        # Remove appended HEX from IQN

        $newname = $HBA.IScsiName -replace "(?<=$ESXiHostname).*"

        if($HBA.IScsiName -ne $newname){

            $HBA | Set-VMHostHba -IScsiName $newname
            $HBA = Get-VMHost $ESXiHostname | Get-VMHostHba -Device $HBA.Device
        }

        if($FlashArrays)
        {
            # Add host to pure flasharray
            
            "`nAdding $ESXiHostname to $($FlashArrays -join ', ')`n" | Write-Host -ForegroundColor Green

            $FlashArrays | % {

                Add-ESXiPureFlashArray `
                -ESXiHostname $ESXiHostname `
                -HBADevice $HBA.Device `
                -FlashArray $_ `
                -FlashArrayHostGroup $FlashArrayHostGroup `
                -DomainCredential $DomainCredential
            }

            # Set personality for host on arrays
            
            "`nSetting $ESXiHostname personality on $($FlashArrays -join ', ') to ESXi`n" | Write-Host -ForegroundColor Green

            $FlashArrays | % {
                Set-ESXiPersonalityPureFlashArray -ESXiHostname $ESXiHostname -FlashArray $_ -DomainCredential $DomainCredential
            }
        }
        
        $ESXiHBATargets | % {
            
            $newtarg = $HBA | Get-IScsiHbaTarget -Type Send | ? Address -eq $_ 
            if($newtarg -eq $null)
            {
                "`nAdding $ESXiHostname iSCSI Send target: $_`n" | Write-Host -ForegroundColor Green

                $HBA | New-IScsiHbaTarget -Address $_ -Port 3260 -Type Send
            }
        }
        
        if($FlashArrays){
            # Set iSCSI advanced params as per storage vendor best practice

            Set-ESXiHBATargetAdvancedSetting -ESXiHostname $ESXiHostname -HBADevice $HBA.Device `
            -Setting 'DelayedAck' -Value $false

            Set-ESXiHBATargetAdvancedSetting -ESXiHostname $ESXiHostname -HBADevice $HBA.Device `
            -Setting 'LoginTimeout' -IsInherited $false -Value 30
        }

        # Bind VMKs to HBA

        $iscsiVmks = $iSCSISwitch | Get-VMHostNetworkAdapter | ? IP -in $ESXiIPiSCSI
    
        "`nConfiguring port binding for $($HBA.Device) with VMKs: $( $iscsiVmks.Name -join ', ' )`n" | Write-Host -ForegroundColor Green        

        $iscsiVmks | % {    
            
            $esxcli_args = $esxcli.iscsi.networkportal.list.CreateArgs()
            $esxcli_args.adapter = $HBA.Device
            $bound = ($esxcli.iscsi.networkportal.list.Invoke($esxcli_args)).VMknic
            
            if($_.name -notin $bound)
            {
                $esxcli_args = $esxcli.iscsi.networkportal.add.CreateArgs()
                $esxcli_args.adapter = $HBA.Device
                $esxcli_args.force = $false
                $esxcli_args.nic = $_.name
                $esxcli.iscsi.networkportal.add.Invoke($esxcli_args) | Out-Null
            }
        }

        $esxcli_args = $esxcli.iscsi.networkportal.list.CreateArgs()
        $esxcli_args.adapter = $HBA.Device
        $esxcli.iscsi.networkportal.list.Invoke($esxcli_args) | Select Adapter,IPv4,VMknic

        # TF - manual storage access

        if($Datacenter.Name -eq 'TF'){ Read-Host -Prompt "Add host IQN - $newname - to access control in PowerVault and QNAP then [enter] to continue" }

        # Storage rescan

        Get-VMHost $ESXiHostname | Get-VMHostStorage -Refresh -RescanAllHba -RescanVmfs | Out-Null

        # Mount vVol datastores

        if($FlashArrays){
            $id = ((Get-VMHost $ESXiHostname).id -split '-')[-1]
            $datastoreSystemID = "HostDatastoreSystem-datastoreSystem-"+$id
            $datastoreSystem = Get-View -Id $datastoreSystemID

            Get-Datastore -Location $Datacenter | ? Type -eq 'VVOL' | % {
                $url = $_.ExtensionData.info.url
                $scid = ($url -split '/')[-2]
                $spec = New-Object VMware.Vim.HostDatastoreSystemVvolDatastoreSpec
                $spec.Name = $_.Name
                $spec.ScId = $scid            
                $datastoreSystem.CreateVvolDatastore($spec)
            }
        }

        ### Configure persistent locations

        "`nConfiguring $ESXiHostname peristent locations for productLocker, logs and vmkdump`n" |
        Write-Host -ForegroundColor Green

        $curPL = (Get-VMHost $ESXiHostname | Get-AdvancedSetting -Name UserVars.ProductLockerLocation).value
        
        if($curPL -eq '/locker/packages/vmtoolsRepo/')
        {
            # Enable MOB web plugin and add productLocker
        
            Get-VMHost $ESXiHostname | Get-AdvancedSetting -Name 'Config.HostAgent.plugins.solo.enableMob' | Set-AdvancedSetting -Value $true -Confirm:0 |
            Out-Null

            Read-Host -Prompt "`nAdd productLocker then [Enter] to continue...`n`nhttps://$ESXiHostname/mob/?moid=ha-host`t"
        }
        
        $TgtDs = Get-Datastore $SysLogDatastore
        $folder = $ESXiHostname -replace '\.zhost',''
        
        $curSysLog = (Get-VMHost $ESXiHostname | Get-AdvancedSetting -Name 'Syslog.global.logDir').value
        $newSysLog = "[$($TgtDs.Name)] zHostLogs/$folder"
        
        $curScratch = (Get-VMHost $ESXiHostname | Get-AdvancedSetting -Name 'ScratchConfig.ConfiguredScratchLocation').value
        $newScratch = "$($TgtDs.ExtensionData.Summary.url)zHostLogs/$folder/Scratch" -replace 'ds://',''

        if(($curSysLog -ne $newSysLog) -or ($curScratch -ne $newScratch))
        {
            New-PSDrive -Name 'TgtDS' -Location $TgtDs -PSProvider VimDatastore -Root '\'
            
            $folderObj = Get-Item -Path "TgtDS:\zHostLogs\$folder" -ErrorAction Ignore
            if($folderObj -eq $null)
            {
                New-Item -Path 'TgtDS:\zHostLogs\' -Name $folder -ItemType Directory
                New-Item -Path "TgtDS:\zHostLogs\$folder" -Name 'Scratch' -ItemType Directory
            }
            else
            {
                $scratchFolderObj = Get-Item -Path "TgtDS:\zHostLogs\$folder\Scratch" -ErrorAction Ignore
                if($scratchFolderObj -eq $null)
                {
                    New-Item -Path "TgtDS:\zHostLogs\$folder" -Name 'Scratch' -ItemType Directory
                }
            }
        }

        Get-VMHost $ESXiHostname |
        Get-AdvancedSetting -Name 'ScratchConfig.ConfiguredScratchLocation' |
        Set-AdvancedSetting -Value $newScratch -Confirm:0

        Get-VMHost $ESXiHostname |
        Get-AdvancedSetting -Name 'Syslog.global.logDir' |
        Set-AdvancedSetting -Value $newSysLog -Confirm:0
        
        $vmkdumpLoc = "$($TgtDs.ExtensionData.Summary.url)vmkdump/$folder-vmkdump.dumpfile" -replace 'ds://',''
        $vmkdumpObj = Get-Item -Path ($vmkdumpLoc -replace '/','\') -ErrorAction Ignore

        if($vmkdumpObj -eq $null)
        {
            $esxcli_args = $esxcli.system.coredump.file.add.CreateArgs()
            $esxcli_args.file = "$folder-vmkdump"
            $esxcli_args.datastore = $TgtDs.Name 
            $esxcli_args.enable = $true
            $esxcli.system.coredump.file.add.Invoke($esxcli_args) | Out-Null

            $esxcli_args = $esxcli.system.coredump.file.set.CreateArgs()
            $esxcli_args.path = $vmkdumpLoc
            $esxcli.system.coredump.file.set.Invoke($esxcli_args) | Out-Null
            
            $esxcli.system.coredump.partition.set.Invoke(@{unconfigure = $true}) | Out-Null
            $esxcli.system.coredump.partition.set.Invoke(@{enable = $false}) | Out-Null
            $esxcli.system.coredump.network.set.Invoke(@{enable = $false}) | Out-Null
        }

        Get-PSDrive TgtDs | Remove-PSDrive

    ### Join domain
        
        "`nJoining $ESXiHostname to domain.local domain`n" | Write-Host -ForegroundColor Green
    
        Get-VMHost $ESXiHostname | Get-VMHostAuthentication | Set-VMHostAuthentication -JoinDomain -Domain "domain.local" -Credential $JoinDomainCredential -Confirm:0

    ### Set NTP server

        "`nSetting NTP server on $ESXiHostname to time.domain.local`n" | Write-Host -ForegroundColor Green

        Set-ESXiNtp -ESXiHost $ESXiHostname

    ### Set ESXi SSH access

        "`nRestricting SSH access on $ESXiHostname`n" | Write-Host -NoNewline -ForegroundColor Green

        Set-ESXiSSH -ESXiHost $ESXiHostname

        Get-VMHost $ESXiHostname | Get-VMHostService | ? Key -like TSM*| Set-VMHostService -Policy Off | Stop-VMHostService -Confirm:0

    ### Set ESXi Power Management

        "`nSetting Power Management on $ESXiHostname to High Performance`n" | Write-Host -ForegroundColor Green

        Set-ESXiPowerManagement -ESXiHost $ESXiHostname

    ### Set SysLog server        
        
        if($SysLogServer){
            
            "`nSetting syslog server setting on $ESXiHostname to udp://$( $SysLogServer ):1514`n" | Write-Host -ForegroundColor Green

            Get-VMHost $ESXiHostname | Get-AdvancedSetting -Name 'Syslog.global.logHost' | Set-AdvancedSetting -Value "udp://$( $SysLogServer ):1514" -Confirm:0
        }

    ### Set spectre and meltdown mitigation

        "`nSetting spectre and meltdown mitigation settings on $ESXiHostname to enable inter-VM security boundaries`n" | Write-Host -ForegroundColor Green
                
        Get-VMHost $ESXiHostname | Get-AdvancedSetting -Name 'VMkernel.Boot.hyperthreading' | Set-AdvancedSetting -Value $true -Confirm:0
        Get-VMHost $ESXiHostname | Get-AdvancedSetting -Name 'VMkernel.Boot.hyperthreadingMitigation' | Set-AdvancedSetting -Value $true -Confirm:0
        Get-VMHost $ESXiHostname | Get-AdvancedSetting -Name 'VMkernel.Boot.hyperthreadingMitigationIntraVM' | Set-AdvancedSetting -Value $false -Confirm:0

    ### Set Pure PSP

        if($FlashArrays){
            $esxcli_args = @{
                satp = "VMW_SATP_ALUA";
                vendor = "PURE";
                model = "FlashArray";
                psp = "VMW_PSP_RR";
                pspoption = "policy=latency";
                description = "FlashArray SATP Rule"
            }

            $esxcli.storage.nmp.satp.rule.add.Invoke($esxcli_args)

            Get-VMHost $ESXiHostname | Get-Datastore *ssd-pure* | % {

                $diskname = $_.extensiondata.info.vmfs.extent.diskname
                $esxcli.storage.nmp.psp.roundrobin.deviceconfig.set.Invoke(@{type = 'latency'; device = $diskname})
            }
        }

    ### Update ESXi with VUM
        
        if($Baseline){

            "`nApplying ESXi updates to $ESXiHostname using baseline $($Baseline.Name)`n" |
            Write-Host -ForegroundColor Green

            Update-ESXiVUMBaseline -ESXiHostname $ESXiHostname -Baseline $Baseline -Reboot $true

            "`n$ESXiHostname has finished installing baseline: '$($Baseline.name)'. Build should continue?`n" | Write-Host -ForegroundColor Green

            Send-MailMessage -From ("$ENV:USERNAME@$ENV:COMPUTERNAME.$ENV:USERDNSDOMAIN").tolower() `
            -Subject "$ESXiHostname has finished installing baseline: '$($Baseline.name)' and build should continue?"`
            -SmtpServer $SMTP -To $AlertDestination
            
            $ans = Read-Host -Prompt '[y/n]'

            if($ans -ne 'y')
            {
                "`nQuitting...`n" | Write-Host -ForegroundColor Green
                break
            }

            Detach-Baseline -Entity (Get-VMHost $ESXiHostname) -Baseline $Baseline 
        }
        
    ### Install iDRAC Service Module

        $iSM = Get-Baseline -Name '6.7 iDRAC Service Module v4.2.0.0'
        if($iSM){
            "`nInstalling iDRAC Service Module on $ESXiHostname using baseline $($iSM.Name)`n" |
            Write-Host -ForegroundColor Green

            
            Update-ESXiVUMBaseline -ESXiHostname $ESXiHostname -Baseline $iSM -Reboot $true
            
            "`n$ESXiHostname has finished installing baseline: '$($iSM.name)'`n" | Write-Host -ForegroundColor Green

            Send-MailMessage -From ("$ENV:USERNAME@$ENV:COMPUTERNAME.$ENV:USERDNSDOMAIN").tolower() `
            -Subject "$ESXiHostname has finished installing baseline: '$($iSM.name)' and build should continue?"`
            -SmtpServer $SMTP -To $AlertDestination
            
            $ans = Read-Host -Prompt '[y/n]'

            if($ans -ne 'y')
            {
                "`nQuitting...`n" | Write-Host -ForegroundColor Green
                break
            }

            Detach-Baseline -Entity (Get-VMHost $ESXiHostname) -Baseline $iSM
        }

        Send-MailMessage -From ("$ENV:USERNAME@$ENV:COMPUTERNAME.$ENV:USERDNSDOMAIN").tolower() `
        -Subject "$ESXiHostname ready for validation, licensing and enabling of alarm actions"`
        -SmtpServer $SMTP -To $AlertDestination
    }
}