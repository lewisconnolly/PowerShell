$policy = Get-SpbmStoragePolicy -Name $sourcePolicyName -server $sourcevCenter
$sourceGroup = $policy |Get-SpbmReplicationGroup
$repPairs = Get-SpbmReplicationPair -Source $sourceGroup
$targetGroup = $repPairs.Target
start-spbmreplicationpreparefailover -ReplicationGroup $sourceGroup
$vms = start-spbmreplicationfailover -replicationgroup $targetGroup -Confirm:$false
$registeredVms = @()
foreach ($testVm in $vms)
{
    $registeredVms += New-VM -VMFilePath $testVm -ResourcePool $resourcePoolName -Location $folderName
}
foreach ($registeredVm in $registeredVms)
{
    try
    {
        $registeredVm |Start-VM -ErrorAction Stop 
    }
        catch [VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.VMBlockedByQuestionException]
    {
        $registeredVm | Get-VMQuestion |Set-VMQuestion –DefaultOption -Confirm:$false
    } 
}
$targetPolicy = Get-SpbmStoragePolicy -Name $targetPolicyName -Server $targetvCenter
$newSourceGroup = Start-SpbmReplicationReverse -ReplicationGroup $targetGroup
$registeredVms | Set-SpbmEntityConfiguration -StoragePolicy $targetPolicy -ReplicationGroup $newSourceGroup