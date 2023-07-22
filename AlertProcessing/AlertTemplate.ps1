<# HTML Cheat sheet

Horizontal separator : <HR size=2 align=center width="100%">
Jump to next line    : <br>
Title levels         : <h1></h1> <h2></h2>
Bold text            : <b></b>

#>

############################################## NOTHING TO CHANGE HERE

. "C:\zts\AlertTools.ps1"

$WarningPreference = "SilentlyContinue"
$Server = 'dca-vcenter'
$FROM = "dca-vcenter@somehost.com"
$SMTP = "mail.replace.me"
$TO = "replace@me.co.uk"


Add-PSSnapin VMware.VimAutomation.Core
$Session = Connect-VIServer -Server $Server


$alertGrabber = AlertGrabber # Grab alert details and generate email HTML header

$AlertBody = $alertGrabber.HTMLHeader

############################################## Collect alert data and prepare e-mail subject

$Subject = "" 

############################################## Build HTML body

$AlertBody += '<br><HR size=2 align=center width="100%"><br>' # Separator

############################################## Send e-mail

Send-MailMessage -Body $AlertBody -From $FROM -SmtpServer $SMTP -Subject $Subject -To $TO -BodyAsHtml
