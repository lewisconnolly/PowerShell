$vm = Get-VM 'alma-8-clone'
$vdPg = Get-VDPortgroup -Name 'DCB-DSw0-DPG-VLAN:200'
$ds = Get-Datastore STORE -Location DCB
$folder = Get-Folder Templates -Location DCB
$vmhost = Get-VMHost mkhost1.zhost
$rp = Get-ResourcePool |? {$_.Parent.Name -eq 'DCB-Cluster'}

$cloneSpec = New-Object VMware.Vim.VirtualMachineCloneSpec
$relocateSpec = New-Object VMware.Vim.VirtualMachineRelocateSpec

$vm.ExtensionData.Config.Hardware.Device | where{$_ -is [VMware.Vim.VirtualEthernetCard]} | %{

    $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec

    $dev.Operation = "edit"

    $dev.Device = $_

    $dev.device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo

    $dev.device.backing.port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection

    $dev.device.backing.port.switchUuid = $vdPg.VDSwitch.ExtensionData.Uuid

    $dev.device.backing.port.portgroupKey = $vdPg.ExtensionData.Config.key


    $relocateSpec.DeviceChange += $dev
}

$relocateSpec.Datastore = $ds.ExtensionData.MoRef
$relocateSpec.Folder = $folder.ExtensionData.MoRef
$relocateSpec.Pool = $rp.ExtensionData.MoRef
$relocateSpec.Host = $vmhost.ExtensionData.MoRef

$cloneSpec.Location = $relocateSpec

$vm.ExtensionData.CloneVM($folder.ExtensionData.MoRef,'alma-8-dcb-clone',$cloneSpec)