function Move-VMandBackAgain ($VMs) {

    get-vm $VMs | sort usedspacegb -Descending | % {

        $Source = $_ | get-datastore
        $UsedVM = $_.UsedSpaceGB
        $dsc = $Source | Get-DatastoreCluster
        $Targ = ($dsc | get-datastore |
        ? {($_.FreeSpaceGB-$UsedVM) -ge ($_.CapacityGB*0.1)} |
        sort freespacegb -Descending)[0]
        if($Targ){
            write-host "moving $($_.name) of size $UsedVM to $($targ.name) with $($targ.freespacegb) free`n`n" -ForegroundColor Green
    
            move-vm -VM $_ -Datastore $Targ  -StorageFormat Thin -WhatIf

            write-host "moving $($_.name) of size $UsedVM back to $($Source.name) with $($Source.freespacegb) free`n`n" -ForegroundColor Green

            move-vm -vm $_ -Datastore $Source -StorageFormat Thin -WhatIf

        }else{write-host "cannot move $($_.name) of size $UsedVM as no datastore with sufficient space`n`n" -ForegroundColor Green}
    }
}

#datastore evac
function Evac-Datastore ($Datastores,$ExcludedDatastores,$ExcludedVMs){
    get-datastore $Datastores | get-vm |? {$_ -notin $ExcludedVMs} | sort usedspacegb -Descending | % {

        $UsedVM = $_.UsedSpaceGB
        $Source = $_ | get-datastore
        $Targ = (get-datastore |
        ? {($_ -notin $Datastores)-and($_ -notin $ExcludedDatastores)-and(($_.FreeSpaceGB-$UsedVM)-ge($_.CapacityGB*0.1))} |
        sort freespacegb -Descending)[0]
        if($Targ){
            write-host "`nMoving $($_.name) of size $([math]::Round($UsedVM,2)) from $($Source.name -join ',') to $($targ.name) with $([math]::Round($targ.freespacegb,2)) free`n`n" -ForegroundColor Green
    
            move-vm -VM $_ -Datastore $Targ | Out-Null
            $_ | get-harddisk

        }else{write-host "`nUnable to move $($_.name) of size $([math]::Round($UsedVM,2)) from $($Source.name -join ',') as there is no datastore with sufficient space`n`n" -ForegroundColor Green}
    }

}

## sim datastore moves

$datastores = Get-Datacenter DCA,DCB|get-datastore |? name -NotMatch 'STORE|VLOLS'|select name,freespacegb,capacitygb,parentfolderid

$nonThin |? power* -Match off| sort usedspacegb -Descending | % {

    $Source = $_ | get-datastore
    $UsedVM = [math]::Round($_.UsedSpaceGB,2)
    $dsc = $Source | Get-DatastoreCluster |select -ExpandProperty id
    $Targ = ($datastores | ? {($_.parentfolderid -eq $dsc) -and ($_.name -ne $Source.name)} |
    ? {(($_.FreeSpaceGB-$UsedVM) -ge ($_.CapacityGB*0.1))} |
    sort freespacegb -Descending)[0]

    if($Targ){
        write-host `
        "Moving $($_.name) of size $UsedVM GB from $($source.name) to $($targ.name) with $([math]::Round($targ.freespacegb,2)) GB free ($([math]::Round(($targ.freespacegb-$UsedVM),2)) GB after)`n`n"`
        -ForegroundColor Green
                        
        $datastores = $datastores | select name,
        @{n='freespacegb';e={
            if($_.name -eq $targ.name){$_.freespacegb - $UsedVM}
            elseif($_.name -eq $source.name){$_.freespacegb +$UsedVM}
            else{$_.freespacegb}
        }},
        capacitygb,
        parentfolderid

        move-vm -VM $_ -Datastore (get-datastore $Targ.name)  -StorageFormat Thin -WhatIf

    }else{write-host "Cannot move $($_.name) of size $UsedVM as no datastore with sufficient space`n`n" -ForegroundColor Magenta}
}

## actually move datastore

$nonThin |? power* -Match off| sort usedspacegb -Descending | % {

    $Source = $_ | get-datastore
    $UsedVM = [math]::Round($_.UsedSpaceGB,2)
    $dsc = $Source | Get-DatastoreCluster |select -ExpandProperty id
    $Targ = (get-datastore | ? {($_.parentfolderid -eq $dsc) -and ($_.name -ne $Source.name)} |
    ? {(($_.FreeSpaceGB-$UsedVM) -ge ($_.CapacityGB*0.1))} |
    sort freespacegb -Descending)[0]

    if($Targ){
        write-host `
        "Moving $($_.name) of size $UsedVM GB from $($source.name) to $($targ.name) with $([math]::Round($targ.freespacegb,2)) GB free ($([math]::Round(($targ.freespacegb-$UsedVM),2)) GB after)`n`n"`
        -ForegroundColor Green

        move-vm -VM $_ -Datastore (get-datastore $Targ.name)  -StorageFormat Thin -WhatIf

    }else{write-host "Cannot move $($_.name) of size $UsedVM as no datastore with sufficient space`n`n" -ForegroundColor Magenta}
}