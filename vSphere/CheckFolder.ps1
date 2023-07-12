function Check-Folder ($Paths) {
    $pathsandfolders = @()
    foreach ($path in $paths) {
        $originalpath = $path
        $splitpaths = $path.Split('\')
        $fldrnames = $splitpaths[2..$splitpaths.count]
        $fldrnames = $fldrnames -replace ' ',''
        $command = 'Get-Folder -Name vm -server vcenter -location TF'
        $continue=$true

        if(($fldrnames -contains 'Graylog')-or(($fldrnames -contains 'RabbitMQ')-and ($fldrnames.count -le 2))){$fldrnames = $fldrnames -replace 'NonProd','CoreServices'}
        if($fldrnames -contains 'zonalconnect.test'){$fldrnames = @('Utility','DMZ')}
        if(($fldrnames -contains 'zabbix')-or($fldrnames -contains 'F5')-or($fldrnames -contains 'SteelApp')){$fldrnames = $fldrnames -replace 'Utility','CoreServices'}
        if(($fldrnames -contains 'Test')){
            $newfldrnames = @('NB')
            $fldrnames | % {$newfldrnames += $_}
            $fldrnames = $newfldrnames
        }

        $fldrnames | %  {
            if($continue){
                $parid = (Invoke-Expression $command -ErrorAction SilentlyContinue).id
                $test = $command + "| Get-Folder -Name '$_' -ErrorAction SilentlyContinue | ? Parentid -eq '$parid'"
                $result = Invoke-Expression $test -ErrorAction SilentlyContinue
                if($result){
                    $command = $test
                }else{
                    switch ($test){
                        {$_ -match 'ElasticSearch'} {$test = $test -replace 'ElasticSearch','es'}
                        {$_ -match 'ServiceFabric'} {$test = $test -replace 'ServiceFabric','sf'}
                        {$_ -match 'Load'} {$test = $test -replace 'Load','ld'}
                        {$_ -match 'Staging'} {$test = $test -replace 'Staging','stg'}
                        {$_ -match 'UAT-qa03'} {$test = $test -replace 'UAT-qa03','uat'}
                        {$_ -match 'Zookeeper'} {$test = $test -replace 'Zookeeper','zoo'}
                        {$_ -match 'Kafka'} {$test = $test -replace 'Kafka','kfk'}
                        {$_ -match 'gg-test'} {$test = $test -replace 'gg-test','gg'}
                        {$_ -match 'wm-test'} {$test = $test -replace 'wm-test','wm'}
                        {$_ -match 'nc-test'} {$test = $test -replace 'nc-test','nc'}
                        {$_ -match 'kp-test'} {$test = $test -replace 'kp-test','kp'}
                        {$_ -match 'RabbitMQ'} {$test = $test -replace 'RabbitMQ','rmq'}
                        {$_ -match 'MongoDB'} {$test = $test -replace 'MongoDB','mgodb'}
                        {$_ -match 'CampaignPlus'} {$test = $test -replace 'CampaignPlus','CampaignsPlus'}
                        {$_ -match 'dev01-Tables2'} {$test = $test -replace 'dev01-Tables2','dev01'}
                    }
                    $result = Invoke-Expression $test -ErrorAction SilentlyContinue
                    if($result) {$command = $test}else{$continue = $false}
                }
            }
        }
        $pathandfolder = @{$originalpath = Invoke-Expression $command}
        $pathsandfolders += $pathandfolder
    }
    $pathsandfolders
}