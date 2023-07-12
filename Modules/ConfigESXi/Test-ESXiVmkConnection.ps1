<#
.Synopsis
   Ping from vmk to target IP on ESXi host via SSH
.EXAMPLE
## Specify host only:

    
    # Connect to vCenter

        Connect-ViServer dca-vcenter


    # Set host credential

        $zhostcred = get-credential


    # Ping from zhost25.zhost to all default IPs from all default vmks

        $results = Test-ESXiVmkConnection -VMHost zhost25* -Credential $zhostcred


    # Save results to a file

        $results | Out-File .\hostping.txt
.EXAMPLE
## Specify host, IPs and vmks:
   

    # Ping from zhost25.zhost, zhost26.zhost and zhost12.zhost to 2 IPs from vmk2 and vmk3 (vmks on iSCSI network)

        $results = Test-ESXiVmkConnection -VMHost zhost25*,*26*,zhost12.zhost -IP '172.31.254.201','172.31.254.254' -Vmk 'vmk2','vmk3' -Credential $zhostcred
.EXAMPLE
## !TAKES AGES! Full batch of iSCSi tests. 16 hosts * 2 vmks * 13 iSCSi IPs * 3 packets = 1248 pings!  ##
   

    # Ping default IPs (all known 172.31.254.X IPs) from all vmk2 and 3. 

        $results = Test-ESXiVmkConnection -Vmk 'vmk2','vmk3' -Credential $zhostcred 
.INPUTS
   -VMHost

   Default is all hosts. Takes strings or VMHost objects.


   -IP

   Default is all 172.31.254.X IPs. Pass as a list. E.g. '1.1.1.1','1.1.1.2' or $IPs = '8.8.8.8','8.8.4.4'


   -Vmk

   Default is vmk0, vmk1, vmk2 and vmk3. Same as -IP.


   -Count

   Number of packets to send. Default is 3. 

   
   -Credential

   Mandatory. Takes System.Management.Automation.PSCredential objects.
.OUTPUTS
   Outputs an object array of vmks and ping results by packet loss.
#>
function Test-ESXiVmkConnection
{

    Param
        (
            $VMHost,

            $IP = @('172.31.254.201',
                '172.31.254.202',
                '172.31.254.203', 
                '172.31.254.204',
                '172.31.254.240',
                '172.31.254.242',
                '172.31.254.243',
                '172.31.254.244',
                '172.31.254.254'),

            $Vmk = @('vmk0','vmk1','vmk2','vmk3'),

            $Count = 3,

            [Parameter(Mandatory=$true)]
            [System.Management.Automation.PSCredential]
            $Credential
        )
    
    try{
        if(!$VMHost){$VMhost = Get-vmhost}

        $vmhost = Get-VMHost $VMHost 
        ${Hosts&IPs} = $VMHost | Get-VMHostNetworkAdapter -Name $Vmk | select vmhost,name,mac,ip,
            @{n='pnic';
                e={
                    $pnics = @()
                    (get-virtualportgroup -vmhost $_.vmhost -Name `
                    (Get-VMHostNetworkAdapter -VMHost $_.vmhost -Name $_.name).portgroupname).extensiondata.computedpolicy.nicteaming.nicorder.activenic |
                    % {if($_){$pnics += $_}}
                    $pnics
                }
            },
            @{n='pnicmac';
                e={     
                    $pnicmacs = @()
                    $vmhost = $_.vmhost
                    $active = (get-virtualportgroup -vmhost $_.vmhost -Name `
                    (Get-VMHostNetworkAdapter -VMHost $_.vmhost -Name $_.name).portgroupname).extensiondata.computedpolicy.nicteaming.nicorder.activenic |
                    % {$pnicmacs += (Get-VMHostNetworkAdapter -VMHost $vmhost -Name $_).Mac}
                    $pnicmacs
                }
            },
            @{n='switch';
                e={
                    $active = (get-virtualportgroup -vmhost $_.vmhost -Name `
                    (Get-VMHostNetworkAdapter -VMHost $_.vmhost -Name $_.name).portgroupname).extensiondata.computedpolicy.nicteaming.nicorder.activenic
                    ((get-view ($_.vmhost).ExtensionData.ConfigManager.NetworkSystem).QueryNetworkHint($active)).ConnectedSwitchPort.DevId
                }
            },
            @{n='port';
                e={
                    $active = (get-virtualportgroup -vmhost $_.vmhost -Name `
                    (Get-VMHostNetworkAdapter -VMHost $_.vmhost -Name $_.name).portgroupname).extensiondata.computedpolicy.nicteaming.nicorder.activenic
                    ((get-view ($_.vmhost).ExtensionData.ConfigManager.NetworkSystem).QueryNetworkHint($active)).ConnectedSwitchPort.PortId
                }
            }
        

        $VmkPings = @()
        foreach ($hosty in ${Hosts&IPs})
        {  
                $VmkPing = [pscustomobject]@{
                    vmhost = $hosty.vmhost.name
                    vmk = $hosty.name
                    mac = $hosty.mac
                    ip = $hosty.IP
                    pnic = $hosty.pnic
                    pnicmac = $hosty.pnicmac
                    switch = $hosty.switch
                    port = $hosty.port
                }
            
                $sessh = New-SSHSession -ComputerName $hosty.vmhost.name -Credential $Credential -AcceptKey

                $IP | Select -Unique | %{
                    $cmd = "vmkping -I $($hosty.name) -c $Count $_ "
                    $invoke = Invoke-SSHCommand -Command $cmd -SSHSession $sessh
                    if ([string]$invoke.Output -match 'statistics'){
                        Out-default -inputobject "$($hosty.vmhost.name) $($hosty.name) ($($hosty.IP)) to $_"
                        Out-Default -InputObject "`n"
                        Out-default -inputobject $invoke.Output
                        Out-Default -InputObject "`n"
                        
                        #Get packet loss string from output
                        $VmkPingOutput = (((($invoke.Output -split "`n") | ? {$_ -match 'packets transmitted'}).Replace(', ',"`n") -split "`n")[-1] -split " ")[0]
                    } else {
                        Out-default -inputobject "$($hosty.vmhost.name) $($hosty.name) ($($hosty.IP)) to $_"
                        Out-Default -InputObject "`n"
                        Out-default -inputobject $invoke.Output
                        Out-Default -InputObject "`n"
                        $VmkPingOutput = "Unable to capture output. Probably 'sendto() failed (Host is down)'. Manual testing required."
                    }
                    $VmkPing | Add-Member -MemberType NoteProperty -Name "$_ pkt loss" -Value $VmkPingOutput
                }
                Remove-SSHSession $sessh | Out-Null
                $VmkPings += $VmkPing
        }
        $VmkPings
    } catch {throw}
}