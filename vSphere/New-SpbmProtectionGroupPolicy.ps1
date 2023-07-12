function New-SpbmProtectionGroupPolicy {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String[]]
        $Name
    )
 
    $Name | % {
        # Create rule that specifies Protection Group requirement
    
        $rule1 = New-SpbmRule -Capability 'com.purestorage.storage.replication.ReplicationConsistencyGroup' -Value $_
    
        # Create rule requiring VM to be stored on Pure Storage FlashArray
    
        $rule2 = New-SpbmRule -Capability 'com.purestorage.storage.policy.PureFlashArray' -Value $true
    
        # Add rules to ruleset and create storage policy
    
        $ruleset = New-SpbmRuleSet -AllOfRules $rule1, $rule2
        New-SpbmStoragePolicy -Name $_ -AnyOfRuleSets $ruleset
    }
}