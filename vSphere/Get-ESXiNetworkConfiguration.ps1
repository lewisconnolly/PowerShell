<#
.Synopsis
   Gets configurable network settings and values for VMHosts
.DESCRIPTION
   Configuration includes ESXi and iDRAC
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-ESXiNetworkConfiguration
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        $VMHost
    )

    Process
    {
        $VMHost | % {

            $curVMHost = $_
            
            $netConfig = [pscustomobject]@{
                Name = $curVMHost.Name
            }

            $netSys = Get-View $curVMHost.extensiondata.configmanager.networksystem
            $esxcli = Get-EsxCli -VMHost $curVMHost -V2

            Write-Host "`n`nGathering network info for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $netSys.NetworkInfo | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name 'NetworkInfo_Hostname' -Value $_.DnsConfig.Hostname
                $netConfig | Add-Member -MemberType NoteProperty -Name 'NetworkInfo_DNSServers' -Value ($_.DnsConfig.Address -join ', ')
                $netConfig | Add-Member -MemberType NoteProperty -Name 'NetworkInfo_DomainName' -Value $_.DnsConfig.DomainName
                $netConfig | Add-Member -MemberType NoteProperty -Name 'NetworkInfo_SearchDomain' -Value ($_.DnsConfig.SearchDomain -join ', ')
            }
            
            Write-Host "`n`nGathering capabilities for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $netSys.Capabilities | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_CanSetPhysicalNicLinkSpeed' -Value $_.CanSetPhysicalNicLinkSpeed
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_SupportsNicTeaming' -Value $_.SupportsNicTeaming
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_SupportsVlan' -Value $_.SupportsVlan
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_UsesServiceConsoleNic' -Value $_.UsesServiceConsoleNic
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_VswitchConfigSupported' -Value $_.VswitchConfigSupported
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_VnicConfigSupported' -Value $_.VnicConfigSupported
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_IpRouteConfigSupported' -Value $_.IpRouteConfigSupported
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_DnsConfigSupported' -Value $_.DnsConfigSupported
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_DhcpOnVnicSupported' -Value $_.DhcpOnVnicSupported
                $netConfig | Add-Member -MemberType NoteProperty -Name 'Capabilities_IpV6Supported' -Value $_.IpV6Supported
            }

            Write-Host "`n`nGathering offload capabilities for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $netSys.OffloadCapabilities | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name 'OffloadCapabilities_CsumOffload' -Value $_.CsumOffload
                $netConfig | Add-Member -MemberType NoteProperty -Name 'OffloadCapabilities_TcpSegmentation' -Value $_.TcpSegmentation
                $netConfig | Add-Member -MemberType NoteProperty -Name 'OffloadCapabilities_ZeroCopyXmit' -Value $_.ZeroCopyXmit
            }

            $vmnics = $curVMHost | Get-VMHostNetworkAdapter -Physical | ? name -ne 'vusb0'

            Write-Host "`n`nGathering vmnic properties for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $vmnics | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_Name" -Value $_.Name
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_MAC" -Value $_.Mac
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_FullDuplex" -Value $_.FullDuplex
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_WakeOnLanSupported" -Value $_.WakeOnLanSupported
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_DhcpEnabled" -Value $_.DhcpEnabled
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_Driver" -Value $_.ExtensionData.driver
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_LinkSpeed" -Value $_.ExtensionData.LinkSpeed.SpeedMb
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_AutoNegotiateSupported" -Value $_.ExtensionData.AutoNegotiateSupported
                
                if(($_.ExtensionData.Spec.EnableEnhancedNetworkingStack -eq $null)-or($_.ExtensionData.Spec.EnableEnhancedNetworkingStack -eq ''))
                {$EENS = 'NotSet'}else{$EENS = $_.ExtensionData.Spec.EnableEnhancedNetworkingStack}
                
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_EnableEnhancedNetworkingStack" -Value $EENS
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_ResourcePoolSchedulerAllowed" -Value $_.ExtensionData.ResourcePoolSchedulerAllowed
                
                if(($_.ExtensionData.ResourcePoolSchedulerDisallowedReason -eq $null)-or($_.ExtensionData.ResourcePoolSchedulerDisallowedReason -eq '')){$RPSDR = 'NotSet'}
                else{$RPSDR = $_.ExtensionData.ResourcePoolSchedulerDisallowedReason}
                
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_ResourcePoolSchedulerDisallowedReason" -Value $RPSDR

                $vmnic = $_.Name

                $argums = $esxcli.network.nic.get.CreateArgs()
                $argums.nicname = $vmnic
                $nicInfo = $esxcli.network.nic.get.Invoke($argums)

                $nicInfo | gm | ? membertype -eq codeproperty | ? Name -notmatch 'VirtualAddress|Name|PHYAddress' | % {
                    $prop = $_.Name
                    if($prop -eq 'DriverInfo')
                    {
                        $DI = $nicInfo.$prop
                        $DI | gm |? membertype -eq codeproperty | ? name -ne 'Driver' | % {
                            $prop = $_.Name
                            $netConfig | Add-Member -MemberType NoteProperty -Name "$($vmnic)_Driver_$prop" -Value $DI.$prop
                        }
                    }
                    else
                    {
                        $netConfig | Add-Member -MemberType NoteProperty -Name "$($vmnic)_$prop" -Value $nicInfo.$prop
                    }
                }
                
                $argums = $esxcli.system.module.parameters.list.CreateArgs()
                $argums.module = $_.ExtensionData.driver
                $driverParams = $esxcli.system.module.parameters.list.Invoke($argums)

                $driverParams | ? value -ne '' | % {

                    $netConfig | Add-Member -MemberType NoteProperty -Name "$($vmnic)_DriverParams_$($_.Name)" -Value $_.Value
                }

                $CDP = $netSys.QueryNetworkHint($_.Name).ConnectedSwitchPort

                $CDP | gm | ? membertype -eq property | % {
                    
                    $prop = $_.Name
                    if($prop -eq 'DeviceCapability')
                    {
                        $DC = $CDP.$prop
                        $DC | gm |? membertype -eq property | % {
                            $prop = $_.Name
                            if(($DC.$prop -eq $null)-or($DC.$prop -eq '')){$val = 'NotSet'}else{$val = $DC.$prop}
                            $netConfig | Add-Member -MemberType NoteProperty -Name "$($vmnic)_CDP_$prop" -Value $val
                        }
                    }
                    else
                    {
                        if(($CDP.$prop -eq $null)-or($CDP.$prop -eq '')){$val = 'NotSet'}else{$val = $CDP.$prop}                        
                        $netConfig | Add-Member -MemberType NoteProperty -Name "$($vmnic)_CDP_$prop" -Value $val
                    }
                }
            }

            $vmks = $curVMHost | Get-VMHostNetworkAdapter -VMKernel

            Write-Host "`n`nGathering vmk properties for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $vmks | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_Name" -Value $_.Name
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_MAC" -Value $_.Mac
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_DhcpEnabled" -Value $_.DhcpEnabled
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_IP" -Value $_.IP
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_SubnetMask" -Value $_.SubnetMask
                
                if(($_.ExtensionData.spec.IpRouteSpec.IpRouteConfig.DefaultGateway -eq $null)-or($_.ExtensionData.spec.IpRouteSpec.IpRouteConfig.DefaultGateway -eq ''))
                {$DG = (Get-VMHostNetwork -VMHost $curVMHost).VMKernelGateway}
                else{$DG = $_.ExtensionData.spec.IpRouteSpec.IpRouteConfig.DefaultGateway}
                
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_DefaultGateway" -Value $DG
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_PortGroup" -Value $_.PortGroupName
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_MTU" -Value $_.Mtu
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_vMotionEnabled" -Value $_.vMotionEnabled
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_FaultToleranceLoggingEnabled" -Value $_.FaultToleranceLoggingEnabled
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_ManagementTrafficEnabled" -Value $_.ManagementTrafficEnabled
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_VsanTrafficEnabled" -Value $_.VsanTrafficEnabled
                
                if(($_.IPv6Enabled -eq $null)-OR($_.IPv6Enabled -eq '')){$IP6 = $false}else{$IP6 = $_.IPv6Enabled}

                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_IPv6Enabled" -Value $IP6
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_TsoEnabled" -Value $_.ExtensionData.spec.TsoEnabled
                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_NetStackInstanceKey" -Value $_.ExtensionData.spec.NetStackInstanceKey
                
                if(($_.ExtensionData.spec.OpaqueNetwork -eq $null)-or($_.ExtensionData.spec.OpaqueNetwork -eq '')){$ON = $False}else{$ON = $_.ExtensionData.spec.OpaqueNetwork}

                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_OpaqueNetwork" -Value $ON

                if(($_.ExtensionData.spec.PinnedPnic -eq $null)-or($_.ExtensionData.spec.PinnedPnic -eq '')){$PP = $False}else{$PP = $_.ExtensionData.spec.PinnedPnic}

                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_PinnedPnic" -Value $PP

                if(($_.ExtensionData.spec.ExternalId -eq $null)-or($_.ExtensionData.spec.ExternalId -eq '')){$EI = $False}else{$EI = $_.ExtensionData.spec.ExternalId}

                $netConfig | Add-Member -MemberType NoteProperty -Name "$($_.Name)_ExternalId" -Value $EI
            }

            $virtualSwitches = $curVMHost | Get-VirtualSwitch -Standard

            Write-Host "`n`nGathering vSwitch properties for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $virtualSwitches | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdvSwitch_$($_.Name)_Name" -Value $_.Name
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdvSwitch_$($_.Name)_MTU" -Value $_.Mtu
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdvSwitch_$($_.Name)_NICs" -Value ($_.Nic -join ', ')
            }

            $stdPortGroups = $curVMHost | Get-VirtualPortGroup -Standard

            Write-Host "`n`nGathering portgroup properties for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta
            
            $stdPortGroups | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_Name" -Value $_.Name
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_VirtualSwitchName" -Value $_.VirtualSwitch
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_VLANID" -Value $_.VlanId
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_Sec_AllowPromiscuous" -Value $_.ExtensionData.ComputedPolicy.Security.AllowPromiscuous
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_Sec_AllowOSMACChangesForInbound" -Value $_.ExtensionData.ComputedPolicy.Security.MacChanges
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_Sec_AllowOSMACChangesForOutbound" -Value $_.ExtensionData.ComputedPolicy.Security.ForgedTransmits
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_Team_Policy" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.Policy
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_Team_Failback" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.ReversePolicy
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_Team_NotifySwitchesOnvNICAddorPhysicalFailover" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.NotifySwitches
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_Team_RollingOrder" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.RollingOrder
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_FailureCriteria_CheckSpeed" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.CheckSpeed
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_FailureCriteria_Speed" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.Speed
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_FailureCriteria_CheckDuplex" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.CheckDuplex
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_FailureCriteria_FullDuplex" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.FullDuplex
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_FailureCriteria_CheckErrorPercent" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.CheckErrorPercent
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_FailureCriteria_Percentage" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.Percentage
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_FailureCriteria_CheckBeacon" -Value $_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.CheckBeacon
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_NicOrder_ActiveNic" -Value ($_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.ActiveNic  -join ', ')
                $netConfig | Add-Member -MemberType NoteProperty -Name "StdPG_$($_.Name)_NicOrder_StandbyNic" -Value ($_.ExtensionData.ComputedPolicy.NicTeaming.FailureCriteria.StandbyNic  -join ', ')
            }

            $VDSwitches = $curVMHost | Get-VDSwitch

            Write-Host "`n`nGathering VDSwitch properties for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $VDSwitches | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_Name" -Value $_.Name
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_Version" -Value $_.Version
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_MTU" -Value $_.Mtu
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_NICs" -Value ($_.ExtensionData.config.UplinkPortPolicy.UplinkPortName -join ', ')
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_NumUplinkPorts" -Value $_.NumUplinkPorts
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_LinkDiscoveryProtocol" -Value $_.LinkDiscoveryProtocol
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_LinkDiscoveryProtocolMode" -Value $_.LinkDiscoveryProtocolOperation
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_LACPAPIVersion" -Value $_.ExtensionData.Config.LacpApiVersion
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_MulticastFilteringMode" -Value $_.ExtensionData.Config.MulticastFilteringMode
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_MaxPorts" -Value $_.ExtensionData.Config.MaxPorts
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_NetworkResourceManagementEnabled" -Value $_.ExtensionData.Config.NetworkResourceManagementEnabled
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_NetworkResourceControlVersion" -Value $_.ExtensionData.Config.NetworkResourceControlVersion
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_DefaultProxySwitchMaxNumPorts" -Value $_.ExtensionData.Config.DefaultProxySwitchMaxNumPorts
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDvSwitch_$($_.Name)_PnicCapacityRatioForReservation" -Value $_.ExtensionData.Config.PnicCapacityRatioForReservation
            }

            $VDPortGroups = $curVMHost | Get-VDSwitch | Get-VDPortgroup

            Write-Host "`n`nGathering VDPortgroup properties for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $VDPortGroups | % {
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Name" -Value $_.Name
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_VirtualSwitchName" -Value $_.VDSwitch.Name
                   
                if($_.VlanConfiguration.VlanType -eq 'Vlan'){$VLAN = $_.VlanConfiguration.VlanID}
                elseif($_.VlanConfiguration.VlanType -eq 'Trunk'){$VLAN = $_.VlanConfiguration.Ranges -join ', '}
                else{$VLAN = 'Untagged'}
                   
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_VLANID" -Value $VLAN
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_PortBinding" -Value $_.PortBinding
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_NumPorts" -Value $_.NumPorts
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_IsUplink" -Value $_.IsUplink
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_PortAllocation" -Value $_.ExtensionData.Config.AutoExpand
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_NetFlowEnabled" -Value $_.ExtensionData.Config.DefaultPortConfig.IpfixEnabled.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Blocked" -Value $_.ExtensionData.Config.DefaultPortConfig.Blocked.Value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_VmDirectPathGen2Allowed" -Value $_.ExtensionData.Config.DefaultPortConfig.VmDirectPathGen2Allowed.value
                
                if(($_.ExtensionData.Config.DefaultPortConfig.FilterPolicy.FilterConfig -eq $null)-or($_.ExtensionData.Config.DefaultPortConfig.FilterPolicy.FilterConfig -eq ''))
                {$FC = 'NotSet'}else{$FC = $_.ExtensionData.Config.DefaultPortConfig.FilterPolicy.FilterConfig}                

                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_FilterConfig" -Value $FC

                $policy = $_.ExtensionData.Config.Policy
                $PGName = $_.Name

                $policy | gm | ? membertype -eq property| % {

                    $prop = $_.Name
                    $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($PGName)_GlobalPolicy_$prop" -Value $policy.$prop
                }

                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Sec_AllowPromiscuous" -Value $_.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.AllowPromiscuous.Value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Sec_AllowOSMACChangesForInbound" -Value $_.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.MacChanges.Value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Sec_AllowOSMACChangesForOutbound" -Value $_.ExtensionData.Config.DefaultPortConfig.SecurityPolicy.ForgedTransmits.Value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Team_Policy" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.Policy.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Team_Failback" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.ReversePolicy.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Team_NotifySwitchesOnvNICAddorPhysicalFailover" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.NotifySwitches.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_Team_RollingOrder" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.RollingOrder.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_FailureCriteria_CheckSpeed" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.FailureCriteria.CheckSpeed.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_FailureCriteria_Speed" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.FailureCriteria.Speed.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_FailureCriteria_CheckDuplex" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.FailureCriteria.CheckDuplex.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_FailureCriteria_FullDuplex" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.FailureCriteria.FullDuplex.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_FailureCriteria_CheckErrorPercent" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.FailureCriteria.CheckErrorPercent.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_FailureCriteria_Percentage" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.FailureCriteria.Percentage.value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_FailureCriteria_CheckBeacon" -Value $_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.FailureCriteria.CheckBeacon.value
                
                if($_.IsUplink -eq $true){$AN = 'N/A'}else{$AN = ($_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.UplinkPortOrder.ActiveUplinkPort -join ', ')}
                
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_NicOrder_ActiveNic" -Value $AN
                
                if($_.IsUplink -eq $true){$SN = 'N/A'}else{$SN = ($_.ExtensionData.Config.DefaultPortConfig.UplinkTeamingPolicy.UplinkPortOrder.StandbyUplinkPort -join ', ')}

                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_NicOrder_StandbyNic" -Value $SN
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_LACP_Enabled" -Value $_.ExtensionData.Config.DefaultPortConfig.LacpPolicy.Enable.Value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_LACP_Mode" -Value $_.ExtensionData.Config.DefaultPortConfig.LacpPolicy.Mode.Value
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_MACLearningPolicy_Enabled" -Value $_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.Enabled
                
                if(($_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.AllowUnicastFlooding -eq $null)-or($_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.AllowUnicastFlooding -eq ''))
                {$AUF = 'NotSet'}else{$AUF = $_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.AllowUnicastFlooding}
                
                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_MACLearningPolicy_AllowUnicastFlooding" -Value $AUF

                if(($_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.Limit -eq $null)-or($_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.Limit -eq ''))
                {$L = 'NotSet'}else{$L = $_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.Limit}

                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_MACLearningPolicy_Limit" -Value $L

                if(($_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.LimitPolicy -eq $null)-or($_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.LimitPolicy -eq '')){$LP = 'NotSet'}else{$LP = $_.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.LimitPolicy}

                $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($_.Name)_MACLearningPolicy_LimitPolicy" -Value $LP

                $inShaping = $_.ExtensionData.Config.DefaultPortConfig.InShapingPolicy
                
                $inShaping | gm | ? membertype -eq property| ? name -ne inherited | % {

                    $prop = $_.Name
                    $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($PGName)_InShapingPolicy_$prop" -Value $inShaping.$prop.value
                }

                
                $outShaping = $_.ExtensionData.Config.DefaultPortConfig.OutShapingPolicy

                $outShaping | gm | ? membertype -eq property| ? name -ne inherited | % {

                    $prop = $_.Name
                    $netConfig | Add-Member -MemberType NoteProperty -Name "VDPG_$($PGName)_OutShapingPolicy_$prop" -Value $outShaping.$prop.value
                }
            }
                
            $HBA = $curVMHost | Get-VMHostHba | ? Status -eq online

            Write-Host "`n`nGathering iSCSI properties for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_IQN" -Value $HBA.IScsiName
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Device" -Value $HBA.Device
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Driver" -Value $HBA.Driver
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_IsSoftwareBased" -Value $HBA.IsSoftwareBased
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_NetworkBindingSupport" -Value $HBA.ExtensionData.NetworkBindingSupport
            
            $disco = $HBA.ExtensionData.DiscoveryProperties

            $disco | gm | ? membertype -eq property| % {

                $prop = $_.Name

                if(($disco.$prop -eq $null)-or($disco.$prop -eq '')){$val = 'NotSet'}else{$val = $disco.$prop}

                $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Discovery_$prop" -Value $val
            }
            
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Digest_HeaderDigestType" -Value $HBA.ExtensionData.DigestProperties.HeaderDigestType
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Digest_DataDigestType" -Value $HBA.ExtensionData.DigestProperties.DataDigestType
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Authentication_ChapType" -Value $HBA.AuthenticationProperties.ChapType
            
            if(($HBA.AuthenticationProperties.ChapName -eq $null)-or($HBA.AuthenticationProperties.ChapName -eq '')){$CN = 'NotSet'}else{$CN = $HBA.AuthenticationProperties.ChapName}

            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Authentication_ChapName" -Value $CN
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Authentication_MutualChapEnabled" -Value $HBA.AuthenticationProperties.MutualChapEnabled
            
            if(($HBA.AuthenticationProperties.MutualChapName -eq $null)-or($HBA.AuthenticationProperties.MutualChapName -eq '')){$MCN = 'NotSet'}else{$MCN = $HBA.AuthenticationProperties.MutualChapName}
            
            $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_Authentication_MutualChapName" -Value $MCN

            $advParams = $HBA.ExtensionData.AdvancedOptions

            $advParams | % {

                $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_AdvancedOpts_$($_.Key)" -Value $_.Value
            }

            $sendTargets = $HBA.ExtensionData.ConfiguredSendTarget

            $sendTargets | % {
                $curTarg = "$($_.address):$($_.port)"
                $advParams = $_.AdvancedOptions | ? IsInherited -eq $false
                $advParams | % {
                    $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_$($curTarg)_$($_.Key)" -Value $_.Value
                }
            }
            #esxcli iscsi networkportal list
            $argums = $esxcli.iscsi.networkportal.list.CreateArgs()
            $argums.adapter = $HBA.Name
            $iSCSIPortBinding = $esxcli.iscsi.networkportal.list.Invoke($argums)
            
            if($iSCSIPortBinding[0].PortGroupKey.Length -eq 2)
            {
                $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_PortBinding" -Value ($iSCSIPortBinding.portgroup-join ', ')                
            }
            else
            {
                $netConfig | Add-Member -MemberType NoteProperty -Name "iSCSI_PortBinding" -Value (($iSCSIPortBinding.portgroupkey | % {Get-VDPortgroup |? key -eq $_}).name -join ', ')
            }

            $iDRAC = "$($curVMHost.Name -replace '\.zhost', '-idrac').zhost"
            
            Write-Host "`n`nGathering iDRAC properties for " -ForegroundColor Green -NoNewline
            Write-Host $curVMHost.name -ForegroundColor Magenta

            $iDRACIOAT = racadm -r $iDRAC -u root -p zh0st1ng get bios.integrateddevices.IoatEngine
            $iDRACSRVIO = racadm -r $iDRAC -u root -p zh0st1ng get bios.integrateddevices.SriovGlobalEnable
            
            $iDRACIOAT, $iDRACSRVIO | % {

                [regex]$ptn = '\w+=\w+'
                $keyValue = $ptn.Matches($_).Value[-1] -split '='
                $key = $keyValue[0]
                $value = $keyValue[-1]
                
                $netConfig | Add-Member -MemberType NoteProperty -Name "iDRAC_$key" -Value $value
            }

            $netConfig
        }
    }
}

$VD = gvh zhost1.zhost,zhost2.zhost,zhost3.zhost,zhost4.zhost,zhost10.zhost
$DCAzhostNetConfVD = Get-ESXiNetworkConfiguration -VMHost $VD
$DCAzhostNetConfVD | Export-Excel -Path C:\Users\Lewisc\Desktop\DCAzhostNetConf.xlsx -WorksheetName 'DCAzhostNetConfVD'

$Std = gvh -Location DCA | ? {$_ -NotIn $VD}
$DCAzhostNetConfStd = Get-ESXiNetworkConfiguration -VMHost $Std
$DCAzhostNetConfStd | Export-Excel -Path C:\Users\Lewisc\Desktop\DCAzhostNetConf.xlsx -WorksheetName 'DCAzhostNetConfStd' -Append 