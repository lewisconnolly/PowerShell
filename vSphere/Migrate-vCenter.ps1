function Migrate-vCenter ($SrcVMHost,$DestVMHosts) {

    try{gvh $SrcVMHost | Out-Null}catch{Write-Host 'Cannot find source host. Exiting.' -ForegroundColor Red;return }
    try{gvh $DestVMHosts | Out-Null}catch{Write-Host 'Cannot find destination host. Exiting.' -ForegroundColor Red;return }

    $TargetVMs = gvh $SrcVMHost | gvm | select name,powerstate,
    @{n='numds';e={($_|Get-Datastore).count}} |
    ? {($_.numds -le 1) -and ($_.powerstate -match 'on')}

    $global:premoveparams = @()
    $global:failedvms = @()

    $TargetVMs | % {
        
        $thevm = gvm $_.name
        $srcds = $thevm | get-datastore
        $dsthost = gvh ($DestVMHosts | sort MemoryUsagePercentage | select -First 1).name
        $datastores = get-datastore -Location TF -Server vcenter
        $dspath = (($thevm.ExtensionData.layoutex.file.name[0] -split '] ')[1] -split '/')[0]
       
        if (($srcds.name -match 'local')-or($thevm.name -cne $dspath)) {
            $usedvm = $thevm.UsedSpaceGB
            $dstdsoptions = ($datastores|
            ? {($_.name -ne $srcds.name)-and($_.name -notmatch 'local')-and(($_.FreeSpaceGB-$usedvm)-ge($_.CapacityGB*0.1))})

            if(($srcds.name -like "SSD*")-or($srcds.name -like "15K*")){
                $dstds = $dstdsoptions | ? name -like "15K*" | sort freespacegb -Descending |
                select -first 1 -ErrorAction SilentlyContinue
            }elseif($srcds.name -like "10K*"){
                $dstds = $dstdsoptions | ? name -like "10K*" | sort freespacegb -Descending |
                select -first 1 -ErrorAction SilentlyContinue
            }elseif($srcds.name -like "7.2K*"){
                $dstds = $dstdsoptions | ? name -like "7.2K*" | sort freespacegb -Descending |
                select -first 1 -ErrorAction SilentlyContinue
            }

            if(!$dstds -and (($srcds.name -like "*SSD*")-or($srcds.name -like "*15K*"))){
                $dstds = ($dsthost | get-datastore -Name *SSD*local* | ? {($_.FreeSpaceGB-$usedvm)-ge($_.CapacityGB*0.1)}|
                sort freespacegb -Descending | select -first 1 -ErrorAction SilentlyContinue)
            }
            
            if(!$dstds){
                $dstds = $dstdsoptions | sort freespacegb -Descending | select -first 1 -ErrorAction SilentlyContinue
            }
            
            if(!$dstds){
                $dstds = ($dsthost | get-datastore -Name *10K*local* | ? {($_.FreeSpaceGB-$usedvm)-ge($_.CapacityGB*0.1)}|
                sort freespacegb -Descending | select -first 1 -ErrorAction SilentlyContinue)
            }
            
            if(!$dstds){
                $dstds = 'No valid datastore'
            }
        } else { $dstds = $datastores| ? name -eq $srcds.name }

        if($dstds -ne 'No valid datastore') {

            $path = $thevm | Get-VIFolderPath
            $splitpaths = $path.Split('\')
            $fldrnames = $splitpaths[2..$splitpaths.count]
            $fldrnames = $fldrnames -replace ' ',''
            $command = 'Get-Folder -Name vm -server vcenter -location TF'
            $continue=$true

            if(($fldrnames -contains 'Graylog')-or(($fldrnames -contains 'RabbitMQ')-and($fldrnames.count -le 2))){$fldrnames = $fldrnames -replace 'NonProd','CoreServices'}
            if($fldrnames -contains 'domain.test'){$fldrnames = @('Utility','DMZ')}
            if(($fldrnames -contains 'zabbix')-or($fldrnames -contains 'F5')-or($fldrnames -contains 'SteelApp')){$fldrnames = $fldrnames -replace 'Utility','CoreServices'}
            if(($fldrnames -contains 'Test')){
                $newfldrnames = @('NB')
                $fldrnames | % {$newfldrnames += $_}
                $fldrnames = $newfldrnames
            }

            $fldrnames | %  {
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
                            {$_ -match 'UAT-qa03'} {$test = $test -replace 'UAT-qa03','uat'}
                            {$_ -match 'Zookeeper'} {$test = $test -replace 'Zookeeper','zoo'}
                            {$_ -match 'Kafka'} {$test = $test -replace 'Kafka','kfk'}
                            {$_ -match 'gg-test'} {$test = $test -replace 'gg-test','gg'}
                            {$_ -match 'wm-test'} {$test = $test -replace 'wm-test','wm'}
                            {$_ -match 'nc-test'} {$test = $test -replace 'nc-test','nc'}
                            {$_ -match 'kp-test'} {$test = $test -replace 'kp-test','kp'}
                            {$_ -match 'RabbitMQ'} {$test = $test -replace 'RabbitMQ','rmq'}
                            {$_ -match 'MongoDB'} {$test = $test -replace 'MongoDB','mgodb'}
                            {$_ -match 'CampaignPlus'} {$test = $test -replace 'CampaignPlus','CampaignsPlus'}
                            {$_ -match 'dev01-Tables2'} {$test = $test -replace 'dev01-Tables2','dev01'}
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
            $dstnet = @()
            $thevm | Get-NetworkAdapter  | % {
                
                if($_.networkname -eq 'Monitoring') {$dstnet+= Get-VDPortgroup -Name "TF*1004"}
                elseif($_.networkname -eq 'SteelApp Jump') {$dstnet+= Get-VDPortgroup -Name "TF*1006"}
                elseif($_.networkname -eq 'VM Management') {$dstnet+= Get-VDPortgroup -Name "TF*0*Untagged"} 
                elseif($_.networkname -eq 'VM Network Non-PROD') {$dstnet+= Get-VDPortgroup -Name "TF*2*4094"} 
                else{
                    $srcvlan = ($_.networkname -split ' ')[-1]
                    $dstnet +=  Get-VDPortgroup -Name "TF*$srcvlan"
                }
            }

            $moveparams =  @{
                VM = $thevm
                Destination = $dsthost
                Datastore = $dstds
                NetworkAdapter = $thevm | Get-NetworkAdapter 
                PortGroup = $dstnet
                InventoryLocation = $dstfolder
                Server = 'vcenter'
            }
            $premoveparams += $moveparams

            Write-Host 'Migrating from ' -NoNewline -ForegroundColor Green; write-host 'tf-vcenter' -ForegroundColor Yellow -NoNewline;
            Write-Host ' to ' -NoNewline -ForegroundColor Green; Write-Host 'vcenter' -ForegroundColor Red -NoNewline; Write-Host " the following:`n" -ForegroundColor Green

            Write-Host 'VM: ' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.VM.Name -ForegroundColor Magenta
            Write-Host 'SrcHost: ' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.VM.VMHost -ForegroundColor Magenta
            Write-Host 'DestHost: ' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.Destination.Name -ForegroundColor Magenta
            Write-Host 'SrcDS: ' -ForegroundColor Cyan -NoNewline;Write-Host $srcds.Name -ForegroundColor Magenta
            Write-Host 'DestDS: ' -ForegroundColor Cyan -NoNewline;Write-Host $moveparams.Datastore.Name -ForegroundColor Magenta
            Write-Host 'SrcNet: ' -ForegroundColor Cyan -NoNewline;Write-Host ($moveparams.NetworkAdapter.NetworkName -join ', ') -ForegroundColor Magenta
            Write-Host 'DestNet: ' -ForegroundColor Cyan -NoNewline;Write-Host ($moveparams.Portgroup.Name -join ', ') -ForegroundColor Magenta
            Write-Host 'SrcFolder: ' -ForegroundColor Cyan -NoNewline;Write-Host "$($moveparams.VM.Folder.Parent.Name)\$($moveparams.VM.Folder.Name)" -ForegroundColor Magenta
            Write-Host 'DestFolder: ' -ForegroundColor Cyan -NoNewline;Write-Host "$($moveparams.InventoryLocation.Parent.Name)\$($moveparams.InventoryLocation.Name)" -ForegroundColor Magenta

            write-host "`n"
            
            try{Move-VM @moveparams | select Name,PowerState,VMHost,Folder | ft -AutoSize}catch{$failedvms += $moveparams}
            #Move-VM @moveparams -WhatIf

            write-host "`n----------------------------------------------`n" -ForegroundColor Green

        } else {
            
            $failedvm = 
                @{
                    VM = $thevm
                    SrcHost = $thevm.VMHost
                    SrcDS = $srcds
                    SrcNet = (($thevm|Get-NetworkAdapter).NetworkName)
                    SrcFolder = "$($thevm.Folder.Parent.Name)\$($thevm.Folder.Name)"
                }
            $failedvms += $failedvm

            Write-Host "Unable to satisfy storage requirements for migration:`n" -ForegroundColor Green
            
            Write-Host 'VM: ' -ForegroundColor Cyan -NoNewline;Write-Host $failedvm.VM.Name -ForegroundColor Magenta
            Write-Host 'SrcHost: ' -ForegroundColor Cyan -NoNewline;Write-Host $failedvm.srchost.Name -ForegroundColor Magenta
            Write-Host 'SrcDS: ' -ForegroundColor Cyan -NoNewline;Write-Host $failedvm.srcds.Name -ForegroundColor Magenta
            Write-Host 'SrcNet: ' -ForegroundColor Cyan -NoNewline;Write-Host ($failedvm.srcnet -join ', ') -ForegroundColor Magenta
            Write-Host 'SrcFolder: ' -ForegroundColor Cyan -NoNewline;Write-Host $failedvm.srcfolder -ForegroundColor Magenta

            write-host "`n----------------------------------------------`n" -ForegroundColor Green
        }
    }
}