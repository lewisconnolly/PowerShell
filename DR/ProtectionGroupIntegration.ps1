Write-Host -ForegroundColor Cyan "`nEnter credential for vcenter and flash arrays..." 

$lcred = Get-Credential

Write-Host -ForegroundColor Cyan "`nConnecting to vcenter..." 

Connect-VIServer vcenter -Credential $lcred

Write-Host -ForegroundColor Cyan "`nConnecting to flash arrays..." 

'dca-flasharray1', 'dca-flasharray2', 'dcb-flasharray1' | % {
    
    New-PfaConnection -endpoint $_ -credentials $lcred -ignoreCertificateError -nonDefaultArray
}

$pureDatastores = Get-Datastore *PURE*
$protectionGroups = $AllFlashArrays | % { Get-PfaProtectionGroups -Array $_ }

$pureDatastores | % {
    
    $ds = $_
    $dsName = $ds.name
    $datastoreProtectionGroups = $protectionGroups | ? volumes -Contains $dsName | select -ExpandProperty Name -Unique

    $datastoreProtectionGroups | % {

        $pg = $_        
        $tag = get-tag -Name $_ -ErrorAction SilentlyContinue
        $policy = Get-SpbmStoragePolicy | ? Name -eq "[VMDK]$pg"
        $tagAssignment = Get-TagAssignment -Entity $ds | ? { $_.tag.name -eq $pg }

        if(!$tag){

            Write-Host -ForegroundColor Cyan "`nCreating tag for $pg ..."

            $tag = New-Tag -Name $_ -Category pgroups
            
            if(!$tag){  Write-Host -ForegroundColor Yellow "`nFailed to create tag" } else {
                Write-Host -ForegroundColor Green "`nTag created"
            }
        } else { Write-Host -ForegroundColor Cyan "`nTag $( $tag.name ) already exists" }

        if(!$policy){
            
            Write-Host -ForegroundColor Cyan "`nCreating storage policy rule for $pg ..."

            $rule = New-SpbmRule -AnyOfTags $tag

            Write-Host -ForegroundColor Cyan "`nCreating storage policy ruleset for $pg ..."

            $ruleset = New-SpbmRuleSet -AllOfRules $rule               
            
            Write-Host -ForegroundColor Cyan "`nCreating storage policy for $pg ..."

            $policy = New-SpbmStoragePolicy -Name "[VMDK]$_" -AnyOfRuleSets $ruleset -Description 'Flash array protection group policy'

            if(!$policy){ Write-Host -ForegroundColor Yellow "`nFailed to create storage policy" } else {
                Write-Host -ForegroundColor Green "`nStorage policy created"
            }                
        } else { Write-Host -ForegroundColor Cyan "`nStorage policy $( $policy.name ) already exists" }
        
        if(!$tagAssignment){

            if(!$tag){
                
                Write-Host -ForegroundColor Yellow "`nUnable to find $pg tag to assign to $dsName"
            } else { 
                
                Write-Host -ForegroundColor Cyan "`nAssigning $( $tag.name ) to $dsName..."

                $tagAssignment = New-TagAssignment -Entity $ds -Tag $tag
                
                if(!$tagAssignment){ Write-Host -ForegroundColor Yellow "`nFailed to assign tag" } else {
                    Write-Host -ForegroundColor Green "`nTag assigned"
                }
            }
        } else { Write-Host -ForegroundColor Cyan "`nTag $( $tag.name ) already assigned to $dsName" }
    }
}
