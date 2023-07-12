Get-WindowsFeature -Name 'Multipath-IO'
Add-WindowsFeature -Name 'Multipath-IO'
Get-MSDSMSupportedHw
New-MSDSMSupportedHw -VendorId PURE -ProductId FlashArray
Remove-MSDSMSupportedHw -VendorId 'Vendor*' -ProductId 'Product*'
Get-MPIOSetting
Set-MPIOSetting -NewPathRecoveryInterval 20 -CustomPathRecovery Enabled -NewPDORemovePeriod 30 -NewDiskTimeout 60 -NewPathVerificationState Enabled
Get-MSDSMGlobalDefaultLoadBalancePolicy
Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR
Enable-MSDSMAutomaticClaim -BusType iSCSI -Confirm:0

Get-StorageSetting
Set-StorageSetting -NewDiskPolicy OnlineAll

$nics = '172.31.254.90','172.31.254.91'

$arrayIPs = '172.31.254.213',
'172.31.254.214',
'172.31.254.215',
'172.31.254.216',
'172.31.254.217',
'172.31.254.218',
'172.31.254.219',
'172.31.254.220'

$arrayIPs | % { New-IscsiTargetPortal -TargetPortalAddress $_ -TargetPortalPortNumber 3260 }

$targetName = 'iqn.2010-06.com.purestorage:flasharray.325f7add91c6c233'

$nics | % {
    $nic = $_
    $arrayIPs | % {
        Connect-IscsiTarget -InitiatorPortalAddress $nic -TargetPortalAddress $_ -IsMultipathEnabled $true -NodeAddress $targetName -IsPersistent $true
    }
}