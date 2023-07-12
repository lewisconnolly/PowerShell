
function Set-VMSDRSAutomation ($VMs, $Enabled)
{
    $storMgr = Get-View StorageResourceManager

    $VMs |  % {
        
        if($Enabled)
        {
            $set = "default"
        }
        else
        {
            $set = 'disabled'
        }
        
        $spec = New-Object VMware.Vim.StorageDrsConfigSpec
        $DSCluster = $_ | get-datastore | Get-DatastoreCluster
        
        if($DSCluster -ne $null)
        {
            $vmEntry = New-Object VMware.Vim.StorageDrsVmConfigSpec
            $vmEntry.Operation = 'add'
            $vmEntry.Info = New-Object VMware.Vim.StorageDrsVmConfigInfo
            $vmEntry.Info.Vm = $_.ExtensionData.MoRef
            $vmEntry.info.Enabled = $false
            $spec.vmConfigSpec += $vmEntry
            
            "`n`nSetting $($_.Name) SDRS automation as $set on $($DSCluster.Name)" | Write-Host -ForegroundColor Green

            $storMgr.ConfigureStorageDrsForPod($DSCluster.ExtensionData.MoRef,$spec,$true)
        }
    }
}


function Get-VMSDRSAutomation ($VMs, $DatastoreCluster)
{
    $storMgr = Get-View StorageResourceManager
    
    if($VMs)
    {
        if(!$DatastoreCluster)
        {
            $DatastoreCluster = Get-DatastoreCluster
        }
        
        $VMs | % {
            $VMName = $_.Name            
            $VMID = $_.Id
            (Get-DatastoreCluster $DatastoreCluster).ExtensionData.PodStorageDrsEntry.StorageDrsConfig.VmConfig |
            select @{n='Name';e={$VMName}},@{n='ID';e={"$($_.VM.Type)-$($_.VM.Value)"}},* -ExcludeProperty Vm |
            ? id -eq  $VMID
        }
    }
    elseif($DatastoreCluster)
    {
        (Get-DatastoreCluster $DatastoreCluster).ExtensionData.PodStorageDrsEntry.StorageDrsConfig.VmConfig |
        select @{n='Name';e={(Get-VM -Id "$($_.VM.Type)-$($_.VM.Value)").Name}},
        @{n='ID';e={"$($_.VM.Type)-$($_.VM.Value)"}},
        * -ExcludeProperty Vm 
    }
    else
    {
        (Get-DatastoreCluster).ExtensionData.PodStorageDrsEntry.StorageDrsConfig.VmConfig |
        select @{n='Name';e={(Get-VM -Id "$($_.VM.Type)-$($_.VM.Value)").Name}},
        @{n='ID';e={"$($_.VM.Type)-$($_.VM.Value)"}},
        * -ExcludeProperty Vm 
    }
}