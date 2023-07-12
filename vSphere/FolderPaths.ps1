$folderPaths = gvh | % {

    $parenthost = $_
    $_ | gvm | sel @{n='parenthost';e={$parenthost}},name,@{n='fp';e={Get-VIFolderPath -VIObject $_}}
    
}
    
$disconnectedHosts | ? name -Like zts* | % {

    $curHost = $_

    $folders = $folderPaths | ? {$_.parenthost.name -eq $curHost.name} | sel name,fp,
    @{n='folder';
    e={
        $origFp = $_.fp
        get-folder ($origFp -split '\\')[-1] | ? {"$( Get-VIFolderPath -VIObject $_ )\$( $_.Name )" -eq $origFp}
    }}

    $folders| % { 
        "`nMoving $( $_.name ) to $( $_.fp ) (Folder: $( $_.folder.name ) - $( $_.folder.id ) )`n" | Write-Host -ForegroundColor Green
        gvm $_.name | move-vm -InventoryLocation $_.folder -WhatIf 
    }
}