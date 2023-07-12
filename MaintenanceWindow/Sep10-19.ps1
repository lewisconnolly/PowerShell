function Set-VmxScheduleUpgrade ($VMs,$HardwareVersion){

    $VMs | % {

        $vm = Get-VM $_

        $do = New-Object -TypeName VMware.Vim.VirtualMachineConfigSpec

        $do.ScheduledHardwareUpgradeInfo = New-Object -TypeName VMware.Vim.ScheduledHardwareUpgradeInfo

        $do.ScheduledHardwareUpgradeInfo.UpgradePolicy = "always"

        $do.ScheduledHardwareUpgradeInfo.VersionKey = $HardwareVersion

        $vm.ExtensionData.ReconfigVM_Task($do)

    }
}

function Do-Patching ($VMs) {

    gvm $VMs | % {
    
        $snapName = 'Pre SaaS Patching - 10th Sep 19'
        $toolsPolicy = 'upgradeAtPowerCycle'
        $hv = 'vmx-13'

        $toolsPolicyChange = $false
    
        $_ | New-Snapshot -Name $snapName

        $tv = (gvm $_).ExtensionData.Config.Tools.ToolsVersion
        $origPolicy = (Get-ToolsUpgradePolicy -VM $_).policy

        if($tv -ne '10346' -and ($origPolicy -ne $toolsPolicy))
        {
            Set-ToolsUpgradePolicy -VM $_ -Policy $toolsPolicy
            $toolsPolicyChange = $true
        }
        if($_.HardwareVersion -ne $hv)
        {
            Set-VmxScheduleUpgrade -VMs $_ -HardwareVersion $hv
        }

        $_ | Stop-VMGuest -con:0
        while((gvm $_).PowerState -match 'on')
        {
            sleep 5
            "`nWaiting for $($_.Name) power off"
        }
        $_ | Start-VM
        
        while((gvm $_).ExtensionData.Config.Tools.ToolsVersion -ne '10346')
        {
            sleep 5
            $curTV = (gvm $_).ExtensionData.Config.Tools.ToolsVersion
            "`nWaiting for $($_.Name) tools to upgrade. Current version: $curTV."
        }
        "
        
        $($_.Name) :

        `tTools: $tv
        `tHV: $((gvm $_).HardwareVersion)

        "
        
        if($toolsPolicyChange)
        {
            Set-ToolsUpgradePolicy -VM $_ -Policy $origPolicy
        }  
    }
}

function Do-PatchingParallel ($VMs) {

    $snapName = 'Pre SaaS Patching - 10th Sep 19'
    $toolsPolicy = 'upgradeAtPowerCycle'
    $hv = 'vmx-13'

    $toolsPolicyChange = $false
    
    gvm $VMs | New-Snapshot -Name $snapName

    gvm $VMs | % {
        $tv = (gvm $_).ExtensionData.Config.Tools.ToolsVersion
        $origPolicy = (Get-ToolsUpgradePolicy -VM $_).policy

        if($tv -ne '10346' -and ($origPolicy -ne $toolsPolicy))
        {
            Set-ToolsUpgradePolicy -VM $_ -Policy $toolsPolicy
            $toolsPolicyChange = $true
        }
        if($_.HardwareVersion -ne $hv)
        {
            Set-VmxScheduleUpgrade -VMs $_ -HardwareVersion $hv
        }
    }

    gvm $VMs | Stop-VMGuest -con:0
    
    gvm $VMs | % {

        while((gvm $_).PowerState -match 'on')
        {
            sleep 5
            "`nWaiting for $($_.Name) power off"
        }
    }
    
    $_ | Start-VM
        
    while((gvm $_).ExtensionData.Config.Tools.ToolsVersion -ne '10346')
    {
        sleep 5
        $curTV = (gvm $_).ExtensionData.Config.Tools.ToolsVersion
        "`nWaiting for $($_.Name) tools to upgrade. Current version: $curTV."
    }
    "
        
    $($_.Name) :

    `tTools: $tv
    `tHV: $((gvm $_).HardwareVersion)

    "
        
    if($toolsPolicyChange)
    {
        Set-ToolsUpgradePolicy -VM $_ -Policy $origPolicy
    }  
    
}

$T1 = gvm dca-ps-sit1,
dca-ps-sql1,
dca-ps-switch1,
dca-ps-switch2,
dca-ps-task1,
dca-ps-url1,
dca-ps-url2,
dca-ps-web1,
dca-ps-web2,
dca-ps-web3,
dca-ps-web4

$T2 = gvm dca-ae-sql1,
dca-ae-sql2,
dca-ae-task1,
dca-ae-web1,
dca-ae-web2

$T3 = gvm dca-igw-web2,
dca-igw-sql1,
DCAIGWPRDTSK01,
dca-igw-web1,
dca-ios-sql1,
dca-ios-web2,
dca-ios-task1,
dca-ios-web1,
dca-mw-sql1,
dca-mw-web2,
dca-mw-task1,
dca-mw-web1,
dca-lrp-web2,
dca-lrp-job1,
dca-lrp-sql1,
dca-lrp-web1,
dca-prd-tsk1,
dca-prd-sql1,
dca-prd-web2,
dca-prd-web1

<#
Re-run then disable Veeam jobs:

PS #done
AE #done
IGW #done
IOS #done
MW #done
LRP #done
PRD #done

#
1200 - Verify backups complete - Confirm all backup jobs completed

Completed
#
#>

gvm dca-igw-sql1 | set-vm -NumCpu 2 -con:0
gvm dca-igw-sql1 | move-vm -Datastore DCA-HYB-EQL04 -Confirm:0 -RunAsync
gvm dca-mw-sql1 | move-vm -Datastore DCA-HYB-EQL10 -Confirm:0 -RunAsync

$snapName = 'Pre SaaS Patching - 10th Sep 19'
$toolsPolicy = 'upgradeAtPowerCycle'
$hv = 'vmx-13'

### PS

# Create snapshot on dca-ps-sql1
$psSQL1 = $T1 | ? Name -Like *sql1 
$psSQL1 | New-Snapshot -Name $snapName

# Performing cold boot on dca-ps-sql1
Set-ToolsUpgradePolicy -VM $psSQL1 -Policy $toolsPolicy
#Set-VmxScheduleUpgrade -VMs $psSQL1 -HardwareVersion $hv
$psSQL1 | Stop-VMGuest
while((gvm $psSQL1).PowerState -match 'on')
{
    sleep 5
    'Waiting for power off'
}
$psSQL1 | Start-VM
sleep 30
$tv = (gvm $psSQL1).ExtensionData.Config.Tools.ToolsVersion

"
$($psSQL1.Name) :

`tTools: $tv
`tHV: $((gvm $psSQL1).HardwareVersion)

"

Set-ToolsUpgradePolicy -VM $psSQL1 -Policy 'manual'

# dca-ps-sql1 ready for SQL patching

# Remaining T1
$T1 | ? Name -NotLike *sql1 | % {
    
    Do-Patching -VMs $_
}

"$(($T1 | ? Name -NotLike *-sql1 ).Name -join "`n")`n`nReady for Win patching"

### AE

# Create snapshot on dca-ae-sql2
$aeSQL2 = $T2 | ? Name -Like *sql2

Do-Patching -VMs $aeSQL2

# Create snapshot on dca-ae-sql1
$aeSQL1 = $T2 | ? Name -Like *sql1

Do-Patching -VMs $aeSQL1

$T2 | ? Name -NotLike *-sql* | % {

    Do-Patching -VMs $_
}

"$(($T2 | ? Name -NotLike *-sql* ).Name -join "`n")`n`nReady for Win patching"


### T3

$T3SQLs = $T3 | ? Name -Like *sql1

$T3SQLs | % {

    Do-Patching -VMs $_
}

"$($T3SQLs.Name -join "`n")`n`nReady for Win patching"


$T3 | ? Name -NotLike *-sql1 | % {

    Do-Patching -VMs $_
}

"$(($T2 | ? Name -NotLike *-sql1 ).Name -join "`n")`n`nReady for Win patching"


### Cleanup

gvm ($T1,$T2,$T3).name| select Name,
HardwareVersion,
@{n='ToolsVersion';e={$_.ExtensionData.Config.Tools.ToolsVersion}},
@{n='Snapshot';e={$_|Get-Snapshot}} | sort

