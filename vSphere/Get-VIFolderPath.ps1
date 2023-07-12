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

