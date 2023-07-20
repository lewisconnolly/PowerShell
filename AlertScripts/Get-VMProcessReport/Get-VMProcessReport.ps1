. '\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\AlertTools.ps1'
. '\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Join-Object.ps1'
Import-Module "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\ChartFunctions.psm1"

$Server = $env:VMWARE_ALARM_VCENTER
$Log = "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMProcessReport\Get-VMProcessReport.log"
$FROM = "$Server@zonalconnect.com"
$SMTP = "mail.zonalconnect.local"
$TO = "lewis.connolly@zonal.co.uk"
#$TO = "zalerts@zonal.co.uk"
Connect-VIServer -Server $Server
$alertGrabber = AlertGrabber
$UsageType = $alertGrabber.AlertDesc.Substring($alertGrabber.AlertDesc.IndexOf('e')+2,$alertGrabber.AlertDesc.IndexOf("' ")-$alertGrabber.AlertDesc.IndexOf('e')-2)

function Get-VMProcessReport {

    ############################################## Add report note to VM
    
    $Notes = ((get-vm $alertGrabber.AlertedObject).Notes).Split("`n")
    
    #clean up trailing new lines
    $i = -1
    while ($Notes[$i] -eq '') {$i--}
    
    $Notes = $Notes[0..$i]

    $NewNotes = "`n`n$UsageType alert email last sent[$(get-date)]"

    Set-VM -VM ($alertGrabber.AlertedObject) -Notes "$Notes$NewNotes" -Confirm:$false
    
    ############################################## Collect alert data and prepare e-mail subject

    $TopVMProcess = Get-HTMLTopProcessList -AlertedVM $alertGrabber.AlertedObject -Description $alertGrabber.AlertDesc

    Get-HTMLvmPerformanceGraph -AlertedVM $alertGrabber.AlertedObject -Description $alertGrabber.AlertDesc

    $Subject = "$($alertGrabber.AlertedObject.name): $($alertGrabber.AlertStatus) $($alertGrabber.AlertName)"

    ############################################## Build HTML header

    $header += "<head><style>table { border-collapse: collapse;} #inner td, #inner th{font-size: 11px; border: 1px solid #999999; padding: 4px} table th {background-color:#e6e6e6;}</style></head>"
    
    $vmrc = $alertGrabber.AlertedObject | Open-VMConsoleWindow -UrlOnly
         
    $header += "<table cellpadding=`"15`"><tr><td>$((get-date).ToString())<h1><a href=`"$vmrc`" title=`"VM Console link`">$($alertGrabber.AlertedObject.name)</a></h1>"
    
    $header += "<b>$($DefaultVIServer.name.ToUpper()) - $($alertGrabber.AlertedObject.vmhost.name.toLower())</b></td>"

    $header += '<td><ul><li><font color="'

    $header += $env:VMWARE_ALARM_NEWSTATUS
    
    $header += "`"><b>$env:VMWARE_ALARM_TRIGGERINGSUMMARY</b></font></li>"

    $header += "<li>$($env:VMWARE_ALARM_EVENTDESCRIPTION.TrimEnd("'"))</li>"

    $header += "<li>$($env:VMWARE_ALARM_DECLARINGSUMMARY -replace '[([\])]')</li>"

    $header += "<li>NumCpu: <b>$($alertGrabber.AlertedObject.numcpu)</b></li>"
    $header += "<li>Memory: <b>$($alertGrabber.AlertedObject.MemoryGB)GB</b></li>"
    $header += "<li>CpuUsage: <b>$($alertGrabber.AlertedObject.extensiondata.summary.quickstats.OverallCpuUsage)MHz</b></li>"
    $header += "<li>MemoryUsage: <b>$($alertGrabber.AlertedObject.extensiondata.summary.quickstats.GuestMemoryUsage)MB</b></li>"
        
    switch ($alertGrabber.AlertedObject | Get-VMResourceConfiguration)
    {
        {$_.CpuLimitMhz -ne -1} {$header += "<li>CpuLimit: <b>$($_.CpuLimitMhz)MHz</b></li>"}
        {$_.CpuReservationMhz -ne 0} {$header += "<li>CpuReservation: <b>$($_.CpuReservationMhz)MHz</b></li>"}
        {$_.CpuSharesLevel -ne 'Normal'} {$header += "<li>CpuSharesLevel: <b>$($_.CpuSharesLevel)</b></li>"}
        {$_.MemLimitGB -ne -1} {$header += "<li>MemLimit: <b>$($_.MemLimitGB)GB</b></li>"}
        {$_.MemReservationGB -ne 0} {$header += "<li>MemReservation: <b>$($_.MemReservationGB)GB</b></li>"}
        {$_.MemSharesLevel -ne 'Normal'} {$header += "<li>MemSharesLevel: <b>$($_.MemSharesLevel)</b></li>"}
    }

    $header +="</ul></td></tr></table>"

    ############################################## Build HTML body

    $AlertBody += $header

    if ($LastSent){
        $AlertBody +="<br><i>$UsageType report was last sent for $($alertGrabber.AlertedObject.name) on $($LastSent.ToShortDateString()) at $($LastSent.TimeOfDay)</i>"
    }

    $AlertBody += '<HR size=2 align=center width="100%">'

    $AlertBody += "<table cellpadding=`"15`"><tr><td><h2>Last 60 seconds:</td></h2></tr>"

    $AlertBody += "<tr><td valign=`"top`"><center><h2>Process usage*</h2></center><div id=`"inner`">$TopVMProcess</div>* Idle process omitted.</td>"

    $AlertBody += "<td valign=`"top`"><center><h2>Overall $UsageType</h2></center><div id=`"inner`"><img src='PerfChart.png' alt='Performance Chart'></div></td></tr></table>"

    ############################################## Send e-mail

    Send-MailMessage -Body $AlertBody -From $FROM -SmtpServer $SMTP -Subject $Subject -To $TO -BodyAsHtml -Attachments "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMProcessReport\PerfChart.png"
}

#Check alerted VM has Windows OS, is on domain, and report hasn't been sent in last 2 days
if ((($alertGrabber.AlertedObject).ExtensionData.Guest.GuestId -match 'win') -and (($alertGrabber.AlertedObject).ExtensionData.Guest.hostname -match 'zonalconnect.local')){
    
    if (($alertGrabber.AlertedObject).Notes -match "$UsageType alert email"){
        
        $Notes = ($alertGrabber.AlertedObject).Notes
        $ReportNote = $Notes -split "`n" | where {$_ -match "$UsageType alert email"}
        [System.DateTime]$LastSent = $ReportNote.Substring($ReportNote.IndexOf('[')).Trim('[',']')

        if ((New-TimeSpan -Start $LastSent -End (get-date)).Days -gt 2){
        
            $NewNotes = $Notes.Replace($ReportNote,'')
            Set-VM -VM ($alertGrabber.AlertedObject) -Notes $NewNotes -Confirm:$false

            Get-VMProcessReport
            Add-Content $Log -Value "$(get-date)`r`n$($alertGrabber.AlertedObject.name) $UsageType report sent to $TO`r`n"
            Remove-Item \\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMProcessReport\PerfChart.png
            
        } else { Add-Content $Log -Value "$(get-date)`r`n$($alertGrabber.AlertedObject.name) $UsageType report not sent as last sent on $($LastSent.ToShortDateString()) at $($LastSent.TimeOfDay)`r`n" }
    }
    else {
        Get-VMProcessReport
        Add-Content $Log -Value "$(get-date)`r`n$($alertGrabber.AlertedObject.name) $UsageType report sent to $TO`r`n"
        Remove-Item \\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMProcessReport\PerfChart.png
    }
} else { Add-Content $Log -Value "$(get-date)`r`n$($alertGrabber.AlertedObject.name) $UsageType report not sent as non-Windows, not on domain or Guest OS unavailable`r`n" }

