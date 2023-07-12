$members = Get-DrsClusterGroup -Name DCA-VMGroup-SQL | sel -ExpandProperty member 
$nonMembers = Get-DrsClusterGroup -Name DCA-VMGroup-NonSQL | sel -ExpandProperty member 

$sqlDrsGroup|? dcb -eq false| ? vm -ne ms-trg| ? vm -ne DCAUTLPRDSQL02 | % {

    if($_.shouldbeingroup -eq 'FALSE'){
        
        if((gvm $_.vm) -in $members){

            "`n" + $_.vm + " removed from sql group`n" | Write-Host -ForegroundColor Green
            Set-DrsClusterGroup -DrsClusterGroup DCA-VMGroup-SQL -VM (gvm $_.vm) -Remove
            
            if((gvm $_.vm) -notin $nonMembers){

                "`n" + $_.vm + " added to nonsql group`n" | Write-Host -ForegroundColor Magenta
                Set-DrsClusterGroup -DrsClusterGroup DCA-VMGroup-NonSQL -VM (gvm $_.vm) -Add
            }
        }
    }
    if($_.shouldbeingroup -eq 'TRUE'){
        
        if((gvm $_.vm) -notin $members){

            "`n" + $_.vm + " added to sql group`n" | Write-Host -ForegroundColor Green
            Set-DrsClusterGroup -DrsClusterGroup DCA-VMGroup-SQL -VM (gvm $_.vm) -add

            if((gvm $_.vm) -in $nonMembers){

                "`n" + $_.vm + " removed from nonsql group`n" | Write-Host -ForegroundColor Magenta
                Set-DrsClusterGroup -DrsClusterGroup DCA-VMGroup-NonSQL -VM (gvm $_.vm) -Remove
            }
        }
    }
}