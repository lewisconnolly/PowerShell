##################################
### Get-VMDataProtectionStatus ###
###       lewis.connolly       ###
##################################

# Creates report of VMs and their array-level data protection
function Get-VMDataProtectionStatus {        

    # Function to get a VM's folder path
    function Get-VIFolderPath {
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
     
    $datastores = Get-Datastore -Location DCA, DCB | select Id, ParentFolderId, Name, Type
    $datastoreClusters = Get-DatastoreCluster -Location DCA, DCB | select Id, Name 
    $protectedIfVMXFileOnTheseDatastores = $datastores | ? Name -like "DCA*PURE*"
    $safeModeProtectedIfVMXFileOnTheseDatastores = $datastores | ? Name -like "DCA*PURE[123]*"
    $policies = Get-SpbmStoragePolicy | ? Name -Like "vVols-*" 
    $policyVMs = @{}
    $policies | % {

        $name = $_.Name
        $vms = $_ | Get-VM | select -ExpandProperty Id
        $vms | % {
            $policyVMs += @{ $_ = $name }
        }
    }

    Get-VM -Location DCA, DCB | % {
        
        $VM = $_
        $vmxDatastore = ($VM.ExtensionData.LayoutEx.File[0].Name -split ' ')[0] -replace '[\[\]]'
        $datastoreIdList = $VM.DatastoreIdList        

        $folderPath = $VM | Get-VIFolderPath
           
        # Get VM datastore if on vVols or datastore cluster
        $parentFolderId = ($datastores | ? Id -in $datastoreIdList)[0].ParentFolderId

        if($parentFolderId -match 'pod'){            
            $VMDatastoreOrCluster = ($datastoreClusters | ? Id -eq $parentFolderId).Name
        }else{ $VMDatastoreOrCluster = ($datastores | ? Id -in $datastoreIdList).Name }
        
        
        $storageType = ($datastores | ? Name -eq $vmxDatastore)[0].Type
        
        # Get VM storage policy

        if($policyVMs[$VM.Id]){
            $storagePolicy = $policyVMs[$VM.Id]
        }elseif($storageType -eq 'VVOL'){
            $storagePolicy = 'NoProtectionPolicy'
        }else{ $storagePolicy = 'N/A(VMFS)' }

        # Get VM protection status
        if($storagePolicy -eq 'vVols-repl-excluded'){
            $isProtected = $isSafeModeProtected = $replicationTarget = 'N/A(ManuallyExcluded)'
        }else{
            
            if($storageType -eq 'VVOL'){
                if($storagePolicy -notin ('vVols-repl-excluded', 'NoProtectionPolicy')){ $isProtected = $true }else{ $isProtected = $false }
            }elseif($vmxDatastore -in $protectedIfVMXFileOnTheseDatastores.Name){ $isProtected = $true }else{ $isProtected = $false }

            # Get VM safe mode protection status
            if($storageType -eq 'VVOL'){
                
                if(($storagePolicy -notin ('vVols-repl-excluded', 'NoProtectionPolicy')) -and ($vmxDatastore -in $safeModeProtectedIfVMXFileOnTheseDatastores.Name)){
                    $isSafeModeProtected = $true
                }else{ $isSafeModeProtected = $false }
            }elseif($vmxDatastore -in $safeModeProtectedIfVMXFileOnTheseDatastores.Name){ $isSafeModeProtected = $true }else{ $isSafeModeProtected = $false }

            # Get VM replicated snaps location     

            if($isProtected){            
                if($vmxDatastore -like "DCA*PURE1*"){ $replicationTarget = 'dcb-flasharray1' }elseif($vmxDatastore -like "DCA*PURE[23]*"){ $replicationTarget = 'dcb-flasharray2' }
            }else{ $replicationTarget = 'N/A(NotProtected)' }
        }

        # Get VM warning status
        if(-not($isProtected -and $isSafeModeProtected)){ $status = 'Warning' }else{ $status = 'OK' }
        
        $VM | select @{n='Status';e={ $status }},
        Name,
        PowerState,
        @{n='FolderPath';e={ $folderPath }},
        @{n='DatastoreOrCluster';e={ $VMDatastoreOrCluster -join '<br>' }},
        @{n='StorageType';e={ $storageType }},
        @{n='StoragePolicy';e={ $storagePolicy }},
        @{n='IsProtected';e={ $isProtected }},
        @{n='IsSafeModeProtected';e={ $isSafeModeProtected }},
        @{n='ReplicationTarget';e={ $replicationTarget }}

    } | sort FolderPath
}

### Report Framework

Import-Module VMware.PowerCLI
Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

Connect-VIServer vcenter.zonalconnect.local | Out-Null

$VMProtectionStatus = Get-VMDataProtectionStatus

$numProtected = "{0}/{1}" -f ($VMProtectionStatus | ? {($_.IsProtected -eq $true) -or ($_.IsProtected -like "N/A*")}).Count, $VMProtectionStatus.Count
$percentProtected = "{0}%" -f [math]::Round(($VMProtectionStatus | ? {($_.IsProtected -eq $true) -or ($_.IsProtected -like "N/A*")}).Count/ $VMProtectionStatus.Count*100) 
$numSafeModeProtected = "{0}/{1}" -f ($VMProtectionStatus | ? {($_.IsSafeModeProtected -eq $true) -or ($_.IsSafeModeProtected -like "N/A*")}).Count, $VMProtectionStatus.Count
$percentSafeModeProtected = "{0}%" -f [math]::Round(($VMProtectionStatus | ? {($_.IsSafeModeProtected -eq $true) -or ($_.IsSafeModeProtected -like "N/A*")}).Count/ $VMProtectionStatus.Count*100) 

$dcaNumProtected = "{0}/{1}" -f ($VMProtectionStatus | ? FolderPath -like "DCA*" | ? {($_.IsProtected -eq $true) -or ($_.IsProtected -like "N/A*")}).Count, ($VMProtectionStatus | ? FolderPath -like "DCA*").Count
$dcaPercentProtected = "{0}%" -f [math]::Round(($VMProtectionStatus | ? FolderPath -like "DCA*" | ? {($_.IsProtected -eq $true) -or ($_.IsProtected -like "N/A*")}).Count/($VMProtectionStatus | ? FolderPath -like "DCA*").Count*100) 
$dcaNumSafeModeProtected = "{0}/{1}" -f ($VMProtectionStatus | ? FolderPath -like "DCA*" | ? {($_.IsSafeModeProtected -eq $true) -or ($_.IsSafeModeProtected -like "N/A*")}).Count, ($VMProtectionStatus | ? FolderPath -like "DCA*").Count
$dcaPercentSafeModeProtected = "{0}%" -f [math]::Round(($VMProtectionStatus | ? FolderPath -like "DCA*" | ? {($_.IsSafeModeProtected -eq $true) -or ($_.IsSafeModeProtected -like "N/A*")}).Count/($VMProtectionStatus | ? FolderPath -like "DCA*").Count*100)

$reportContext = "Total VMs Protected or N/A: $numProtected ($percentProtected)
<br>
Total VMs SafeMode Protected or N/A: $numSafeModeProtected ($percentSafeModeProtected)
<br>
DCA VMs Protected or N/A: $dcaNumProtected ($dcaPercentProtected)
<br>
DCA VMs SafeModeProtected or N/A: $dcaNumSafeModeProtected ($dcaPercentSafeModeProtected)"

$VMProtectionStatus |
ConvertTo-HtmlReport `
    -ReportTitle "VM Data Protection Status" `
    -ReportDescription "Protection of VMs via storage array snapshot replication and deletion prevention" `
    -ReportContext $reportContext `
    -FilePath "C:\inetpub\Html Reports\vmdataprotection.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "C:\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "C:\inetpub\wwwroot\index.html" `
    -VirtualPath "/"
