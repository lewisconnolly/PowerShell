function Clear-Datastore ($Datastores,$ExcludedDatastores,$ExcludedVMs){
    get-datastore $Datastores | get-vm |? {$_ -notin $ExcludedVMs} | sort usedspacegb -Descending | % {

        $UsedVM = $_.UsedSpaceGB
        $Source = $_ | get-datastore
        $Targ = (get-datastore |
        ? {($_ -notin $Datastores)-and($_ -notin $ExcludedDatastores)-and(($_.FreeSpaceGB-$UsedVM)-ge($_.CapacityGB*0.1))} |
        sort freespacegb -Descending)[0]
        if($Targ){
            write-host "`nMoving $($_.name) of size $([math]::Round($UsedVM,2))GB from $($Source.name -join ',') to $($targ.name) with $([math]::Round($targ.freespacegb,2))GB free`n`n" -ForegroundColor Green
    
            move-vm -VM $_ -Datastore $Targ | Out-Null
            $_ | get-harddisk

        }else{write-host "`nUnable to move $($_.name) of size $([math]::Round($UsedVM,2))GB from $($Source.name -join ',') as there is no datastore with sufficient space`n`n" -ForegroundColor Green}
    }

}

