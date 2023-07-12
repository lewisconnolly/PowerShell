$denyts = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name “fDenyTSConnections” 
$userauth = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name “UserAuthentication”

if($denyts.fDenyTSConnections -ne 0){
 Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name “fDenyTSConnections” -Value 0
}

if($userauth.UserAuthentication -ne 1){
 Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name “UserAuthentication” -Value 1
}
