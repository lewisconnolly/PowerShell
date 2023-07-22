########################################
### Get-PureProtectionGroupSnapshots ###           
###          lewis.connolly          ###       
########################################

# Creates report of Pure Storage FlashArray Protection Group local and replicated snapshots


function Get-PureProtectionGroupSnapshots {

    param()
    
    $dcafa1 = New-PfaArray -EndPoint dca-flasharray1 -ApiToken '11751e8e-f081-ac4c-903c-2ac4b3d34c53' -IgnoreCertificateError 
    $dcbfa1 = New-PfaArray -EndPoint dcb-flasharray1 -ApiToken 'ecbb1380-e145-2eee-67c4-85e1cdc138a5' -IgnoreCertificateError 
    $dcafa2 = New-PfaArray -EndPoint dca-flasharray2 -ApiToken 'c3ed9cc1-2b75-9b97-34e8-30d8801d32f9' -IgnoreCertificateError 
    $dcbfa2 = New-PfaArray -EndPoint dcb-flasharray2 -ApiToken '3ba70618-1d17-67f6-8c40-8d5deb2aac5f' -IgnoreCertificateError

    $faConnections = @()
    $faConnections += $dcafa1, $dcbfa1, $dcafa2, $dcbfa2

    $faConnections | % {

        $fa = $_
    
        Get-PfaProtectionGroups -Array $_ | % {
        
            Get-PfaProtectionGroupSnapshotReplicationStatus -Array $fa -Name $_.name |
            select @{n='Snapshot';e={$_.name}},
            @{n='ProtectionGroup';e={$_.source}},
            @{n='DataTransferredGB';e={if($_.progress){[math]::Round(($_.data_transferred/1GB),2)}else{'Local snap (not replicated)'}}},
            @{n='SnapshotSizeGB';e={[math]::Round(((Get-PfaProtectionGroupSnapshotSpaceMetrics -Array $fa -Name $_.name).snapshots/1GB),2)}},
            @{n='SourceArray';e={if($_.progress){($_.source -split ':')[0]}else{$fa.Endpoint}}},
            @{n='TargetArray';e={if($_.progress){$fa.Endpoint}else{'Local snap (not replicated)'}}},
            @{n='Created';e={$_.created}},
            @{n='TransferStarted';e={if($_.started){$_.started}else{'Local snap (not replicated)'}}},
            @{n='Completed';e={$_.completed}},
            @{n='TransferProgress%';e={if($_.progress){[math]::Round(($_.progress*100),2)}else{'Local snap (not replicated)'}}},
            @{n='TransferDurationDD:HH:MM:SS';e={
                if($_.progress){
                    $tspan = New-TimeSpan -Start (Get-Date $_.started) -End (Get-Date $_.completed)
                    
                    if("$($tspan.Days)".length -eq 1){$days = "0$($tspan.Days)"}else{$days = "$($tspan.Days)"}
                    if("$($tspan.Hours)".length -eq 1){$hrs = "0$($tspan.Hours)"}else{$hrs = "$($tspan.Hours)"}
                    if("$($tspan.Minutes)".length -eq 1){$mins = "0$($tspan.Minutes)"}else{$mins = "$($tspan.Minutes)"}
                    if("$($tspan.Seconds)".length -eq 1){$secs = "0$($tspan.Seconds)"}else{$secs = "$($tspan.Seconds)"}
    
                    if($tspan.Days -ne 0){"$days`:$hrs`:$mins`:$secs"}elseif($tspan.Hours -ne 0){"$hrs`:$mins`:$secs"}elseif($tspan.Minutes -ne 0){"$mins`:$secs"}else{$secs}
    
                }else{'Local snap (not replicated)'}
            }}
        }
        
    } | sort Completed -Descending

}


### Report Framework

Import-Module PureStoragePowerShellSDK
Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

Get-PureProtectionGroupSnapshots |
ConvertTo-HtmlReport `
    -ReportTitle "Pure Storage Protection Group Snapshots" `
    -ReportDescription "Summary of Protection Group snapshots on Pure Storage FlashArrays" `
    -FilePath "C:\inetpub\Html Reports\pureprotectiongroupsnapshots.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "C:\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "C:\inetpub\wwwroot\index.html" `
    -VirtualPath "/"
