$VMXTs = foreach($Datastore in (Get-datastore -Location TF)) {
    
    New-PSDrive -Name TgtDS -Location $Datastore -PSProvider VimDatastore -Root '\' | Out-Null
    $VMXFile = Get-ChildItem -Path TgtDS: -Recurse | `
    where {$_.FolderPath -notmatch ".snapshot" -and $_.Name -like "*.vmtx"}    
    $VMXFile
    Remove-PSDrive -Name TgtDS
}    