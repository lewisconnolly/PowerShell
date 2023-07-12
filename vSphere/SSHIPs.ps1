$AuthenticatedIPs = @('10.40.10.78','10.40.110.78', '10.40.10.63', '10.40.110.63','10.39.1.78','10.40.10.94','10.40.110.94','10.40.10.59','10.40.110.59')

gvh |? power* -match on | % {
                         
    $HostFirewallSystem = Get-View $_.ExtensionData.ConfigManager.FirewallSystem
                
    $HostFirewallRulesetIpSpec = New-Object VMware.Vim.HostFirewallRulesetRulesetSpec
    $HostFirewallRulesetIpList = new-object VMware.Vim.HostFirewallRulesetIpList 
    $HostFirewallRulesetIpList.IpAddress = New-Object System.String[] ($AuthenticatedIPs.Count)

    for ($i=0;$i -lt $AuthenticatedIPs.count;$i++) {
        $HostFirewallRulesetIpList.IpAddress[$i]=$AuthenticatedIPs[$i]
    }

    $HostFirewallRulesetIpList.AllIp = $false
                   
    $HostFirewallRulesetIpSpec.AllowedHosts = $HostFirewallRulesetIpList

    <#$HostFirewallSystem.FirewallInfo.RuleSet|? key -eq 'sshServer'| % {

        if($_){
            $HostFirewallSystem.UpdateRuleset($_.key,$HostFirewallRulesetIpSpec)
        }
    }#>

    $HostFirewallSystem.UpdateRuleset('sshServer',$HostFirewallRulesetIpSpec)
    $SshService = $_ | Get-VMHostService | where Key -eq 'TSM-SSH'
                
    Restart-VMHostService -HostService $SshService -Confirm:$false
}
