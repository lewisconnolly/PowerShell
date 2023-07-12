function Set-VMToolsUpgradePolicy ($VM, $Policy) {
    
    
    if(!$Policy) {Write-Host "`nInvalid policy`n`nOptions are: 'manual' or 'upgradeAtPowerCycle'`n" -ForegroundColor -BackgroundColor Black Red; return}
    if(($Policy -ne 'manual')-and($Policy -ne 'upgradeatpowercycle')) {Write-Host "`nInvalid policy`n`nOptions are: 'manual' or 'upgradeAtPowerCycle'`n" -ForegroundColor Red -BackgroundColor Black; return}
    
    $VM | % {
        if($_ -is [string]){$curVM = gvm $_}else{$curVM = $_}
        $oldpolicy = (get-view -VIObject $curVM).Config.Tools.ToolsUpgradePolicy
        if($Policy -ne $oldpolicy) {
            $VmConfigSpec = new-object VMware.Vim.VirtualMachineConfigSpec
            $ToolsConfigInfo = New-Object VMware.Vim.ToolsConfigInfo
            $ToolsConfigInfo.ToolsUpgradePolicy = $Policy
            $VmConfigSpec.Tools = $ToolsConfigInfo
            (get-view -VIObject $curVM).ReconfigVM($VmConfigSpec) | Out-Null
        }
        $newpolicy = (get-view -VIObject $curVM).Config.Tools.ToolsUpgradePolicy

        [pscustomobject]@{
            Name=$curVM.name
            OldPolicy = $oldpolicy
            NewPolicy = $newpolicy
        }
    }
}
