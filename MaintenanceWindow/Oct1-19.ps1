$patchList = Import-Excel .\Oct1SaasPatching.xlsx
$patchList = $patchList | sort name -Descending


function Set-VmxScheduleUpgradeParallel ($VMs,$HardwareVersion){

    $VMs = Get-VM $VMs
    
    $spec = New-Object -TypeName VMware.Vim.VirtualMachineConfigSpec
    $spec.ScheduledHardwareUpgradeInfo = New-Object -TypeName VMware.Vim.ScheduledHardwareUpgradeInfo
    $spec.ScheduledHardwareUpgradeInfo.UpgradePolicy = 'always'
    $spec.ScheduledHardwareUpgradeInfo.VersionKey = $HardwareVersion

    (Get-View $VMs).ReconfigVM_Task($spec)
}

function Set-VmToolsUpgradePolicyParallel ($VMs, $Policy) {

    $VMs = Get-VM $VMs
    
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
    $vmConfigSpec.Tools.ToolsUpgradePolicy = $Policy
    
    (Get-View $VMs).ReconfigVM($vmConfigSpec)
}


Function Enable-HotAddParallel ($VMs){

    $VMs = Get-VM $VMs
    
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $vmConfigSpec.MemoryHotAddEnabled = $true
    $vmConfigSpec.CPUHotAddEnabled = $true
    
    (Get-View $VMs).ReconfigVM($vmConfigSpec)
      
}

$snapName = 'Pre SaaS Patching - 1st Oct 19'
$toolsPolicy = 'upgradeAtPowerCycle'
$hv = 'vmx-13'


gvm $patchList.Name | select -first ([math]::Floor($patchList.count/2)) | New-Snapshot -Name $snapName
gvm $patchList.Name | select -last ([math]::Ceiling($patchList.count/2)) | New-Snapshot -Name $snapName

Set-VmxScheduleUpgradeParallel -VMs (gvm ($patchList | ? HV -ne $hv).Name) -HardwareVersion $hv

Set-ToolsUpgradePolicy -VM (gvm ($patchList | ? ToolsPolicy -ne $toolsPolicy).Name) -Policy $toolsPolicy

gvm $patchList.Name | select -last ([math]::Ceiling($patchList.count/2)) | Stop-VMGuest
gvm $patchList.Name | select -first ([math]::Floor($patchList.count/2)) | Stop-VMGuest

while((gvm $patchList.Name).PowerState -contains 'PoweredOn'){
    "`n`nWaiting on all VMs to power off"
    sleep 3
}

gvm ($patchList | ? vNicType -ne 'Vmxnet3').Name | Get-NetworkAdapter | Set-NetworkAdapter -Type Vmxnet3

gvm ($patchList | ? ISOAttached -ne $null).Name | Get-CDDrive | Set-CDDrive -NoMedia

gvm ($patchList | ? FloppyPresent -ne $null).Name | Get-FloppyDrive | Remove-FloppyDrive

Enable-HotAddParallel -VMs (gvm ($patchList | ? HotAdd -Match $false).Name)

$patchList | ? ReclaimCPU -ne $null| %{

    $reclaim = [math]::Floor([int]$_.ReclaimCPU/2)
    if($reclaim -ne 0){
        $newCPU = (gvm $_.name | select -ExpandProperty numCPU)-$reclaim
        gvm $_.name | Set-VM -NumCpu $newCPU -Confirm:0
    }
}

$patchList | ? ReclaimMem -ne $null| %{

    $reclaim = [math]::Ceiling([int]$_.ReclaimMem/2)
    if($reclaim -ne 0){
        $newMem = (gvm $_.name | select -ExpandProperty MemoryGB)-$reclaim
        Set-VM -VM (gvm $_.name) -MemoryGB $newMem -Confirm:0
    }
}

gvm $patchList.Name | select -first ([math]::Floor($patchList.count/2)) | Start-VM
gvm $patchList.Name | select -last ([math]::Ceiling($patchList.count/2)) | Start-VM

while(((gvm $patchList.Name).guest.toolsversion | select -Unique) -ne '10.3.10'){
    "`n`nWaiting on all VMTools to update"
    sleep 3
}

Set-ToolsUpgradePolicy -VM (gvm ($patchList | ? ToolsPolicy -ne $toolsPolicy).Name) -Policy 'manual'