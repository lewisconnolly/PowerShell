# Failover

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


# Failback

New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01r) `
    -ReplicaName 'dcautlprdvbs01' `
    -ShutdownSourceVmFirst `
    -StartReplicaVm `
    -ReplicaVmHostname 'dcautlprdvbs01' `
    -DomainJoinCredential $domainJoinCred `
    -ReplicaVmPortgroups (Get-VDPortgroup 'DCA-DSw0LAG-DPG-VLAN:2') `
    -ReplicaVmIpDetails '172.31.2.152,255.255.255.0,172.31.2.1' `
    -ReplicaVmDnsServers '172.31.6.136', '172.31.6.137' `
    -DestinationCluster (Get-Cluster DCA-ClusterAMD) `
    -DestinationFolder (Get-Folder Veeam -Location DCA) `
    -LocalAdminCredential $vbs01Cred `
    -SyncProtectionGroup `
    -SourceFlashArrayCredential $faCred `
    -TargetFlashArrayCredential $faCred `
    -RemoveSourceVmPermanently