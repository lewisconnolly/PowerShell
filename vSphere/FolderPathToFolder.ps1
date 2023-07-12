function Get-MoveVmParams ($VM, $DstHost, $DstDS, $DstNet, $DstFolder, $DstVC)
{
    @{
        VM = $VM
        Destination = $DstHost
        Datastore = $DstDS
        NetworkAdapter = ($VM | Get-NetworkAdapter).networkname
        PortGroup = $DstNet
        InventoryLocation = $DstFolder
        Server = $DstVC
    }
}


$datastores = get-datastore -Location TF | select name,freespacegb,capacitygb

${zts9-1nic} = gvh zts9.zhost | gvm | select name,powerstate,@{n='numnics';e={($_|Get-NetworkAdapter).count}},
@{n='localds';e={if(($_|get-datastore).name -match 'local'){$true}else{$false}}} |
? {($_.name -notlike "gg-*") -and ($_.numnics -eq 1)-and ($_.powerstate -match 'on')}

$allmoveparams = @()

${zts9-1nic}|% {

$thevm = gvm $_.name
$srcds = $thevm | get-datastore
$dsthost = gvh zts1.zhost

if (($thevm | get-datastore).name -match 'local') {

    $usedvm = $thevm.UsedSpaceGB
    $dstds = ($datastores|
    ? {($_.name -ne $srcds.name)-and($_.name -notmatch 'local')-and(($_.FreeSpaceGB-$usedvm)-ge($_.CapacityGB*0.1))} |
    sort freespacegb -Descending | select -first 1 -ErrorAction SilentlyContinue).name

    if(!$dstds){
        #return "$($thevm.name) - no valid datastore"
        $dstds = ($dsthost | get-datastore -Name *local* | sort -Descending | select -first 1 -ErrorAction SilentlyContinue).name
    }

} else { $dstds = ($datastores | ? {$_.Name -eq ($thevm|get-datastore).name}).name }

#simulate used space on datastores
if($dstds -ne $srcds.name){
    $datastores = $datastores | select name,
    @{n='FreeSpaceGB';e={if($_.name -eq $dstds){$_.FreeSpaceGB - $usedvm}else{$_.FreeSpaceGB}}},CapacityGB
}

$path = $thevm | Get-VIFolderPath
$splitpaths = $path.Split('\')
$fldnames = $splitpaths[2..$splitpaths.count]
$fldnames = $fldnames -replace ' ',''
$command = 'Get-Folder -Name vm -server vcenter -location TF'
$continue=$true
$fldnames | %  {
    if($continue){
        $parid = (Invoke-Expression $command -ErrorAction SilentlyContinue).id
        $test = $command + "| Get-Folder -Name '$_' -ErrorAction SilentlyContinue | ? Parentid -eq '$parid'"
        $result = Invoke-Expression $test -ErrorAction SilentlyContinue
        if($result){
            $command = $test
        }else{
            switch ($test){
                {$_ -match 'ElasticSearch'} {$test = $test -replace 'ElasticSearch','es'}
                {$_ -match 'ServiceFabric'} {$test = $test -replace 'ServiceFabric','sf'}
                {$_ -match 'Load'} {$test = $test -replace 'Load','ld'}
                {$_ -match 'Staging'} {$test = $test -replace 'Staging','stg'}                
            }
            $result = Invoke-Expression $test -ErrorAction SilentlyContinue
            if($result) {$command = $test}else{$continue = $false}
        }
    }
}

$dstfolder = Invoke-Expression $command
if($dstfolder.name -eq 'vm'){
$dstfolder = Get-Folder -Name 'Discovered virtual machine' -Location TF -Server vcenter
}
 
$srcvlan = (($thevm | Get-NetworkAdapter).networkname -split ' ')[-1]
$dstnet = Get-VDPortgroup -Name "TF*$srcvlan"

$moveparams = Get-MoveVmParams -VM $thevm -DstHost $dsthost -DstDS $dstds -DstNet $dstnet -DstFolder $dstfolder -DstVC vcenter 

$allmoveparams += $moveparams

Write-Host 'Migrating from ' -NoNewline -ForegroundColor Green; write-host 'tf-vcenter' -ForegroundColor Yellow -NoNewline;
Write-Host ' to ' -NoNewline -ForegroundColor Green; Write-Host 'vcenter' -ForegroundColor Blue -NoNewline; Write-Host " using parameters:`n`n" -ForegroundColor Green

Write-Host 'VM:' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.VM.Name -ForegroundColor Magenta
Write-Host 'DestHost:' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.Destination.Name -ForegroundColor Magenta
Write-Host 'DestDS:' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.Datastore -ForegroundColor Magenta
Write-Host 'SrcNet:' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.NetworkAdapter -ForegroundColor Magenta
Write-Host 'DestNet:' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.Portgroup -ForegroundColor Magenta
Write-Host 'DestServer:' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.Server -ForegroundColor Magenta

write-host "`n`n"

}