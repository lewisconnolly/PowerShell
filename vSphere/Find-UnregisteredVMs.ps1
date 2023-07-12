function Find-UnregisteredVMs ($Datastores) {

    foreach($Datastore in Get-Datastore $Datastores) {
        # Collect .vmx paths of registered VMs on the datastore
        $registered = @{}
        Get-VM -Datastore $Datastore | %{
            $vmxfile = (($_.Extensiondata.LayoutEx.File | where {$_.Name -like "*.vmx"}).name -split '\/')[-1]
            $registered.Add($vmxfile,$true)
        }
        
        # Search for .vmx files in Datastore not in registered
        New-PSDrive -Name TgtDS -Location $Datastore -PSProvider VimDatastore -Root '\' | Out-Null
        $unregistered = Get-ChildItem -Path TgtDS: -Recurse | `
        where {$_.FolderPath -notmatch ".snapshot" -and $_.Name -like "*.vmx" -and !$registered.ContainsKey($_.Name)}
        
        
        # Output unregistered VMs
        if($unregistered){
            $unregistered | %{
                [pscustomobject]@{
                    Name = $_.Name
                    Datastore = $_.Datastore
                    FullPath = $_.DatastoreFullPath
                }
            }
        }

        Remove-PSDrive -Name TgtDS
    }
}