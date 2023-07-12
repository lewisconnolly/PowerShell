$jobs = get-vbrjob | ? jobtype -eq backup
$copy = get-vbrjob | ? Jobtype -ne 'Backup'

$copy | select name,
@{n='Retain';e={$_.BackupStorageOptions.RetainCycles}},
@{n='TargetRetain';e={$targetid= $_.LinkedJobIds.guid; ($jobs | ? {$_.Id.Guid -eq $targetid}).BackupStorageOptions.RetainCycles}} |
sort name