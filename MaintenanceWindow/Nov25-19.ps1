# Zabbix
# Host monitoring
# Toggle alarms
Set-VIAlarmActions -Entity (get-datacenter DCA) -Enabled $false
Set-VIAlarmActions -Entity (Get-VDSwitch DCA*0) -Enabled $false
Set-VIAlarmActions -Entity (Get-VMHost -Location DCA) -Enabled $false
Set-VIAlarmActions -Entity (Get-Cluster DCA*) -Enabled $false

<#
1. Move A2 cable from 5000s to newly config'd port on A1

2. Test access to MAB DMZ and NASes

2.1 If fail, move cable back then stop

3. Set all port groups to use vmnic0 only

3.1 Clear MAC table on A2

4. Upgrade A2

5. Test VM connectivity moving from A2 to A1

5.1 If success, set host nics active/active

5.2 If fail, leave host nics active/standby
#>


# 2.
ping DCAMABPRDSUP01
ping dca-utl-nas

# 3.
Get-VDPortgroup DCA* |? name -NotMatch "dvuplink|iscsi|proxy|VirtualLab|'" |
Get-VDUplinkTeamingPolicy |
Set-VDUplinkTeamingPolicy -StandbyUplinkPort Dvmnic1 -ActiveUplinkPort Dvmnic0 -Confirm:0 -ErrorAction Ignore

Get-VMHost | Get-VirtualSwitch -Standard -Name *0 | Get-VirtualPortGroup |
Get-NicTeamingPolicy | 
Set-NicTeamingPolicy -MakeNicStandby vmnic1 -MakeNicActive vmnic0 -Confirm:0 -ErrorAction Ignore

# 4.
gvm lc-test3 | Get-NetworkAdapter | ft -au
gvm lc-test3 | Open-VMConsoleWindow
Move-VM -VM lc-test3 -Destination (gvh zhost6*) -PortGroup (Get-VDPortgroup "DCA*89'")

# 5.1
Get-VDPortgroup DCA* |? name -NotMatch "dvuplink|iscsi|proxy|VirtualLab|'" |
Get-VDUplinkTeamingPolicy |
Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1,Dvmnic0

Get-VMHost | Get-VirtualSwitch -Standard -Name *0 | Get-VirtualPortGroup |
Get-NicTeamingPolicy | 
Set-NicTeamingPolicy -MakeNicActive vmnic1,vmnic0

# DRS?
Get-Cluster DCA* | Set-Cluster -DrsMode PartiallyAutomated


# Toggle alarms
Set-VIAlarmActions -Entity (get-datacenter DCA) -Enabled $true
Set-VIAlarmActions -Entity (Get-VDSwitch DCA*0) -Enabled $true
Set-VIAlarmActions -Entity (Get-VMHost -Location DCA) -Enabled $true
Set-VIAlarmActions -Entity (Get-Cluster DCA*) -Enabled $true
