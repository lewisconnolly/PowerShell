$thevm = gvm tf-cp-nodejs2
$srcfolder = $thevm.folder.name
$dstfolder = (get-folder -Location TF -Server vcenter -Name ($thevm.folder.name) -ErrorAction SilentlyContinue)

if(!$dstfolder) {

    switch ($srcfolder){

    'ElasticSearch' {$dstfolder = get-folder -Location TF -Server vcenter -Name 'es'}
    'ServiceFabric' {$dstfolder = get-folder -Location TF -Server vcenter -Name 'sf'}
    'Load' {$dstfolder = get-folder -Location TF -Server vcenter -Name 'ld'}
    'Staging' {$dstfolder = get-folder -Location TF -Server vcenter -Name 'stg'}
    ($_.Contains(' ')) {$dstfolder = get-folder -Location TF -Server vcenter -Name ($srcfolder -replace ' ','')}
    }

}

$i = -2
$oneup = ' '
$path = $thevm | Get-VIFolderPath
while((($dstfolder.count -gt 1) -or (!$dstfolder))-and$oneup) {
$oneup = $path.Split('\')[$i]
$dstfolder = (get-folder -Location TF -Server vcenter -Name $oneup)
$i--
}

if(!$dstfolder) {
$dstfolder = (get-folder -Location TF -Server vcenter -Name 'Discovered virtual machine')
}