## Case 1: Failover and failback

    # dcautlprdvbs01 already in Protection Group and assigned corresponding storage policy
    # Failover w/ explicit placement params (-DestinationCluster and -DestinationFolder)
    # Shut down source VM before replica creation and delete afterward
    # Replicate new Protection Group snapshot before failover
    # Prompted for snapshot selection
    # Start replica and change hostname, portgroup, IP and DNS 

    New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01) `
        -ReplicaName 'dcautlprdvbs01r' `
        -ShutdownSourceVmFirst `
        -StartReplicaVm `
        -ReplicaVmHostname 'dcautlprdvbs01r' `
        -DomainJoinCredential $domainJoinCred `
        -ReplicaVmPortgroups (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:2') `
        -ReplicaVmIpDetails '172.30.2.152,255.255.255.0,172.30.2.254' `
        -ReplicaVmDnsServers '172.30.6.136', '172.30.6.137' `
        -DestinationCluster (Get-Cluster DCB-Cluster) `
        -DestinationFolder (Get-Folder Veeam -Location DCB) `
        -LocalAdminCredential $vbs01Cred `
        -SyncProtectionGroup `
        -SourceFlashArrayCredential $faCred `
        -TargetFlashArrayCredential $faCred `
        -RemoveSourceVmPermanently

    # Failback w/ explicit placement params
    # Shut down source VM before replica creation and delete afterward
    # Replicate new Protection Group snapshot before failback
    # Prompted for snapshot selection
    # Start replica and change hostname, portgroup, IP and DNS
    # Using parameter aliases

    New-PureVvolVmReplica -VM (Get-VM dcautlprdvbs01r) `
        -Name 'dcautlprdvbs01' `
        -ShutdownSource `
        -PowerOn `
        -Hostname 'dcautlprdvbs01' `
        -DomainCred $domainJoinCred `
        -Portgroups (Get-VDPortgroup 'DCA-DSw0LAG-DPG-VLAN:2') `
        -IPs '172.31.2.152,255.255.255.0,172.31.2.1' `
        -DNS '172.31.6.136', '172.31.6.137' `
        -Cluster (Get-Cluster DCA-ClusterAMD) `
        -Folder (Get-Folder Veeam -Location DCA) `
        -AdminCred $vbs01Cred `
        -Sync `
        -SourceFaCred $faCred `
        -TargetFaCred $faCred `
        -DeleteSource

## Case 2: Failover w/ automatic placement

    # dcautlprdvbs01 already in Protection Group and assigned corresponding storage policy
    # Replica VM cluster and folder chosen automatically
    # Shut down source VM before replica creation and delete afterward
    # Replicate new Protection Group snapshot before failover
    # Use most recent snapshot
    # Start replica and change hostname, portgroup, IP and DNS

    New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01) `
        -ReplicaName 'dcautlprdvbs01r' `
        -ShutdownSourceVmFirst `
        -StartReplicaVm `
        -ReplicaVmHostname 'dcautlprdvbs01r' `
        -DomainJoinCredential $domainJoinCred `
        -ReplicaVmPortgroups (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:2') `
        -ReplicaVmIpDetails '172.30.2.152,255.255.255.0,172.30.2.254' `
        -ReplicaVmDnsServers '172.30.6.136', '172.30.6.137' `
        -LocalAdminCredential $vbs01Cred `
        -SyncProtectionGroup `
        -MostRecentSnapshot `
        -SourceFlashArrayCredential $faCred `
        -TargetFlashArrayCredential $faCred `
        -RemoveSourceVmPermanently

## Case 3: Quick replica

    # dcautlprdvbs01 already in Protection Group and assigned corresponding storage policy
    # Cluster and folder chosen automatically
    # Register replica VM as 'dcautlprdvbs01_replica' and change portgroup
    # Use most recent snapshot
    # Source VM left as is

    New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01) `
        -RegisterReplicaVm `
        -ReplicaVmPortgroups (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:2') `
        -MostRecentSnapshot `
        -SourceFlashArrayCredential $faCred `
        -TargetFlashArrayCredential $faCred

# Case 4: Failover of VM with more than one network adapter

    # dca-utl-sep already in Protection Group and assigned corresponding storage policy
    # Failover w/ explicit placement params
    # Source VM has two network adapters
    # Shut down source VM before replica creation and remove from inventory afterward
    # Replicate new Protection Group snapshot before failover
    # Prompted for snapshot selection
    # Start replica and change hostname, portgroup, IP and DNS 

    New-PureVvolVmReplica -VM (Get-VM dca-utl-sep) `
        -Name 'dcb-utl-sep' `
        -ShutdownSource `
        -PowerOn `
        -Hostname 'dcb-utl-sep' `
        -DomainCred $domainJoinCred `
        -Portgroups (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:2'), (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:Untagged') `
        -IPs '172.30.2.152,255.255.255.0,172.30.2.254', '172.30.1.15,255.255.255.0' `
        -DNS '172.30.6.136', '172.30.6.137' `
        -Cluster (Get-Cluster DCB-Cluster) `
        -Folder (Get-Folder Veeam -Location DCB) `
        -AdminCred $vbs01Cred `
        -Sync `
        -SourceFaCred $faCred `
        -TargetFaCred $faCred `
        -RemoveSource

# Case 5: Don't register VM (outputs datastore path)

    # dcautlprdvbs01 already in Protection Group and assigned corresponding storage policy
    # Prompted for snapshot selection

    New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01) -SourceFlashArrayCredential $faCred -TargetFlashArrayCredential $faCred