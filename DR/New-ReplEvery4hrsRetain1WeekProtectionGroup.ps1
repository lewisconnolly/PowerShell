function New-ReplEvery4hrsRetain1WeekProtectionGroup {
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String[]]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'dca-flasharray1', 'dca-flasharray2', 'dca-flasharray3',
            'dcb-flasharray1', 'dcb-flasharray2'
        )]
        $SourceArray,

        [Parameter(Mandatory = $true)]
        [pscredential]
        $SourceArrayCredential,

        [Parameter()]
        [ValidateSet(
            'dca-flasharray1', 'dca-flasharray2', 'dca-flasharray3',
            'dcb-flasharray1', 'dcb-flasharray2'
        )]
        $TargetArray,
        
        [Parameter()]
        [switch]
        $EnableReplication
    )

    # Connect to source array
    $array = New-PfaArray -EndPoint ($SourceArray + '.domain.local') -Credentials $SourceArrayCredential -IgnoreCertificateError
    
    $Name | % {        
        
        # Create new Protection Group
        $newPG = New-PfaProtectionGroup -Array $array -Name $_
        
        if($newPG){
            
            # Add target to new Protection Group        
            if($TargetArray){ Set-PfaTargetArrays -Array $array -Name $_ -Targets $TargetArray }

            # Set new PG to replicate every 4hrs
            Set-PfaProtectionGroupSchedule -Array $array -GroupName $_ -ReplicationFrequencyInSeconds 14400

            # Set new PG to retain all snapshots for a week (604800 seconds) and to not retain any after that period
            Set-PfaProtectionGroupRetention -Array $array -GroupName $_ -DefaultRetentionForAllTargetSnapshot 604800 -PostDefaultTargetSnapshotsPerDay 0 -PostDefaultTargetSnapshotRetentionInDays 0         
            
            if($EnableReplication){
                # Enable replication to begin from now
                Enable-PfaReplicationSchedule -Array $array -Name $_
            }

        }else{ "Failed to create Protection Group $_ on $SourceArray" | Write-Warning }
    }
}