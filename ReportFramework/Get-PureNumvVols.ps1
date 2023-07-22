########################
### Get-PureNumvVols ###           
###  lewis.connolly  ###       
########################

# Creates report of number of vVols on Pure Storage FlashArrays

function Get-PureNumvVols {

    param()
    
    $dcafa1 = New-PfaArray -EndPoint dca-flasharray1 -ApiToken '11751e8e-f081-ac4c-903c-2ac4b3d34c53' -IgnoreCertificateError 
    $dcbfa1 = New-PfaArray -EndPoint dcb-flasharray1 -ApiToken 'ecbb1380-e145-2eee-67c4-85e1cdc138a5' -IgnoreCertificateError 
    $dcafa2 = New-PfaArray -EndPoint dca-flasharray2 -ApiToken 'c3ed9cc1-2b75-9b97-34e8-30d8801d32f9' -IgnoreCertificateError 
    $dcbfa2 = New-PfaArray -EndPoint dcb-flasharray2 -ApiToken '3ba70618-1d17-67f6-8c40-8d5deb2aac5f' -IgnoreCertificateError

    $faConnections = @()
    $faConnections += $dcafa1, $dcbfa1, $dcafa2, $dcbfa2

    Connect-VIServer vcenter | Out-Null

    $faConnections | % {

        $fa = $_
        
        $name = ($fa.Endpoint -split '\.')[0]
        $no = $name[-1]
        $dc = $name.Substring(0,3)
        
        $vVolDatastore = Get-Datastore ($dc+'-ssd-vvol-pure'+$no)

        $vVolVms = $vVolDatastore | Get-VM
        $vVolVmDisks = ($vVolVms | Get-HardDisk).count
        $vVolVmSnaps = ($vVolVms | Get-Snapshot).count
        
        $NumVolGroups = (Get-PfaVolumeGroups -Array $fa | ? Name -Like vvol*).count
        $NumvVols = (Get-PfaVolumeGroups -Array $fa | ? Name -Like vvol*).volumes.count
        $NumSnapvVols = ((Get-PfaVolumeGroups -Array $fa | ? Name -Like vvol*).volumes | ? {$_ -match '-snap-'}).count
        
        if(($vVolVms.Count -ge 1800) -or ($NumVolGroups -ge 1800) -or ($NumvVols -ge 9000)){

            if(($vVolVms.Count -ge 1900) -or ($NumVolGroups -ge 1900) -or ($NumvVols -ge 9500)){ $Status = 'Critical' }else{ $Status = 'Warning' }
        
        } else { $Status = "OK" }

        $fa | select @{n='Status';e={$Status}},
        @{n='Array';e={($_.Endpoint -split '\.')[0]}},
        @{n='NumvVolVMs';e={$vVolVms.count}},
        @{n='NumvVolVMDisks';e={$vVolVmDisks}},
        @{n='NumvVolVMSnapshots';e={$vVolVmSnaps}},
        @{n='NumvVolGroups';e={$NumVolGroups}},
        @{n='NumvVols';e={$NumvVols}},
        @{n='NumSnapshotvVols';e={$NumSnapvVols}}    

    } | sort Array
}


### Report Framework

Import-Module PureStoragePowerShellSDK
Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

$ReportContext = "Max # of vVol VMs: 2,000
<br>
Max # of vVol groups: 2,000
<br>
Max # of vVols: 10,000"

Get-PureNumvVols |
ConvertTo-HtmlReport `
    -ReportTitle "Pure Storage Number of vVols" `
    -ReportDescription "Number of vVols per Pure Storage FlashArray" `
    -ReportContext $ReportContext `
    -FilePath "C:\inetpub\Html Reports\purevvols.html" `
    -VirtualPath "reports" `
    -ReportEmail Warning

New-HtmlReportIndex `
    -ReportPath "C:\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "C:\inetpub\wwwroot\index.html" `
    -VirtualPath "/"
