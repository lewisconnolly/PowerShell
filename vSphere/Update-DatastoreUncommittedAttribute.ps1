function Update-DatastoreUncommittedAttribute($Datastores, $GetOnly)
{
    if(!$GetOnly)
    {
        $dsUncommitted = get-datastore $Datastores | select name,type,capacitygb,
        @{n='Committed';e={
            ($_|get-vm|measure provisionedspacegb -Sum).sum
        }} |select name,type,
        @{n='Uncommitted';e={
            [math]::Round($_.CapacityGB - $_.Committed)
        }}

        $dsUncommitted | ? type -ne 'NFS' | ? type -ne 'VVOL' | % {

            $datastoreView = Get-View -ViewType Datastore -Property Name -Filter @{"name"=$_.Name}

            $datastoreView.setCustomValue("UncommittedGB","$($_.Uncommitted)")
        }
    }
    
    $dsUncommittedCustomAtt = $Datastores | ? type -ne 'NFS' | ? type -ne 'VVOL' | select name,
    @{n='UncommittedGB';e={
        [int]($_.ExtensionData.customvalue |? key -eq 401).value
    }}

    $Log = ".\Update-DatastoreUncommittedAttribute.log"

    Add-Content $Log `
    -Value "$(get-date)---------------------------------------------------------------------------`r`n"

    if(!$GetOnly)
    {
        Add-Content $Log `
        -Value "Datastore custom attribute 'UncommittedGB' has been updated"
    }
    
    Add-Content $Log -Value ($dsUncommittedCustomAtt | Out-String)

    #Send-MailMessage -Body ($dsUncommittedCustomAtt | ? UncommittedGB -le 100 | ConvertTo-Html -Fragment|Out-String)`
    #-BodyAsHtml -From 'UncommittedGBReport@dcautlprdwrk01.zonalconnect.local' -SmtpServer 'mail.zonalconnect.local'`
    #-Subject 'UncommittedGBReport' -To 'lewis.connolly@zonal.co.uk'
}

Connect-VIServer -Server vcenter 3>&1 | Out-Null

Update-DatastoreUncommittedAttribute -Datastores (get-datastore) -GetOnly $false