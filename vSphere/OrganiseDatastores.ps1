Set-Content -Path .\manHigh.txt -Value ''

Set-Content -Path .\manMed.txt -Value ''

Set-Content -Path .\manLow.txt -Value ''

$highIOds = get-datastore 15K*PV*,SSD*|? name -notmatch zts11

$medIOds = get-datastore 10K*

$lowIOds = get-datastore 7.2K*

#$stats = Get-VMFootprintNP -VM (get-vm|? power* -match 'on') -Start (get-date).AddDays(-5) -Finish (get-date).AddDays(-1) 

$manHigh = 'C:\Users\Lewisc\Desktop\manHigh.txt'
$manMed = 'C:\Users\Lewisc\Desktop\manMed.txt'
$manLow = 'C:\Users\Lewisc\Desktop\manLow.txt'

function Select-Datastore ($vm, $datastores, $manLog)
{
    $curVM = Get-VM $vm
    $curDs = $curVM | Get-Datastore
    $needsMoved = $true
            
    $curDS | % {

        if($datastores -contains $_){

            Write-Warning "$($curVM.Name) already on appropriate datastore $($curDS.name)"
            $needsMoved = $false
        }
    }
    if ($needsMoved){
                   
        $targs = get-datastore $datastores | sort freespacegb -descending
        $i=0
        while (($i -lt $targs.count) -and (($targs[$i].FreeSpaceGB-$curVM.UsedSpaceGB) -lt ($targs[$i].CapacityGB*0.05))){
            $i++
        }              
        if (-not$targs[$i]){
            Write-Warning "No datastore available for $($curVM.name) to satisfy space requirements"
            Add-Content $manLog -Value "$($curVM.name)`r`n"
        } elseif ($targs[$i] -match 'local'){
            $zts = ($targs[$i].name -split '-')[1]
            Write-Host "Moving $($curVM.Name) to $zts.zhost and $($targs[$i])"
            $curVM | Move-VM -Location (Get-VMHost -Name "$zts*") -Datastore $targs[$i]
        } else {
            Write-Host "Moving $($curVM.Name) to $($targs[$i])"
            $curVM | Move-VM -Datastore $targs[$i] 
        } 
    } else {
        Add-Content $manLog -Value "$($curVM.name)`r`n"
    }
}


function Place-VMsToDatastores ($stats, $highIOds, $medIOds, $lowIOds)
{
    foreach ($vm in $stats){

        switch ($vm.'DiskAvrg(KBps)')
        {
            #highIO
            {$_ -gt 20} {
                Select-Datastore -vm $vm.Name -datastores $highIOds -manLog $manHigh
            }

            #medIO
            {($_ -gt 5) -and ($_ -lt 20)} {
                Select-Datastore -vm $vm.Name -datastores $medIOds -manLog $manMed
            }
        
            #low IO
            {$_ -lt 5} {
                Select-Datastore -vm $vm.Name -datastores $lowIOds -manLog $manLow
            }
            Default {}
        }
    }
}

$tfsfvmdatastores = import-csv .\tf-sf-datastores.csv 
$Vol1SFvms = ($tfsfvmdatastores |? datastore -eq '15KRAID10-PV-Vol1')|%{get-vm -name $_.vm.Trim(' ')}
$Vol1SFvms|%{Select-Datastore -vm $_ -datastores (get-datastore 15KRAID10-PV-Vol1) -manLog '.\manSF.txt'}