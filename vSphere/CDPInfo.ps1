

$cdpinfo  = gvh | % {Get-View $_.ID} | `
  % { $esxname = $_.Name; Get-View $_.ConfigManager.NetworkSystem} | `
  % { foreach ($physnic in $_.NetworkInfo.Pnic) {
    $pnicInfo = $_.QueryNetworkHint($physnic.Device)
    foreach( $hint in $pnicInfo ){
       if ( $hint.ConnectedSwitchPort ) {
        $hint.ConnectedSwitchPort | select @{n="VMHost";e={$esxname}},@{n="VMNic";e={$physnic.Device}},DevId,Address,PortId,vLan
        }
      }
    }
  }