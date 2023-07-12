# Failover

$vm = gvm lc-test6
$srcReplGroup = Get-SpbmReplicationGroup -VM $vm
$tgtReplGroup = Get-SpbmReplicationPair -Source $srcReplGroup | select -ExpandProperty Target
$snapshots = Get-SpbmPointInTimeReplica -ReplicationGroup $tgtReplGroup
$replicaVms = Start-SpbmReplicationFailover -ReplicationGroup $tgtReplGroup -PointInTimeReplica $snapshots[0]

New-VM -Name 'lc-test6_replica' -VMFilePath ($replicaVms | ? {$_ -match 'lc-test6'}) -ResourcePool (Get-Cluster DCB*) -Location (Get-Folder lc -Location DCB)

Start-SpbmReplicationReverse -ReplicationGroup $tgtReplGroup

# Recreate source Protection Group

# Remove unwanted dcautlprdvbs01 vVols

# Rename auto-created target Protection Group

$sp = Get-SpbmStoragePolicy | ? Name -eq '[vVol]TestSvc-Repl8hrsRetain48hrs-NoSnap'

$srcReplGroup = Get-SpbmReplicationGroup | ? Name -eq 'dca-flasharray2:TestSvc-Repl8hrsRetain48hrs-NoSnap'
gvm dcautlprdvbs01 | Get-HardDisk | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $srcReplGroup
gvm dcautlprdvbs01 | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $srcReplGroup
gvm lc-test6 | Get-HardDisk | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $srcReplGroup
gvm lc-test6 | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $srcReplGroup

$tgtReplGroup = Get-SpbmReplicationGroup | ? Name -eq 'dcb-flasharray1:TestSvc-Repl8hrsRetain48hrs-NoSnap'
gvm lc-test6_replica | Get-HardDisk | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $tgtReplGroup
gvm lc-test6_replica | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $tgtReplGroup


# Failback

$vm = gvm lc-test6_replica
$srcReplGroup = Get-SpbmReplicationGroup -VM $vm
$tgtReplGroup = Get-SpbmReplicationPair -Source $srcReplGroup | select -ExpandProperty Target
$snapshots = Get-SpbmPointInTimeReplica -ReplicationGroup $tgtReplGroup

gvm lc-test6 | Remove-VM -DeletePermanently

# Create new PG snapshot

$replicaVms = Start-SpbmReplicationFailover -ReplicationGroup $tgtReplGroup -PointInTimeReplica $snapshots[0]

New-VM -Name 'lc-test6' -VMFilePath $replicaVms -ResourcePool (Get-Cluster *AMD) -Location (Get-Folder lc -Location DCA)

Start-SpbmReplicationReverse -ReplicationGroup $tgtReplGroup

gvm lc-test6_replica | Remove-VM -DeletePermanently

# Remove source Protection Group

$tgtReplGroup = Get-SpbmReplicationGroup | ? Name -eq 'dca-flasharray2:TestSvc-Repl8hrsRetain48hrs-NoSnap'
gvm lc-test6 | Get-HardDisk | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $tgtReplGroup
gvm lc-test6 | Get-SpbmEntityConfiguration | Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $tgtReplGroup

# Clean up auto-created target Protection Group

