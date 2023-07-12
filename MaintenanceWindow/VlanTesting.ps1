$esxCred = Get-Credential

#$vmhosts = gvh -Location DCB
$vmhosts = gvh -Location DCA

#get powered on vm with one network adapter in each vlan with ip like 172*
$testIps = $vmhosts |
Get-VirtualSwitch -Name *0 | Get-VirtualPortGroup | % {
        
    if($_.key -like "dvportgroup*")
    {
        $vlan = $_.extensiondata.config.defaultportconfig.vlan.vlanid
    }
    else
    {
        $vlan = $_.vlanid
    }

    $pg = $_.name

    $_ | gvm | ? power* -match on | ? {($_ | Get-NetworkAdapter).count -eq 1} |
    ? {($_.guest.ipaddress | ? {$_ -like "172*"} | sel -first 1) -ne $null} |
    sel name,
    @{n='vmhostName';e={$_.vmhost.name}},
    @{n='pg';e={$pg}},
    @{n='vlan';e={$vlan}},
    @{n='ip';e={($_.guest.ipaddress | ? {$_ -like "172*"} | sel -first 1)}}
}

# group test ips by vlan
$byVlan = $testIps | Group vlan

# get uplink used vmk0
$vmhostsToTest = $vmhosts | sel name,
@{n='vmk0Uplink';e={
    
    cvi $_.name -Credential $esxCred | Out-Null

    Get-EsxTop -Server $_.name -CounterName netport |
    ? clientname -eq vmk0 | sel -ExpandProperty teamuplink

    Disconnect-VIServer $_.name -con:0 | Out-Null
}}

# where there is only one vm in a vlan, exclude the host where that vm is running
$vmhostsToTest = $vmhostsToTest |
? name -NotIn (($byVlan | ? count -eq 1).group.vmhostname)

# pick a host using lan blade a1 and one using lan blade a2
$vmhostsToTest = $vmhostsToTest | sort vmk0uplink |
sel -Index 0,($vmhostsToTest.count-1)

$results = $vmhostsToTest | % {
    
    $vmhostName = $_.name
    $vmhostUplink = $_.vmk0Uplink
    $sessh = New-SSHSession -ComputerName $vmhostName -Credential $esxCred -AcceptKey -Force

    # for each vlan, pick a random VM
    $byVlan | % {

        if($_.count -gt 1)
        {
            $test = $_.Group | ? vmhostName -ne $vmhostName | get-random
        }
        else
        {
            $test = $_.Group
        }

        $vm = $test.name
        $pg = $test.pg
        $vlan = $test.vlan
        $ip = $test.ip
        
        # ping vm ip with 2 packets and timeout of 1
        $output = (Invoke-SSHCommand -Command "ping $ip -c 2 -W 1 | grep 'packet loss'" `
        -SSHSession $sessh).output

        # create object of result
        if($output -like "*packet loss")
        {
            $output = $output -split ', '
            
            [pscustomobject]@{
                vmhost = $vmhostName
                vmhostUplink = $vmhostUplink
                vm = $vm
                pg = $pg
                vlan = $vlan
                ip = $ip
                pktsTransmitted = $output[0][0]
                pktsReceived = $output[1][0]
                pktsPcntLost = ($output[2] -split ' ')[0]
            }
        }
        else
        {
            [pscustomobject]@{
                vmhost = $vmhostName
                vmhostUplink = $vmhostUplink
                vm = $vm
                pg = $pg
                vlan = $vlan
                ip = $ip
                pktsTransmitted = $output
                pktsReceived = $output
                pktsPcntLost = $output
            }
        }
    }
    
    Remove-SSHSession -SSHSession $sessh | Out-Null
}

# output results

$results | Export-Csv .\hosts_to_vlans_tests.csv -NoTypeInformation

if($null -ne ($results | ? pktsReceived -eq 0)){$results | ? pktsReceived -EQ 0 | Export-Csv .\no_pkt_received.csv -NoTypeInformation}