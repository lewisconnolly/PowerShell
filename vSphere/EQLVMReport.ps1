function Get-VIFolderPath
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true, 
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $VIObject
    )

    Begin {}
    Process
    {
        $VIObject | % {
            $VIObjectTypeName = $_.GetType().Name
        
            switch ($VIObjectTypeName)
            {
                Default {$FirstFolderPropertyName = "FolderId"}

                'FolderImpl' {$FirstFolderPropertyName = "ParentId"}

                'VmfsDatastoreImpl' {$FirstFolderPropertyName = "ParentFolderId"}
            }

            if($_.$FirstFolderPropertyName -match 'StoragePod')
            {
                $dsc = Get-DatastoreCluster -Id $_.$FirstFolderPropertyName
                $folder= get-folder -Id $dsc.extensiondata.Parent
                $folderpath= "$($folder.Name)\$($dsc.Name)"
            }
            else
            {
                $folder= get-folder -Id $_.$FirstFolderPropertyName

                $folderpath= $folder.Name
            }

            while ($folder.Parent -ne $null)
            {
                $folder = $folder.Parent
                $folderpath = "$($folder.Name)\$folderpath"
            }
            $folderpath
        }
    }
    End {}
}

$ErrorActionPreference = 'Stop'

Connect-VIServer vcenter

# Get tag assignments and clusters for all VMs at once instead of calling costly functions each time for each VM
$Datacenter = 'DCA'
$eqlVMs = Get-Datastore "*EQL*" -Location $Datacenter | Get-VM
$fdTagAssignments = Get-TagAssignment -Category FaultDomain | select @{n='TagName';e={$_.Tag.Name}},@{n='EntityName';e={$_.Entity.Name}}
$iopsTagAssignments = Get-TagAssignment -Category iops -Entity $eqlVMs | select @{n='TagName';e={$_.Tag.Name}},@{n='EntityName';e={$_.Entity.Name}}
$computeClusters = Get-Cluster -Location $Datacenter | % {
    $cluster = $_ 
    $cluster | Get-VMHost | select name,@{n='ClusterName';e={$cluster.Name}}
}
$dsInCluster = Get-DatastoreCluster -Location $Datacenter | % {
    $cluster = $_ 
    $cluster | Get-Datastore | select name,@{n='ClusterName';e={$cluster.Name}},Id
}
$ds = Get-Datastore -Location $Datacenter | select name,Id

# EQL VM report
$Sheet1 = $eqlVMs | select Name,PowerState,NumCPU,MemoryGB,
@{n='DiskType';e={
    $dsIds = $_.DatastoreIdList
    if(($ds | ? Id -in $dsIds).Name -match 'VVOL'){'VVOL'}else{'VMFS'}
}},
@{n='IOPSTags';e={
    $vm = $_
    ($iopsTagAssignments | ? EntityName -eq $vm.Name).TagName -join "`n"
}},
@{n='IOPSLimits';e={
    $diskConf = ($_ | Get-VMResourceConfiguration).DiskResourceConfiguration
    $vm = $_
    ($diskConf | % {
        $key = $_.key
        ($vm | Get-HardDisk | ? {$_.ExtensionData.key -eq $key}).Name + ' / ' +
        ($vm |Get-HardDisk | ? {$_.ExtensionData.key -eq $key}).CapacityGB + 'GB' + ' / ' +
        $_.DiskLimitIOPerSecond
    }) -join "`n"
}},
@{n='ServiceType';e={
    if((Get-VIFolderPath -VIObject $_) -match 'SaaS'){
        'SaaS'
    }elseif((Get-VIFolderPath -VIObject $_) -match 'Aztec'){
        'Aztec'
    }elseif((Get-VIFolderPath -VIObject $_) -match 'Utility'){
        'Utility'
    }else{'Misc'}
}},
SiteCount,TargetDiskType,TargetFA,Moved,
@{n='Datastore(s)';e={
    $dsIds = $_.DatastoreIdList
    (($ds | ? Id -in $dsIds).Name | sort) -join "`n"
}},
@{n='StorageFaultDomain';e={
    $dsIds = $_.DatastoreIdList
    $dsTags = $ds | ? Id -in $dsIds | sort Name | % {
        $dsName = $_.Name
        if($_.Name -notin $dsInCluster.Name){            
            ($fdTagAssignments | ? EntityName -eq ($ds | ? Name -eq $dsName).Name).TagName
        } else {
            ($fdTagAssignments | ? EntityName -eq ($dsInCluster | ? Name -eq $dsName).ClusterName).TagName 
        }
    } | Select -Unique
    if($dsTags){$dsTags -join "`n"}else{'NotTagged'}
}},
@{n='VMHost';e={
    $_.VMHost.Name
}},
@{n='ComputeFaultDomain';e={
    $vmhostName = $_.vmhost.name
    $clusterTag = ($fdTagAssignments | ? EntityName -eq ($computeClusters | ? Name -eq $vmhostName).ClusterName).TagName
    if($clusterTag){$clusterTag}else{'NotTagged'}
}} |
select *,
@{n='SingleRackFaultDomain';e={
    if($_.ComputeFaultDomain -ne $_.StorageFaultDomain){'FALSE'}else{'TRUE'}
}}

# EQL datastore report
$Sheet2 = Get-Datastore *EQL* -Location $Datacenter | select Name,CapacityGB,FreeSpaceGB,Type,
@{n='DatastoreCluster';e={(Get-DatastoreCluster -Id $_.ParentFolderId).Name}},
@{n='NumVMs';e={($_ | Get-VM | measure).count}},
@{n='VMs';e={($_ | Get-VM | sort Name).Name -join ', '}}

# DCA datastore cluster report
$Sheet3 = Get-DatastoreCluster -Location $Datacenter | select Name,CapacityGB,FreeSpaceGB,
@{n='NumVMs';e={($_ | Get-VM | measure).count}},
@{n='FaultDomain';e={
    $cluster = $_
    ($fdTagAssignments | ? EntityName -eq $cluster.Name).TagName
}},
@{n='Datastores';e={($_ |Get-Datastore | sort Name).Name -join ', '}}

# Export data as excel workbook with three sheets 
Remove-Item $env:USERPROFILE\Desktop\EQLVMReport.xlsx -ErrorAction Ignore
$Sheet1 | Export-Excel $env:USERPROFILE\Desktop\EQLVMReport.xlsx -WorksheetName 'VMs' -TableName 'VMs' -AutoSize -AutoFilter
$Sheet2 | Export-Excel $env:USERPROFILE\Desktop\EQLVMReport.xlsx -WorksheetName 'Datastores' -TableName 'Datastores' -AutoSize -AutoFilter
$Sheet3 | Export-Excel $env:USERPROFILE\Desktop\EQLVMReport.xlsx -WorksheetName 'DatastoreClusters' -TableName 'DatastoreClusters' -AutoSize -AutoFilter
$EqlVmReportExcel = Open-ExcelPackage -Path $env:USERPROFILE\Desktop\EQLVMReport.xlsx
Set-Format -Address $EqlVmReportExcel.Workbook.Worksheets[1].Cells -WrapText
Close-ExcelPackage $EqlVmReportExcel