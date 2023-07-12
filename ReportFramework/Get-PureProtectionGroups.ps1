##################################
### Get-PureProtectionGroups   ###           
### lewis.connolly@zonal.co.uk ###       
##################################

# Creates report of Pure Storage FlashArray Protection Groups returned by Get-PfaProtectionGroups

function ConvertFrom-Seconds ($InputObject){
    
    $output = ''
    
    if($InputObject % 86400){

        $remsecs = $InputObject % 86400

        if(($InputObject - $remsecs) -ne 0){ $output += "$(($InputObject - $remsecs) / 86400)d" }

        if($remsecs % 3600){

            $newremsecs = $remsecs % 3600
            
            if(($remsecs - $newremsecs) -ne 0){ $output += "$(($remsecs - $newremsecs) / 3600)h" }

            if($newremsecs % 60){

                $newnewremsecs = $newremsecs % 60

                if(($newremsecs - $newnewremsecs) -ne 0){ $output += "$(($newremsecs - $newnewremsecs)/60)m" }

                $output += "$($newnewremsecs)s"
            
            }else{ $output += "$($newremsecs / 60)m" }

        }else{ $output += "$($remsecs / 3600)h" }
        
    }else{ $output += "$($InputObject / 86400)d" }
    
    $output
}

function Get-PureProtectionGroups {

    param()
    
    $dcafa1 = New-PfaArray -EndPoint dca-flasharray1 -ApiToken '11751e8e-f081-ac4c-903c-2ac4b3d34c53' -IgnoreCertificateError 
    $dcbfa1 = New-PfaArray -EndPoint dcb-flasharray1 -ApiToken 'ecbb1380-e145-2eee-67c4-85e1cdc138a5' -IgnoreCertificateError 
    $dcafa2 = New-PfaArray -EndPoint dca-flasharray2 -ApiToken 'c3ed9cc1-2b75-9b97-34e8-30d8801d32f9' -IgnoreCertificateError 
    $dcbfa2 = New-PfaArray -EndPoint dcb-flasharray2 -ApiToken '3ba70618-1d17-67f6-8c40-8d5deb2aac5f' -IgnoreCertificateError

    $faConnections = @()
    $faConnections += $dcafa1, $dcbfa1, $dcafa2, $dcbfa2

    $faConnections | % {

        $fa = $_

        Get-PfaProtectionGroups -Array $fa | ? name -NotMatch default | ? source -eq $fa.Endpoint |
            select Name,
            Source,
            @{n='Target';e={$_.targets.name -join ", "}},
            @{n='LocalSnapsEnabled';e={(Get-PfaProtectionGroupSchedule -ProtectionGroupName $_.name -Array $fa).snap_enabled}},
            @{n='ReplSnapsEnabled';e={(Get-PfaProtectionGroupSchedule -ProtectionGroupName $_.name -Array $fa).replicate_enabled}},
            @{n='NumVols';e={$_.volumes.count}},
            @{n='NumLocalSnaps';e={(Get-PfaProtectionGroupSnapshots -Array $fa -Name $_.name | measure).count}},
            @{n='LocalSnapTotalSizeGB';e={[math]::Round(((Get-PfaProtectionGroupSnapshotSpaceMetrics -Array $fa -Name $_.name).snapshots | measure -sum).sum/1GB,2)}},
            @{n='NumReplSnaps';e={
                $targ = $_.targets.name
                (Get-PfaProtectionGroupSnapshots -Array ($faConnections | ? endpoint -eq $targ) -Name ($_.source + ':' + $_.name) | measure).count
            }},
            @{n='ReplSnapTotalSizeGB';e={
                $targ = $_.targets.name
                [math]::Round(((Get-PfaProtectionGroupSnapshotSpaceMetrics -Array ($faConnections | ? endpoint -eq $targ) -Name ($_.source + ':' + $_.name)).snapshots | measure -sum).sum/1GB,2)
            }},
            @{n='LocalSnapRetention';e={ConvertFrom-Seconds (Get-PfaProtectionGroupRetention -ProtectionGroupName $_.name -Array $fa).all_for}},
            @{n='ReplSnapRetention';e={ConvertFrom-Seconds (Get-PfaProtectionGroupRetention -ProtectionGroupName $_.name -Array $fa).target_all_for}},
            @{n='LocalSnapSchedule';e={ConvertFrom-Seconds (Get-PfaProtectionGroupSchedule -ProtectionGroupName $_.name -Array $fa).snap_frequency}},
            @{n='ReplSnapSchedule';e={ConvertFrom-Seconds (Get-PfaProtectionGroupSchedule -ProtectionGroupName $_.name -Array $fa).replicate_frequency}}
    } | sort Source    

}


### Report Framework

Import-Module PureStoragePowerShellSDK
Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

Get-PureProtectionGroups |
ConvertTo-HtmlReport `
    -ReportTitle "Pure Storage Protection Groups" `
    -ReportDescription "Summary of Protection Groups (asynchronous replication) on Pure Storage FlashArrays" `
    -FilePath "C:\inetpub\Html Reports\pureprotectiongroups.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "C:\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "C:\inetpub\wwwroot\index.html" `
    -VirtualPath "/"
