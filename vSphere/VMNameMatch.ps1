$VMs = gvm -Location DCA

$matchingVMs = @()

$VMs.Name | % {

    switch ($_)
    {
        {$_ -match 'admin'} {
        
            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = 'n/a'
                type = 'n/a'
                match = '1'
            }
            
            break
        }

        {($_ -notmatch '[0-9]') -and ($_ -notmatch '-')} {
            
            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = 'n/a'
                type = 'n/a'
                match = '2'
            }
            
            break
        }

        {$_ -like "*-STA02*"} {
        
            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = 'UTL'
                type = 'STA'
                match = '3'
            }
            
            break
        }

        
        {$_ -like "*glogprd*"} {
            
            $type = $_ -replace 'dcaglogprd','' -replace '[0-9]',''

            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = 'GLOGPRD'
                type = $type
                match = '3'
            }
            
            break
        }

         {$_ -like "*isrvprd*"} {
            
            $type = $_ -replace 'isrvprd','' -replace '[0-9]',''

            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = 'ISRVPRD'
                type = $type
                match = '3'
            }
            
            break
        }

        {$_ -like "MS-*"} {
        
            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = 'n/a'
                type = 'n/a'
                match = '3'
            }
            
            break
        }

        {$_ -like "txd-hosting-php-web*"} {
            
            $prd = 'TXD'
            $type = 'WEB'

            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = $prd
                type = $type
                match = '4'
            }

            break
        }
        
        {($_ -match '[0-9]') -and ($_ -notmatch '-')} {
            
            $prd = $_.Substring(3,6)
            $type = ($_.Substring(9,($_.Length-10))) -replace '[0-9]',''
            
            if($type -like "*N"){$type = $type.Substring(0,($type.Length-1))}

            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = $prd
                type = $type
                match = '5'
            }

            break
        }

        {($_ -match '[0-9]') -and ($_ -match '-') -and ($_ -notmatch '\.')} {
            
            $prd = ($_ -split '-')[1]
            $type = ($_ -split '-')[-1] -replace '[0-9]',''
            
            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = $prd
                type = $type
                match = '6'
            }

            break
        }

        {$_ -like "dca-mtgw-*-*"} {

            $prd = ($_ -split '-')[1]
            $type = ($_ -split '-')[-2]+($_ -split '-')[-1]
            
            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = $prd
                type = $type
                match = '7'
            }

            break
        }

        

        {$_ -match '[\.]'} {
            
            $prd = (($_ -split '\.')[0] -replace 'dca-','') -replace '[0-9]',''
            $type = (($_ -split '\.')[1]+'.'+($_ -split '\.')[-1])
            
            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = $prd
                type = $type
                match = '9'
            }

            break
        }

        Default {
        
            $matchingVMs+=
            [pscustomobject]@{
                name = $_
                prd = 'no match'
                type = 'no match'
                match = 'no match'
            }

            break
        }
    }
}

$matchingVMs |
? {($_.type -notmatch 'n/a|no match') -and ($_.prd -notmatch 'n/a|no match')} |
select name,@{n='rule';e={($_.prd + '-' + $_.type).ToUpper()}}|
group rule |
? count -gt 1|
select @{n='RuleName';e={$_.Name}},Count,@{n='VMs';e={($_.group.name|sort) -join ', '}}|
sort rulename|
Export-Excel .\PossibleAntiAffinityRules1.xlsx