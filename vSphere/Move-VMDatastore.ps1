function Move-VMDatastore ($VMs, $Log)
{
    foreach ($vm in $VMs) {
        
        $curVM = Get-VM $vm
        $curDs = $curVM | Get-Datastore
        
        if(($curDs.type -eq 'VVOL')) {
            
            Add-Content $Log -Value "--------------------------------------------------`r`n"
            Write-Host "--------------------------------------------------`r`n" -ForegroundColor Cyan
            Add-Content $Log -Value "# $($curVM.name) is on a VVOL datastore. Exiting`r`n"
            Write-Host "# $($curVM.name) is on a VVOL datastore. Exiting`r`n" -ForegroundColor Yellow
            Add-Content $Log -Value "--------------------------------------------------`r`n" 
            Write-Host "--------------------------------------------------`r`n" -ForegroundColor Cyan
            Add-Content $Log -Value "##################################################`r`n" 
            Write-Host "##################################################`r`n" -ForegroundColor Cyan

        } elseif($curDs.count -gt 1) {
            
            Add-Content $Log -Value "--------------------------------------------------`r`n"
            Write-Host "--------------------------------------------------`r`n" -ForegroundColor Cyan
            Add-Content $Log -Value "# $($curVM.name) is on more than one datastore. Exiting`r`n"
            Write-Host "# $($curVM.name) is on more than one datastore. Exiting`r`n" -ForegroundColor Yellow
            Add-Content $Log -Value "--------------------------------------------------`r`n" 
            Write-Host "--------------------------------------------------`r`n" -ForegroundColor Cyan
            Add-Content $Log -Value "##################################################`r`n" 
            Write-Host "##################################################`r`n" -ForegroundColor Cyan

        } else {
            
            Add-Content $Log -Value "--------------------------------------------------`r`n"
            Write-Host "--------------------------------------------------`r`n" -ForegroundColor Cyan
            Add-Content $Log -Value "# Processing $($curVM.name)...`r`n"
            Write-Host "# Processing $($curVM.name)...`r`n" -ForegroundColor Yellow
            
            if ($null -ne ($curDs | Get-DatastoreCluster)) {

                $targDS = $curDs | Get-DatastoreCluster | Get-Datastore | ? {$_.name -ne $curDs.name} |
                Sort-Object FreeSpaceGB | select -last 1

            } else {
                
                $targDs = Get-Datastore | ? {($null -eq ($_|Get-DatastoreCluster))-and($_.name -ne $curDs.name)-and($_.name -notmatch 'local')} |
                Sort-Object FreeSpaceGB | select -last 1
            }

            if(($targDS.FreeSpaceGB-$curVM.UsedSpaceGB) -lt ($targDS.CapacityGB * 0.10)){
                
                Add-Content $Log -Value "# No datastore available for $($curVM.name) to satisfy space requirements ($([math]::Round($curVM.UsedSpaceGB,2))GB)`r`n" 
                Write-Host "No datastore available for $($curVM.name) to satisfy space requirements ($([math]::Round($curVM.UsedSpaceGB,2))GB)`r`n" -ForegroundColor DarkRed
                Add-Content $Log -Value "--------------------------------------------------`r`n" 
                Write-Host "--------------------------------------------------`r`n" -ForegroundColor Cyan
                Add-Content $Log -Value "##################################################`r`n" 
                Write-Host "##################################################`r`n" -ForegroundColor Cyan

            } else {

                Add-Content $Log -Value "# Moving $($curVM.Name) of size $([math]::Round($curVM.UsedSpaceGB,2))GB to $($targDS.Name) with $([math]::Round($targDS.FreeSpaceGB,2))GB of free space`r`n"
                Write-Host "Moving $($curVM.Name) of size $([math]::Round($curVM.UsedSpaceGB,2))GB to $($targDS.Name) with $([math]::Round($targDS.FreeSpaceGB,2))GB of free space`r`n" -ForegroundColor Magenta
                
                try {
                
                    Move-VM $curVM -Datastore $targDS|Out-Null
                
                    Add-Content $Log -Value "# $($curVM.Name) move to $($targDS.Name) complete`r`n"
                    Write-Host "$($curVM.Name) move to $($targDS.Name) complete`r`n" -ForegroundColor Magenta

                } catch {
                    
                    Add-Content $Log -Value "# Unable to move $($curVM.Name) to $($targDS.Name)`r`n"
                    Write-Host "Unable to move $($curVM.Name) to $($targDS.Name)`r`n" -ForegroundColor DarkRed
                    Add-Content $Log -Value $Error[0]
                    Write-Host $Error[0] -ForegroundColor DarkRed
                
                }
                
                <#

                Add-Content $Log -Value "# Moving back $($curVM.Name) of size $([math]::Round($curVM.UsedSpaceGB,2))GB to $($curDs.Name) with $([math]::Round($targDS.FreeSpaceGB,2))GB of free space`r`n"
                Write-Host "Moving back $($curVM.Name) of size $([math]::Round($curVM.UsedSpaceGB,2))GB to $($curDs.Name) with $([math]::Round($curDS.FreeSpaceGB,2))GB of free space`r`n" -ForegroundColor Magenta
                
                try {

                    Move-VM $curVM -Datastore $curDs|Out-Null
                
                    Add-Content $Log -Value "# $($curVM.Name) move back to $($curDS.Name) complete`r`n"
                    Write-Host "$($curVM.Name) move back to $($curDS.Name) complete`r`n" -ForegroundColor Magenta

                } catch {
                    
                    Add-Content $Log -Value "# Unable to move $($curVM.Name) back to $($curDS.Name)`r`n"
                    Write-Host "Unable to move $($curVM.Name) back to $($curDS.Name)`r`n" -ForegroundColor DarkRed
                    Add-Content $Log -Value $Error[0]
                    Write-Host $Error[0] -ForegroundColor Red
                
                }
                
                #>

                if ((Get-VM $curVM).name -eq (($curVM.ExtensionData.Config.Files.VmPathName -split '] ')[-1] -split '/')[0]) {

                    # Add-Content $Log -Value "# $($curVM.name) moved to $($targDS.Name) then back to $($curDs) to fix inconsistent folder name`r`n"
                    # Write-Host "$($curVM.name) moved to $($targDS.Name) then back to $($curDs) to fix inconsistent folder name`r`n" -ForegroundColor Green
                    Add-Content $Log -Value "# $($curVM.name) moved to $($targDS.Name) to fix inconsistent folder name`r`n"
                    Write-Host "$($curVM.name) moved to $($targDS.Name) to fix inconsistent folder name`r`n" -ForegroundColor Green
                    Add-Content $Log -Value "--------------------------------------------------`r`n" 
                    Write-Host "--------------------------------------------------`r`n" -ForegroundColor Cyan
                    Add-Content $Log -Value "##################################################`r`n" 
                    Write-Host "##################################################`r`n" -ForegroundColor Cyan

                } else {

                    $curVmFolder = (($curVM.ExtensionData.Config.Files.VmPathName -split '] ')[-1] -split '/')[0]
                    Add-Content $Log -Value "# $($curVM.name) does not match folder name: $curVmFolder`r`n"
                    Write-Host "$($curVM.name) does not match folder name: $curVmFolder`r`n" -ForegroundColor DarkRed
                    Add-Content $Log -Value "# $($curVM.name) started on datastore $($curDs.name) and now on $((get-vm $curVM | get-datastore).name)`r`n"
                    Write-Host "$($curVM.name) started on datastore $($curDs.name) and now on $((get-vm $curVM | get-datastore).name)`r`n" -ForegroundColor Magenta
                    Add-Content $Log -Value "--------------------------------------------------`r`n" 
                    Write-Host "--------------------------------------------------`r`n" -ForegroundColor Cyan
                    Add-Content $Log -Value "##################################################`r`n" 
                    Write-Host "##################################################`r`n" -ForegroundColor Cyan

                }
            }
        }
    }
}