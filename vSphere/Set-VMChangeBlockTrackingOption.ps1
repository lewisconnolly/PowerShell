
function Set-VMChangeBlockTrackingOption {
    Param (        
        [Parameter(Mandatory=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]
        $VMs,

        [Parameter(Mandatory=$true)]
        [ValidateSet($true, $false)]
        $Enabled
    )
    
    # Store provided VMs and create empty array to store VMs requiring change

    $originalVMList = $VMs
    $VMs = $originalVMList | ? {$_.ExtensionData.Config.ChangeTrackingEnabled -ne $Enabled}

    if($VMs){
    
        "VMs requiring change block tracking change: $( ($VMs | sort Name).Name -join ', ' )" | Write-Host        
    
        if($Enabled){ "Enabling change block tracking" | Write-Host }else{ "Disabling change block tracking" | Write-Host }
        
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec    
        $vmConfigSpec.ChangeTrackingEnabled = $Enabled    
        (Get-View $VMs).ReconfigVM($vmConfigSpec)

        # Find VMs where CBT change failed

        if((Get-VM -Id $VMs.Id).ExtensionData.Config.ChangeTrackingEnabled -contains (!$Enabled)){
            
            "Change block tracking change failed on $( (Get-VM -Id $VMs.Id | ? {$_.ExtensionData.Config.ChangeTrackingEnabled -ne $Enabled}).Name -join ', ' )" | Write-Host
        }
    }
    
    # Get VMs where change worked or already set as specified by -Enabled param
    # E.g. If setting to enabled then activate on all enabled VMs and ignore where failed to enabled (wouldn't want to activate disabling of CBT if trying to enable)
    # Assumption is script will be retried/error investigated
    # Could improve by using guaranteed way of determining effective status of CBT

    $toSnap = Get-VM -Id $originalVMList.Id | ? {$_.ExtensionData.Config.ChangeTrackingEnabled -eq $Enabled}
    
    if($toSnap){
        
        "In order for change block tracking option to take effect a stun-unstun cycle is required" | Write-Host
        
        "Creating snapshots on all VMs where CBT option is set as specified by -Enabled parameter, even if no change was required - because CBT setting could be correct but not in effect (e.g. enabled and inactive)" | Write-Host
        $guid = ((New-Guid).guid -split '-')[0]
        $toSnap | New-Snapshot -Name "Change CBT option $guid" | Out-Null

        # Check if each VM has snapshot

        $snaps = Get-VM -Id $toSnap.Id | select Name, Id, @{n='SnapStatus';e={ if($_ | Get-Snapshot -Name "Change CBT option $guid"){ $true }else{ $false } }}
        
        # Print VMs where snapshot failed

        if($snaps.SnapStatus -contains $false){
            
            "Snapshot failed on $( ($snaps | sort Name | ? SnapStatus -eq $false).Name -join ', ' ). Current CBT setting may not be in effect" | Write-Host
        }
        
        # Remove snaps

        $toRemoveSnap = $snaps | ? SnapStatus -eq $true

        if($toRemoveSnap){
        
            "Removing snapshots" | Write-Host                
            Get-VM -Id $toRemoveSnap.Id | Get-Snapshot -Name "Change CBT option $guid" | Remove-Snapshot -Confirm:0 | Out-Null

            # Check if each VM snapshot removed. Use different variable name in case snap lookup fails and old variable used where snap existed - resulting in erroneous result
            # (snap was removed but lookup fails and check deems it exists because it did when $snap was created)

            $snaps1 = Get-VM -Id $toRemoveSnap.Id | select Name, Id, @{n='SnapStatus';e={ if($_ | Get-Snapshot -Name "Change CBT option $guid"){ $true }else{ $false } }}
        
            if($snaps1.SnapStatus -contains $true){
                
                "Snapshot removal failed on $( ($snaps1 | sort Name | ? SnapStatus -eq $true).Name -join ', ' ). Current CBT setting may not be in effect" | Write-Host
            }
            
            # Add VMs where snap was successfully removed to $snapRemoved - to be used later to report on effective status of CBT

            $snapRemoved = $snaps1 | ? SnapStatus -eq $false 
        }
    }        
       
    # Output all provided VMs and their CBT status

    Get-VM -Id $originalVMList.Id | select name, powerstate,
    @{n='ChangeTrackingEnabled';e={$_.ExtensionData.Config.ChangeTrackingEnabled}},
    @{n='ChangeTrackingSettingEffective';e={if($_.Id -in $snapRemoved.Id){'In effect'}else{'May not be in effect'}}} |
    sort name
}