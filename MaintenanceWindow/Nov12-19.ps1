Function Enable-HotAddParallel ($VMs){

    $VMs = Get-VM $VMs
    
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $vmConfigSpec.MemoryHotAddEnabled = $true
    $vmConfigSpec.CPUHotAddEnabled = $true
    
    (Get-View $VMs).ReconfigVM($vmConfigSpec)
      
}

function Set-VmToolsUpgradePolicyParallel ($VMs, $Policy) {

    $VMs = Get-VM $VMs
    
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
    $vmConfigSpec.Tools.ToolsUpgradePolicy = $Policy
    
    (Get-View $VMs).ReconfigVM($vmConfigSpec)
}

$vms = gvm dca-txda-cf04,
dca-txda-php02,
TXD-app-bg01,
TXD-app-cf01,
TXD-app-php01,
txd-hosting-coldfusion-web01


$upCpu = gvm DCA-ANC-MSQ1,
DCA-ANC-PHP1,
dca-txda-php02,
dca-txda-wgts,
TXD-app-bg01,
TXD-app-php01,
txd-hosting-coldfusion-web01,
TXD-hosting-php-web01,
TXD-hosting-php-web02 

$upCpu | Stop-VMGuest

gvm $upCpu | Set-VM -NumCpu 4

Enable-HotAddParallel -VMs (gvm $vms)

gvm $upCpu | Start-VM

gvm $vms | New-Snapshot -Name "Pre ProdPatching $((get-date).ToString() -replace '\/','-')"

#-----

Set-VmToolsUpgradePolicyParallel -VMs (gvm dca-txda-cf04) -Policy 'upgradeAtPowerCycle'

gvm dca-txda-cf04 | Stop-VMGuest

$2cpu = gvm dca-txda-cf04

$2cpu | Set-VM -NumCpu 2

gvm dca-txda-cf04 | Start-VM

gvm dca-txda-cf04 | Stop-VMGuest

gvm dca-txda-cf04 | ? hardwareversion -ne vmx-13 | Set-VM -HardwareVersion 'vmx-13'

gvm dca-txda-cf04 | Start-VM

Set-VmToolsUpgradePolicyParallel -VMs (gvm dca-txda-cf04) -Policy 'manual'