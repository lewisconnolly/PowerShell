##################################
### Get-VMDataProtectionStatus ###
###       lewis.connolly       ###
##################################

# Creates report of Windows servers connected to Pure Storage FlashArrays and their iSCSI related configuration
function Get-WindowsPureiSCSIConfiguration {
    
    $PureiSCSIServers =
        'dca-utl-nas3',
        'dcautlprdvbp01',
        'dcautlprdvbp02',
        'dcautlprdvbp03',
        'dcautlprdvbp04',
        'dcautlprdvbp05',
        'dcautlprdvbp06',
        'dcautlprdvbp07',
        'dcautlprdvbp08',
        'dcb-utl-nas3',
        'dcbutlprdvbp01'

    $dcaFA1IPs =
        '172.31.254.205',
        '172.31.254.206',
        '172.31.254.207',
        '172.31.254.208',
        '172.31.254.209',
        '172.31.254.210',
        '172.31.254.211',
        '172.31.254.212'

    $dcaFA2IPs =
        '172.31.254.213',
        '172.31.254.214',
        '172.31.254.215',
        '172.31.254.216',
        '172.31.254.217',
        '172.31.254.218',
        '172.31.254.219',
        '172.31.254.220'

    $dcbFA1IPs =
        '172.30.254.201',
        '172.30.254.202',
        '172.30.254.205',
        '172.30.254.206',
        '172.30.254.203',
        '172.30.254.204',
        '172.30.254.207',
        '172.30.254.208'
    
    $dcbFA2IPs = 
        '172.30.254.209',
        '172.30.254.210',
        '172.30.254.213',
        '172.30.254.214',
        '172.30.254.211',
        '172.30.254.212',
        '172.30.254.215',
        '172.30.254.216'

    # Servers not currently required to connect to DCA FA3 directly
    <#$dcaFA3IPs = 
        '172.31.254.221',
        '172.31.254.222',
        '172.31.254.223',
        '172.31.254.224',
        '172.31.254.225',
        '172.31.254.226',
        '172.31.254.227',
        '172.31.254.228'#>    

    #$PureiSCSIServers = 'dcautlprdvbp01'

    $PureiSCSIServers | % {
        # Gather configuration on each server
        Invoke-Command -ComputerName $_ -ArgumentList $dcaFA1IPs, $dcaFA2IPs, $dcbFA1IPs, $dcbFA2IPs -HideComputerName -ScriptBlock {
            
            # Get iSCSI NICs            
            $iSCSINICs = Get-NetIPAddress -AddressFamily IPv4 | ? IPAddress -like 172.3*.254.*

            # Get iSCSI network IPs
            $iSCSIIPs = $iSCSINICs.IPAddress -join ', '

            # Get iSCSI NICs' MTUs
            $iSCSIMTUs = (Get-NetAdapterAdvancedProperty  -Name $iSCSINICs.InterfaceAlias -RegistryKeyword "*JumboPacket").RegistryValue
            
            # Get all iSCSI connections
            $iSCSIConnections = Get-IscsiConnection
            
            # Get number of connections to each array
            $numFA1Connections = ($iSCSIConnections | ? TargetAddress -in $args[0]).Count
            $numFA2Connections = ($iSCSIConnections | ? TargetAddress -in $args[1]).Count
            $numDCBFA1Connections = ($iSCSIConnections | ? TargetAddress -in $args[2]).Count
            $numDCBFA2Connections = ($iSCSIConnections | ? TargetAddress -in $args[3]).Count
            #$numFA3Connections = ($iSCSIConnections | ? TargetAddress -in $args[2]).Count
            
            # Check if Multipath-IO feature is installed
            $multipathFeature = (Get-WindowsFeature -Name 'Multipath-IO').Installed
            
            # Check MPIO support for Pure devices has been added
            $MSDSMSupportedHw = $false
            if(Get-MSDSMSupportedHw | ? VendorId -eq PURE | ? ProductId -eq FlashArray){$MSDSMSupportedHw = $true}

            # Check MPIO parameters
            $MPIOSettings = Get-MPIOSetting
            
            # Check load balancing policy
            $LoadBalancing = Get-MSDSMGlobalDefaultLoadBalancePolicy

            # Check Policy for new disks
            $NewDiskPolicy = (Get-StorageSetting).NewDiskPolicy

            # Check claim settings for iSCSI devices 
            $claimSettings = Get-MSDSMAutomaticClaimSettings
            $iSCSIClaimSetting = $claimSettings['iSCSI']
            
            # Check for non best practice values
            $RetryIntervalBP = 1,3

            if(
                (($iSCSIMTUs | select -Unique) -ne 9014) -or
                (-not$multipathFeature) -or
                (-not$MSDSMSupportedHw) -or
                ($MPIOSettings.PathVerificationState -ne 'Enabled') -or
                ($MPIOSettings.PathVerificationPeriod -ne 30) -or
                ($MPIOSettings.PDORemovePeriod -ne 30) -or
                ($MPIOSettings.RetryCount -ne 3) -or
                ($MPIOSettings.RetryInterval -notin $RetryIntervalBP) -or
                ($MPIOSettings.UseCustomPathRecoveryTime -ne 'Enabled') -or
                ($MPIOSettings.CustomPathRecoveryTime -ne 20) -or
                ($MPIOSettings.DiskTimeoutValue -ne 60) -or
                ($LoadBalancing -ne 'RR') -or
                ($NewDiskPolicy -ne 'OfflineShared') -or
                (-not$iSCSIClaimSetting)
            ){ $status = 'Warning' }else{ $status = 'OK' }

            [PSCustomObject]@{
                Status = $status
                Hostname = hostname
                iSCSIIPs = $iSCSIIPs
                iSCSIMTUs = $iSCSIMTUs -join ', '
                NumDCAFA1Connections = $numFA1Connections
                NumDCAFA2Connections = $numFA2Connections
                NumDCBFA1Connections = $numDCBFA1Connections
                NumDCBFA2Connections = $numDCBFA2Connections
                #NumDCAFA3Connections = $numFA3Connections
                MultipathFeatureInstalled = $multipathFeature
                MSDSMSupportedHwPureEntryPresent = $MSDSMSupportedHw
                PathVerificationState = $MPIOSettings.PathVerificationState
                PathVerificationPeriod = $MPIOSettings.PathVerificationPeriod
                PDORemovePeriod = $MPIOSettings.PDORemovePeriod
                RetryCount = $MPIOSettings.RetryCount
                RetryInterval = $MPIOSettings.RetryInterval
                UseCustomPathRecoveryTime = $MPIOSettings.UseCustomPathRecoveryTime
                CustomPathRecoveryTime = $MPIOSettings.CustomPathRecoveryTime
                DiskTimeoutValue = $MPIOSettings.DiskTimeoutValue
                LoadBalancingPolicy = $LoadBalancing
                NewDiskPolicy = $NewDiskPolicy
                iSCSIAutomaticClaimSetting = $iSCSIClaimSetting
            }
        }
    } | select * -ExcludeProperty RunspaceId, PSComputerName, PSShowComputerName
}

### Report Framework

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

$windowsPureiSCSIConfiguration = Get-WindowsPureiSCSIConfiguration

$reportContext = "Best practice guide: https://support.purestorage.com/Solutions/Microsoft_Platform_Guide/Quick_Setup_Steps/Step_01
<br><br>
<b>MSDSMSupportedHWPureEntryPresent</b> - Checks Pure devices have been added as supported for MPIO. <b>BP = True</b>
<br>
<b>PathVerificationState</b> - Specifies whether to enable path verification. <b>BP = Enabled</b>
<br>
<b>PathVerificationPeriod</b> - Specifies a path verification period, in seconds. This is the length of time for the server to verify every path. <b>BP = 30</b>
<br>
<b>PDORemovePeriod</b> - Specifies a physical device object (PDO) removal period, in seconds. This period is the length of time the server waits after all paths to a PDO have failed before it removes the PDO. <b>BP = 30</b>
<br>
<b>RetryCount</b> - Specifies the number of times to retry an I/O request. <b>BP = 3</b>
<br>
<b>RetryInterval</b> - Specifies a retry interval, in seconds. This is the length of time after which the server retries a failed I/O request. <b>BP = 1 or 3</b>
<br>
<b>UseCustomPathRecoveryTime</b> - Specifies whether MPIO performs custom path recovery. <b>BP = 1</b>
<br>
<b>CustomPathRecoveryTime</b> - Specifies a custom path recovery time, in seconds. This is the length of time before the server attempts path recovery. <b>BP = 20</b>
<br>
<b>DiskTimeoutValue</b> - Specifies the disk timeout value, in seconds. This value is the length of time the server waits before it marks the I/O request as timed out. <b>BP = 60</b>
<br>
<b>LoadBalancingPolicy</b> - Default load balance policy for Microsoft Multipath I/O (MPIO) devices. <b>BP = RR</b> (Round Robin - distributes IOs evenly across all Active/Optimized paths and suitable for most environments)
<br>
<b>NewDiskPolicy</b> - The policy that will be applied to newly attached disks. <b>BP =  OfflineShared</b> (All disks on sharable busses, such as iSCSI, FC, or SAS are left offline by default)
<br> 
<b>iSCSIAutomaticClaimSetting</b> - Setting that determines if iSCSI disks are automatically claimed for Multipath I/O. <b>BP = True</b>"

$windowsPureiSCSIConfiguration |
ConvertTo-HtmlReport `
    -ReportTitle "Windows Pure iSCSI Configuration" `
    -ReportDescription "Best practice configuration for connecting Windows servers to Pure arrays via iSCSI" `
    -ReportContext $reportContext `
    -FilePath "C:\inetpub\Html Reports\windowspureiscsiconfig.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "C:\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "C:\inetpub\wwwroot\index.html" `
    -VirtualPath "/"