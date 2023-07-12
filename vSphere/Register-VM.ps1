function Register-VM ($VMNames, $Datastore, $VMHost, $Folder, $Server) {

    foreach($VMName in $VMNames) {
        # Collect .vmx paths of registered VMs on the datastore
        $registered = @{}
        Get-VM -Datastore $Datastore | %{$_.Extensiondata.LayoutEx.File | where {$_.Name -like "*.vmx"} | %{$registered.Add($_.Name,$true)}}
        # Set up Search for .VMX File in Datastore
        New-PSDrive -Name TgtDS -Location $Datastore -PSProvider VimDatastore -Root '\' | Out-Null
        $VMXFile = Get-ChildItem -Path TgtDS: -Recurse | `
        where {$_.FolderPath -notmatch ".snapshot" -and $_.Name -eq "$VMName.vmx" -and !$registered.ContainsKey($_.Name)}
        
        #Register .vmx file as VMs on the datastore
        New-VM -VMFilePath $VMXFile.DatastoreFullPath -VMHost $VMHost -Location $Folder -Server $Server 
        Remove-PSDrive -Name TgtDS
    }
}