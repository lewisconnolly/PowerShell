<#  .Description
Function to retrieve Netports' (portgroup ports') client, uplink info, vSwitch, etc. info.  Includes things like VMKernel ports and Management uplinks.
    Author:  vNugglets.com -- Nov 2012
    .Outputs
    PSObject
#>
function Get-VNUplinkNIC {
    param(
        ## the VMHost DNS name whose VMs' uplink info to get (not VMHost object name -- so, do not use wildcards)
        [parameter(Mandatory=$true)][string]$VMHostToCheck_str,
        ## PSCredential to use for connecting to VMHost; will prompt for credentials if not passed in here
        [System.Management.Automation.PSCredential]$CredentialForVMHost_cred
    ) ## end param
 
    $strThisVMHostName = $VMHostToCheck_str
 
    ## check if VMHost name given is responsive on the network; if not, exit
    if (-not (Test-Connection -Quiet -Count 3 -ComputerName $strThisVMHostName)) {
        Write-Warning "VMHost '$strThisVMHostName' not responding on network -- not proceeding"; exit}
 
    ## set/get the credential to use for connecting to the VMHost (get if not already passed as param)
    $credToUseForVMHost = if ($CredentialForVMHost_cred) {$CredentialForVMHost_cred} else 
        {$host.ui.PromptForCredential("Need credentials to connect to VMHost", "Please enter credentials for '$strThisVMHostName'", $null, $null)}
 
    ## connect to the given VIServer (VMHost, here)
    $oVIServer = Connect-VIServer $strThisVMHostName -Credential $credToUseForVMHost
 
    ## if connecting to VMHost failed, write warning and exit
    if (-not $oVIServer) {Write-Warning "Did not connect to VMHost '$strThisVMHostName' -- not proceeding"; exit}
 
    ## array with PortID to vSwitch info, for determining vSwitch name from PortID
    ## get vSwitch ("PortsetName") and PortID info, not grouped
    $arrNetPortEntries = (Get-EsxTop -Server $strThisVMHostName -TopologyInfo NetPort).Entries
 
    ## calculated property for vSwitch name
    $hshVSwitchInfo = @{n="vSwitch"; e={$oNetportCounterValue = $_; ($arrNetPortEntries | ?{$_.PortId -eq $oNetportCounterValue.PortId}).PortsetName}}
 
    ## get the VM, uplink NIC, vSwitch, and VMHost info
    Get-EsxTop -Server $strThisVMHostName -CounterName NetPort | select @{n="VMName"; e={$_.ClientName}},TeamUplink,$hshVSwitchInfo,@{n="VMHostName"; e={$_.Server.Name}}
 
    Disconnect-VIServer $strThisVMHostName -Confirm:$false
} ## end function