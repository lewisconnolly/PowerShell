## dependencies:

Set-Alias -Name 'gvm' -Value 'Get-VM'

Set-Alias -Name 'gvh' -Value 'Get-VMHost'

Set-Alias -Name 'cvi' -Value 'Connect-VIServer'

Import-Module PureStoragePowerShellSDK -Force
##

function Connect-VBPtoFA2 ($veeamproxy, $portgroup, $ip, $domaincred, $faName, $arrayScsiIps, $arrayIqn)
{   
    ## on vm
    gvm $veeamproxy | New-NetworkAdapter -Portgroup $portgroup -StartConnected -Type Vmxnet3 
 
    ## in guest
    $iqn = Invoke-Command -ComputerName $veeamproxy -Credential $domaincred -ArgumentList $ip `
    -ScriptBlock { 

        # enable iscsi initiator
        get-service *iscsi* | start-service | out-null
        Get-NetAdapter *ethernet1* | Remove-NetIPAddress | Out-Null
        Get-NetAdapter *ethernet1* | New-NetIPAddress -IPAddress $args[0] -AddressFamily IPv4 -PrefixLength 24 |
        Out-Null
        $iqn = (Get-InitiatorPort).NodeAddress
        $iqn
    }
    # add host to pure
    $fa = New-PfaArray -EndPoint $faName `
    -UserName lewisc -Password $domaincred.Password -IgnoreCertificateError
    # add host then add iqn from above output
    New-PfaHost -Array $fa -Name $veeamproxy -IqnList $iqn
    # add to veeamplugin hosts group
    $vbp=Get-PfaHost -Name $veeamproxy -Array $fa
    $group = Get-PfaHostGroup -Array $fa -Name 'DCA-VeeamProxies'
    Add-PfaHosts -Array $fa -Name $group.name -HostsToAdd $vbp.name
    
    Invoke-Command -ComputerName $veeamproxy -Credential $domaincred -ArgumentList $ip, $arrayScsiIps, $arrayIqn `
    -ScriptBlock { 

        $ip = $args[0]
        $arrayScsiIps = $args[1]
        $arrayIqn = $args[2] 
        
        $arrayScsiIps | % {

            New-IscsiTargetPortal -TargetPortalAddress $_
            Connect-IscsiTarget -NodeAddress $arrayIqn `
            -TargetPortalAddress $_ -TargetPortalPortNumber 3260 -InitiatorPortalAddress $ip `
            -IsPersistent $true -IsMultipathEnabled $true
        }
    }
}

function Enable-VbpMpio ($veeamproxy, $domaincred, $installMPIOFeature)
{
    if($installMPIOFeature)
    {
        $veeamproxy | % {
        
            Invoke-Command -ComputerName $_ -Credential $domaincred -ScriptBlock {
        
                Get-WindowsFeature *multipath*|Install-WindowsFeature -Restart
            }

            Read-Host -Prompt "`n[Enter] when $_ has rebooted... "
        }
    }

    $veeamproxy | % {

        Invoke-Command -ComputerName $_ -Credential $domaincred -ScriptBlock {
    
            Enable-MSDSMAutomaticClaim -BusType iSCSI -Confirm:0

            Restart-Computer -Confirm:0 -Force| Out-Null
        }
        
        Read-Host -Prompt "`n[Enter] when $_ has rebooted... "

        Invoke-Command -ComputerName $_ -Credential $domaincred -ScriptBlock {

            New-MSDSMSupportedHw -VendorId PURE -ProductId FlashArray
            Remove-MSDSMSupportedHw -VendorId 'Vendor*' -ProductId 'Product*'
            
            Restart-Computer -Confirm:0 -Force | Out-Null
        }
    }
}
