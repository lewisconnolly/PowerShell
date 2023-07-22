############################################## NOTHING TO CHANGE HERE

. "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\AlertTools.ps1"

$WarningPreference = "SilentlyContinue"
$Server = $env:VMWARE_ALARM_VCENTER
$FROM = "dca-vcenter@somehost.com"
$SMTP = "mail.replace.me"
$TO = "replace@me.co.uk"
#$TO = "lewis.connolly@zonal.co.uk"
$Session = Connect-VIServer -Server $Server

$alertGrabber = AlertGrabber # Grab alert details and generate email HTML header

$AlertBody = $alertGrabber.HTMLHeader
$AlertBody = $alertGrabber.HTMLHeader

############################################## Collect alert data and prepare e-mail subject

$TopVM = Get-HTMLTopVMList -Container $alertGrabber.AlertedObject -sort "descending" -nbVM 5

$VMHostGraph = Get-HTMLVMHostGraph -VMhost (get-vmhost)

$Subject = "$($alertGrabber.AlertedObject.name): $($alertGrabber.AlertStatus) $($alertGrabber.AlertName)"

############################################## Build HTML body

$AlertBody += '<br><HR size=2 align=center width="100%"><br>'

$AlertBody += $VMHostGraph

$AlertBody += '<br><HR size=2 align=center width="100%"><br>'

$AlertBody += "<h2>TOP VMs on $($alertGrabber.AlertedObject.name)</h2><br>"

$AlertBody += $TopVM.CPUHtml

$AlertBody += "<br><br>"

$AlertBody += $TopVM.MEMHtml

############################################## Send e-mail

Send-MailMessage -Body $AlertBody -From $FROM -SmtpServer $SMTP -Subject $Subject -To $TO -BodyAsHtml
