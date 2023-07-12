$sshcred = Get-Credential
$sshcred1 = Get-Credential
$hosts = get-vmhost

foreach ($hosty in $hosts) {
    
    if ($hosty.build -eq '7388607'){
        $sessh = New-SSHSession $hosty.name -Credential $sshcred -AcceptKey
    } else {
        $sessh = New-SSHSession $hosty.name -Credential $sshcred1 -AcceptKey
    }

    $vMotionIps = (Get-VMhost | ? name -ne $hosty.name | Get-VMHostNetworkAdapter | ? vmotionenabled -eq $true).IP

    Log-Host "`n$($hosty.name)`n" -ForegroundColor Yellow -FilePath .\Desktop\brap.txt
    
    $vMotionIps | % {
        Log-Host "`nping $_ `n" -ForegroundColor Green -FilePath .\Desktop\brap.txt
        Log-Host "$((Invoke-SSHCommand -SSHSession $sessh 'hostname').Output)`n" -ForegroundColor Magenta `
        -FilePath .\Desktop\brap.txt
        Log-Host (Invoke-SSHCommand -SSHSession $sessh "ping $_ -c 2").Output -FilePath .\Desktop\brap.txt
    }

    Remove-SSHSession -SSHSession $sessh | Out-Null
}