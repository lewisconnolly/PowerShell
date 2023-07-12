$datacenter = 'dca'

$envandtype = gvm -Location $datacenter| select name,
@{n='env';e={
    if($_.name -notmatch '-')
    {
        [regex]$patn = "(($datacenter[a-z]{3,4})(prd|tst))"
        $env = $_.name.tolower()
        $env = $patn.Matches($env).value -replace $datacenter,''
        
        if($env)
        {
            $env.ToUpper()
        }
        else
        {
            'N/A'
        }
    }
    elseif($_.name -match '-')
    {
        if($_.name -match 'sta')
        {
            'STA'
        }
        elseif($_.name -match '\.')
        {
            [regex]$patn = "-[A-Za-z]+[0-9]+\."
            

        }

        else
        {
            $env = ($_.name -split '-')[1]
            $env.ToUpper()
        }
    }
}},
@{n='type';e={
    if($_.name -notmatch '-')
    {
        [regex]$patn = "(($datacenter[a-z]{3,4})(prd|tst))"
        $env = $_.name.tolower()
        $env = $patn.Matches($env).value
        if($env -ne $null){
            $type = $_.name -replace $env,''
            $type = $type -replace '[0-9]',''        

            if($type[$type.length-1] -eq 'n')
            {
                $type.substring(0,($type.length-1)).toupper()
            }
            else{$type.toupper()}
        }
        else
        {
            'N/A'
        }
    }
    elseif($_.name -match '-')
    {
        if($_.name -notmatch ".+[0-9]{1,2}")
        {
            [regex]$patn = '-[A-Za-z]{2,7}$'
            $type = $patn.Matches($_.name).value
            $type = $type -replace '-',''
            $type.toupper()
        }
        else
        {
            [regex]$patn = '[A-Za-z]{2,7}[0-9]{1,2}'
            $type = $patn.Matches($_.name).value
            $type = $type -replace '[0-9]',''
            $type.toupper()
        }
    }
}} | sort name

$envandtype
<#
$ruleandvms = $envandtype | ? type -match '[A-Za-z]' | group env | %{
    
    $env = $_.Name
    
    $_.Group | group type | % {
        
        $type = $_.name

        if($_.group.count -gt '1')
        {
            $vms = gvm $_.group.name
            
            [pscustomobject]@{
                Name= "$datacenter-Separate-$env-$type"
                VMs = $vms
            }
        }
    }
}
 
$exclude = 'DCB-Separate-UTL-DC
DCB-Separate-UTL-MTA
DCB-Separate-MABPRD-SQL
DCB-Separate-F5-BIP-T
DCB-Separate-UTL-RDL
DCB-Separate-surveyor-web
DCB-Separate-surveyor-task
DCB-Separate-surveyor-rabbitmq
'

$trimexclude = @()
$exclude -split "`n"| % {
    $trimexclude += $_.trim()
}

$rulestocreate = $ruleandvms | ? name -notin $trimexclude

$rulestocreate | % {
    $rulename = $_.name
    $rulename = $_.name -replace 'dcb','DCB'
    if($_.name -match 'ISRVPRD|UTLPRD'){
        $rulename = $_.name -replace 'PRD',''
    }
    ""
    ""
    $rulename
    ""
    $_.VMs
    ""
    New-DrsRule -Name $rulename -Cluster DCB* -Enabled $true -KeepTogether $false -VM $_.VMs -WhatIf
} 
#>