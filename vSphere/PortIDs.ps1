Set-Alias -Name 'gvm' -Value 'Get-VM'

Set-Alias -Name 'gvh' -Value 'Get-VMHost'

$portIds = gvh zhost19* |
Get-VirtualPortGroup -Standard | ? port -is [array] | % {

    $vmhost = (gvh -id $_.vmhostid).name
    $pg = $_
    $vms = $pg|gvm
    $nics = $pg|Get-VMHostNetworkAdapter
    
    $_.port | % {
        
        $portId = ($_.key -split '-')[-1]
        $mac = $_.mac

        $connectees = $vms|%{
            $vm = $_
            $mac | % {
                if(($vm | Get-NetworkAdapter).macaddress -contains $_)
                {
                    $vm.Name
                }
            }
        } | select -Unique
    
        $connectees += $nics|%{
            $nic = $_
            if($nic.mac -eq $mac)
            {
                $nic.Name
            }
        } | select -Unique
    
        [pscustomobject]@{
            vmhost = $vmhost
            portgroup = $pg.Name
            portId = $portId
            mac = $mac
            'connectee(s)' = $connectees
        }
    }
}