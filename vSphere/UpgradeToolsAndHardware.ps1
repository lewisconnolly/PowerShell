
# 1) Load both functions into your session (paste in console)

function Set-VmToolsUpgradePolicy ($VMs, $Policy) {

    $VMs = Get-VM $VMs
    
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
    $vmConfigSpec.Tools.ToolsUpgradePolicy = $Policy
    
    (Get-View $VMs).ReconfigVM($vmConfigSpec)
}

function Set-VmxScheduleUpgrade ($VMs,$Policy){

    $VMs = Get-VM $VMs
    
    $spec = New-Object -TypeName VMware.Vim.VirtualMachineConfigSpec
    $spec.ScheduledHardwareUpgradeInfo = New-Object -TypeName VMware.Vim.ScheduledHardwareUpgradeInfo
    $spec.ScheduledHardwareUpgradeInfo.UpgradePolicy = $Policy
    $spec.ScheduledHardwareUpgradeInfo.VersionKey = 'vmx-15'

    (Get-View $VMs).ReconfigVM_Task($spec)
}


# 2) Copy your VMs to csv and save in your current directory then import
$myVMsToPatch = Get-VM (Import-Csv .\myVMsToPatch.csv).Name
# 3) Set VM tools policy to update
$upgradeTools = $myVMsToPatch | ? {$_.ExtensionData.Guest.ToolsVersionStatus -ne "guestToolsCurrent"}
Set-VMToolsUpgradePolicy -VMs $upgradeTools -Policy 'upgradeAtPowerCycle'
# 4) Power off VMs to be updated
Get-VM $upgradeTools | ? PowerState -eq 'PoweredOn' | Stop-VMGuest

while(((Get-VM $upgradeTools).PowerState | select -Unique) -ne 'PoweredOff'){
    "Waiting for VMs to power off..." | Write-Host
    sleep 3
}
# 5) Check VMs are powered off
Get-VM $upgradeTools | select Name, PowerState
# 6) Start VMs
Get-VM $upgradeTools | Start-VM

while (((Get-VM $upgradeTools).ExtensionData.Guest.ToolsVersionStatus | select -Unique) -ne 'guestToolsCurrent'){
    "Waiting for VM tools to update..." | Write-Host
    sleep 3
}
# 7) Check tools have been updated
Get-VM $myVMsToPatch | select Name, PowerState, @{n='ToolsVersionStatus';e={$_.ExtensionData.Guest.ToolsVersionStatus}}
# 8) Set policy back to manual
Set-VMToolsUpgradePolicy -VMs (Get-VM $upgradeTools) -Policy 'manual'


# 9) Set hardware version policy to update 
$upgradeHV = (Get-VM $myVMsToPatch | ? HardwareVersion -ne 'vmx-15')
Set-VmxScheduleUpgrade -VMs $upgradeHV -Policy 'always'
# 10) Power off VMs to be updated
Get-VM $upgradeHV | ? PowerState -eq 'PoweredOn' | Stop-VMGuest

while(((Get-VM $upgradeHV).PowerState | select -Unique) -ne 'PoweredOff'){
    "Waiting for VMs to power off..." | Write-Host
    sleep 3
}
# 11) Check VMs are powered off
Get-VM $upgradeHV | select Name, PowerState
# 12) Start VMs
Get-VM $upgradeHV | Start-VM
# 13) Wait for hardware version to update
while (((Get-VM $upgradeHV).HardwareVersion | select -Unique) -ne 'vmx-15'){
    "Waiting for VM hardware version to update..." | Write-Host
    sleep 3
}
# 14) Check all VMs are on vmx-15
Get-VM $myVMsToPatch | select Name, PowerState, HardwareVersion
# 15) Set policy to manual update
Set-VmxScheduleUpgrade -VMs (Get-VM $upgradeHV) -Policy 'never'
