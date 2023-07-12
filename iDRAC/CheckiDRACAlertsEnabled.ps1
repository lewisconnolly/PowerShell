$hostsToCheck = 
'zts4-idrac',
'zts9-idrac',
'zts7-idrac',
'zts1-idrac',
'zts6-idrac',
'zts5-idrac',
'zts3-idrac',
'zts2-idrac',
'zhost11-idrac',
'zhost4-idrac',
'zhost18-idrac',
'zhost2-idrac',
'zhost6-idrac',
'zhost26-idrac',
'zhost27-idrac',
'zhost19-idrac',
'zhost5-idrac',
'zhost3-idrac',
'zhost1-idrac',
'zhost10-idrac',
'zhost25-idrac',
'zhost13-idrac',
'zhost12-idrac',
'zhost20-idrac',
'mkhost7-idrac',
'mkhost5-idrac',
'mkhost1-idrac',
'mkhost2-idrac',
'mkhost6-idrac',
'mkhost4-idrac',
'mkhost3-idrac',
'dca-utl-nas2-idrac',
'dcb-utl-nas1-idrac',
'dcb-utl-nas2-idrac',
'dcacmc.zhost',
'mkcmc.zhost'

$hostsToCheck | %{
    
    $u = 'root'
    
    switch ($_)
    {
        {$_ -match 'zts'} {$p = 'Zts+Offb4ND!'}
        {$_ -match 'dcb'} {$u= 'tsuser'; $p = 'Bantha$!'}
        Default {$u = 'root'; $p = 'zh0st1ng'}
    }

    $response = racadm -r $_ -u $u -p $p get idrac.ipmilan.AlertEnable
    $response = $response -split "=" -split "`n"|? {$_ -match '[A-Z]'}
    
    [pscustomobject]@{
        Server = $_
        u = $u
        p = $p
        Setting = $response[-2]
        Value = $response[-1]
    }
}
