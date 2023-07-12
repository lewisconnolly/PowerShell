
#Requires -Modules 'VMware.VimAutomation.Core'

<#
.SYNOPSIS
    Get VM network adapter IP addresses.
.DESCRIPTION
    Get VM network adapter IPv4 addresses by VM, VM name or network adapter.
.PARAMETER VM
    Specify VMs by object to check network adapters of.
.PARAMETER VMName
    Specify names or name filters by string for VMs to check network adapters of.
.PARAMETER NetworkAdapter
    Specify network adapters to check by object.
.PARAMETER NetworkAdapterName
    Specify names or name filters by string for network adapters to check.
.OUTPUTS
    $null or PSCustomObject objects.
.EXAMPLE    
    #
    # Get IPs by VM
    
    Get-VM lc-test1, lc-test3 | Get-VMNetworkAdapterIP
    
    # or

    Get-VMNetworkAdapterIP -VM (Get-VM lc-test1, lc-test3)

    # or

    Get-VMNetworkAdapterIP (Get-VM lc-test1, lc-test3)
.EXAMPLE
    #
    # Get IPs by adapter
    
    Get-VM lc-test1, lc-test3 | Get-NetworkAdapter | Get-VMNetworkAdapterIP

    # or

    Get-VMNetworkAdapterIP -NetworkAdapter (Get-VM lc-test1, lc-test3 | Get-NetworkAdapter)
.EXAMPLE
    #
    # Get IPs by VM name    

    Get-VMNetworkAdapterIP -VmName 'lc-test1', 'lc-test3'

    # or 

    Get-VMNetworkAdapterIP -VmName 'lc-test[13]'

    # or

    Get-VMNetworkAdapterIP 'lc-test[13]'
.EXAMPLE
    #
    # Filter network adapters to return

    Get-VMNetworkAdapterIP -NetworkAdapterName 'Network adapter 1'

    # or for specific VMs

    Get-VM lc-test1, lc-test3 | Get-VMNetworkAdapterIP -NetworkAdapterName 'Network adapter 1'

    # or 

    Get-VMNetworkAdapterIP -VmName 'lc-test1', 'lc-test3' -NetworkAdapterName 'Network adapter 1'
.EXAMPLE
    #
    # Get IPs for all network adapters
    
    Get-VMNetworkAdapterIP
.NOTES
    VM must be powered on to get IPs.

    Module dependencies:

    Name                               TestedVersion
    ----                               -------   
    VMware.VimAutomation.Core          12.0.0.15939655
#>
function Get-VMNetworkAdapterIP {
    [CmdletBinding(DefaultParameterSetName='VM')]
    [Alias()]    
    [OutputType([PSCustomObject[]])]
    Param (                                                  
        [Parameter(Position=0, ValueFromPipeline=$true, ParameterSetName='VM')]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]
        $VM,  
        
        [Parameter(Position=0, ParameterSetName='VmName')]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $VMName,
        
        [Parameter(ValueFromPipeline=$true, ParameterSetName='Adapter')]        
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.Types.NetworkAdapter[]]
        $NetworkAdapter,

        [Parameter(ParameterSetName='VmName')]
        [Parameter(ParameterSetName='VM')]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $NetworkAdapterName
    )
    
    Begin {       
        try{            

            # Check a vCenter is connected

            if(!$global:DefaultVIServer){
                "$( (Get-Date).ToString() ) No connected VIServers" | Write-Warning

                while($confirm -notin @('y','n')){
                    $confirm = Read-Host -Prompt "`nAttempt to connect to vcenter.zonalconnect.local? [y/n]`n" `
                    "" | Write-Host
                    # Warn on invalid input
                
                    if(!$confirm -or ($confirm -notin @('y','n'))){ "Invalid input, enter y or n" | Write-Warning } 
                }

                if($confirm -eq 'n'){
                    "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host
                    $exit = $true
                    return
                } else {
                    "`n$( (Get-Date).ToString() ) Connecting to vcenter.zonalconnect.local ...`n" | Write-Host
                    Connect-VIServer vcenter.zonalconnect.local | Out-Null
                }
            }
            
            # Build parameters for filtering network adapters
            
            $splat = @{}

            # Filter on name if included

            if($NetworkAdapterName){ $splat += @{Name = $NetworkAdapterName} }

        } catch { $Error[0] | Write-Error } finally {}
    }
    
    Process {                    
        try {
            if($exit){ return }

            # If getting IPs by VM, check each VM is powered on and get IPs for each adapter returned by filter

            if($VM){
                foreach ($vim in $VM){
                    if($vim.PowerState -eq 'PoweredOn'){
                        if($vim | Get-NetworkAdapter){
                            $vim | Get-NetworkAdapter @splat | % {
                                $_ | select @{n='VM';e={$_.Parent}},Name,Type,NetworkName,MacAddress,
                                @{n='IpAddress';e={
                                    $nicName = $_.Name
                                    $_.Parent.Guest.Nics | ? {$_.Device.Name -eq $nicName} | select -ExpandProperty IPAddress |
                                    ? {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'} | select -Last 1
                                }}
                            }
                        } else { "$( (Get-Date).ToString() ) $( $vim.Name ) has no network adapters`n" | Write-Warning }
                    } else { "$( (Get-Date).ToString() ) $( $vim.Name ) is not powered on. Unable to get IP(s) of its network adapter(s)`n" | Write-Warning }                    
                }

            # If getting IPs by name or adapters, for each network adapter check its parent VM is powered on and get IP

            } elseif($VmName){
                foreach ($nm in $VmName){
                    $vim = Get-VM -Name $nm
                    if($vim){
                        $vim | % {
                            if($_.PowerState -eq 'PoweredOn'){
                                if($_ | Get-NetworkAdapter){
                                    $_ | Get-NetworkAdapter @splat | % {
                                        $_ | select @{n='VM';e={$_.Parent}},Name,Type,NetworkName,MacAddress,
                                        @{n='IpAddress';e={
                                            $nicName = $_.Name
                                            $_.Parent.Guest.Nics | ? {$_.Device.Name -eq $nicName} | select -ExpandProperty IPAddress |
                                            ? {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'} | select -Last 1
                                        }}
                                    }
                                } else { "$( (Get-Date).ToString() ) $( $_.Name ) has no network adapters`n" | Write-Warning }
                            } else { "$( (Get-Date).ToString() ) $( $_.Name ) is not powered on. Unable to get IP(s) of its network adapter(s)`n" | Write-Warning }
                        }
                    } else { "$( (Get-Date).ToString() ) Unable to get VM from name: $nm`n" | Write-Warning }
                }
            } elseif($NetworkAdapter){
                foreach ($nic in $NetworkAdapter){                    
                    if($nic.Parent.PowerState -eq 'PoweredOn'){
                        $nic | select @{n='VM';e={$_.Parent}},Name,Type,NetworkName,MacAddress,
                        @{n='IpAddress';e={
                            $nicName = $_.Name
                            $_.Parent.Guest.Nics | ? {$_.Device.Name -eq $nicName} | select -ExpandProperty IPAddress |
                            ? {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'} | select -Last 1
                        }}
                    } else { "$( (Get-Date).ToString() ) $( $nic.Parent.Name ) is not powered on. Unable to get IP(s) of its network adapter(s)`n" | Write-Warning }
                }

            # If no network adapters or VMs passed in, get IPs of all network adapters with powered on VMs returned by filter (@splat)

            } else {
                Get-VM | Get-NetworkAdapter @splat | % {
                    if($_.Parent.PowerState -eq 'PoweredOn'){
                        $_ | select @{n='VM';e={$_.Parent}},Name,Type,NetworkName,MacAddress,
                        @{n='IpAddress';e={
                            $nicName = $_.Name
                            $_.Parent.Guest.Nics | ? {$_.Device.Name -eq $nicName} | select -ExpandProperty IPAddress |
                            ? {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'} | select -Last 1                              
                        }}
                    } else { "$( (Get-Date).ToString() ) $( $_.Parent.Name ) is not powered on. Unable to get IP(s) of its network adapter(s)`n" | Write-Warning }
                }
            }            
        } catch { $Error[0] | Write-Error } finally {}                
    }
}