function Get-ESXiiSCSiAdvancedSetting
{
    
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiHost,
        
        [ValidateNotNullOrEmpty()]
        $TargetIPs,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Setting        
    )
    Process {
        try
        {
            $ESXiHost | % {
                # host storage system .net object
                $HostStorageSystem = Get-View (Get-VMHost $_).ExtensionData.configmanager.Storagesystem

                # host hba .net object
                $HostHBA = Get-VMHostHba -VMHost $_ | ? model -eq 'iSCSI Software Adapter'

                if ($TargetIPs){
                    $Targets = @()
                    foreach ($IP in $TargetIPs){
                        $Targets += $HostHBA.ExtensionData.ConfiguredSendTarget | ? address -eq $IP
                    }
                } else {
                    $AdvParam = New-Object VMware.Vim.HostInternetScsiHbaParamValue

                    $AdvParam.Key = $Setting
                    $AdvParam.Value = $Value

                    $HostStorageSystem.UpdateInternetScsiAdvancedOptions($HostHBA,$null,$AdvParam)
                }

                $Targets | % {
                    if ($_.AdvancedOptions | ? key -eq $Setting) {
            
                        # targetset object
                        $TargetSet = New-Object VMware.Vim.HostInternetScsiHbaTargetSet 

                        # add target to target set
                        $TargetSet.SendTargets = $_

                        # advanced setting object
                        $TargetParam = New-Object VMware.Vim.HostInternetScsiHbaParamValue

                        $TargetParam.IsInherited = $IsInherited
                        $TargetParam.Key = $Setting
                        $TargetParam.Value = $Value

                        # update advanced setting
                        $HostStorageSystem.UpdateInternetScsiAdvancedOptions($HostHBA,$TargetSet,$TargetParam)
                    }
                }
            }
        }
        catch {throw}
    }
}
