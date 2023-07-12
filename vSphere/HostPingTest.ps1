#zhost19 : 172.31.1.90 -> zhost8 : 172.31.1.76		vMotion : 172.31.254.27, 172.31.9.11		iSCSI : 172.31.254.115, 172.31.254.116

$ip = "172.31.1.76
172.31.254.214
172.31.254.215
172.31.254.216
172.31.254.217
172.31.254.218
172.31.254.219
172.31.254.220" -split "`n"
$esxcred = Get-Credential

$results = $ip | % {

    $sessh = New-SSHSession -ComputerName zhost1.zhost -Credential $esxCred -AcceptKey -Force
    
    $output = (Invoke-SSHCommand -Command " vmkping -I vmk1 $_ -c 2 -W 1 | grep 'packet loss'" `
            -SSHSession $sessh).output

    # create object of result
    if($output -like "*packet loss")
    {
        $output = $output -split ', '
        
        [pscustomobject]@{
            ip = $_
            pktsTransmitted = $output[0][0]
            pktsReceived = $output[1][0]
            pktsPcntLost = ($output[2] -split ' ')[0]
        }
    }
    else
    {
        [pscustomobject]@{
            ip = $_
            pktsTransmitted = $output
            pktsReceived = $output
            pktsPcntLost = $output
        }
    }

    Remove-SSHSession -SSHSession $sessh | Out-Null
}