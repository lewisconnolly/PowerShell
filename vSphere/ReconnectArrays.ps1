$nics = (Get-NetIPAddress -AddressFamily IPv4 | ? IPAddress -like 172.3*.254.*).IPAddress

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

<#$dcaFA3IPs = 
    '172.31.254.221',
    '172.31.254.222',
    '172.31.254.223',
    '172.31.254.224',
    '172.31.254.225',
    '172.31.254.226',
    '172.31.254.227',
    '172.31.254.228'#>

#$dcaFA3IPs | % { New-IscsiTargetPortal -TargetPortalAddress $_ -TargetPortalPortNumber 3260 }

$FA1TargetName = 'iqn.2010-06.com.purestorage:flasharray.43fa7979c66654f4'
$FA2TargetName = 'iqn.2010-06.com.purestorage:flasharray.325f7add91c6c233'
#$FA3TargetName = 'iqn.2010-06.com.purestorage:flasharray.21c1a6ef1661814e'

Get-IscsiSession | ? TargetNodeAddress -match 'purestorage' | % { Disconnect-IscsiTarget -SessionIdentifier $_.SessionIdentifier -NodeAddress $_.TargetNodeAddress -Confirm:0 }

$nics | % {
    
    $nic = $_
    
    $dcaFA1IPs | % {
        Connect-IscsiTarget -InitiatorPortalAddress $nic -TargetPortalAddress $_ -IsMultipathEnabled $true -NodeAddress $FA1TargetName -IsPersistent $true
    }
    
    $dcaFA2IPs | % {
        Connect-IscsiTarget -InitiatorPortalAddress $nic -TargetPortalAddress $_ -IsMultipathEnabled $true -NodeAddress $FA2TargetName -IsPersistent $true
    }
    
    <#$dcaFA3IPs | % {
        Connect-IscsiTarget -InitiatorPortalAddress $nic -TargetPortalAddress $_ -IsMultipathEnabled $true -NodeAddress $FA3TargetName -IsPersistent $true
    }#>
}