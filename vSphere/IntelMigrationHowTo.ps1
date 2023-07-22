
# NB: Don't upgrade VMTools and hardware version without power cycling in between and if doing both upgrade VMTools first

# 1) Set $path variable to location of this file's directory (include directory itself and remove ending back slash) then run to add best practice config scripts to current session

$path = "FULL PATH OF THIS FILE'S DIRECTORY"
Get-ChildItem "$path\Scripts\*.ps1" | % { . $_ } 

# 2) Set $VMs variable - enter 1 to many VM names

$VMs = Get-VM -Name "VM1", "VM2", "VM3"

# 3) Run config tasks that are required based on migration spreadsheet or check using below code

$VMs | select Name, Powerstate,
@{n='UpdateVMTools';e={if($_.ExtensionData.Guest.ToolsVersionStatus -ne "guestToolsCurrent"){'Y'}else{'N'}}},
@{n='UpgradeHV';e={if($_.HardwareVersion -ne "vmx-15"){'Y'}else{'N'}}},
@{n='MoveDatastore';e={
if(
    (
        (($_ | Get-HardDisk | sel storageformat).storageformat | sel -Unique) -ne 'Thin'
    ) -or
    (
        (($_ | Get-Datastore).Type -notcontains 'VVOL') -and
        (
            (($_.ExtensionData.LayoutEx.File[0].Name -split ' ' -split '/')[1] -ne $_.name) -or
            (($_.ExtensionData.LayoutEx.File[0].Name -split ' ' -split '/')[-1] -ne "$($_.name).vmx")
        )
    )
)
{'Y'}else{'N'}
}},
@{n='DisableCPUHotAdd';e={if($_.ExtensionData.Config.CPUHotAddEnabled){'Y'}else{'N'}}},
@{n='EnableMemHotAdd';e={if($_.ExtensionData.Config.MemoryHotAddEnabled){'N'}else{'Y'}}},
@{n='ChangeNicTypeToVMXNET3';e={($_ | Get-NetworkAdapter | ? Type -ne 'VMXNET3' | sort Name).Name -replace 'Network Adapter ' -join ', '}},
@{N='EnableChangeBlockTracking';e={if($_.ExtensionData.Config.ChangeTrackingEnabled){'N'}else{'Y'}}}


## Upgrade VMTools

New-VMToolsUpgrades -VMs $VMs

## Upgrade VM hardware version

New-VMHardwareVersionUpgrades -VMs $VMs

## Disable CPU hot-add

Set-VMCPUHotAddOption -VMs $VMs -Enabled $false

## Enable memory hot-add

Set-VMMemoryHotAddOption -VMs $VMs -Enabled $true

## Enable change block tracking

Set-VMChangeBlockTrackingOption -VMs $VMs -Enabled $true
