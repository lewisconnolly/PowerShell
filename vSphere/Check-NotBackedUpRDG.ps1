function Check-NotBackedUpRDG {
    Connect-VIServer -Server vcenter | Out-Null

    $backupTagAssignments = Get-TagAssignment -Category backup -ErrorAction Ignore
    $backedUpRdgs = ($backupTagAssignments|? {$_.tag.name -match 'rdg'}).entity.name
    $rdgs = get-folder rdg-ad -Location dca | get-vm | select name

    $backupTagAssignments | group tag | select count,name | sort count | % {
        Write-Information -MessageData ($_.name + ' has ' + $_.count + ' VMs')
    }
    
    compare $rdgs.name  $backedUpRdgs | select InputObject,
    @{n='PowerState';e={(get-vm $_.inputobject | select powerstate).powerstate}},
    @{n='Status';e={
        $name = $_.inputobject
        if($_.sideindicator -eq '=>'){
            'Stop backing up or wrong folder.' + ' Tag: ' + ($backupTagAssignments | ? {$_.entity.name -eq $name}).tag.name
        }else{'Should be backed up'}
    }},
    @{n='Folder';e={(get-vm $_.inputobject).folder.name}} | sort Status

    Disconnect-VIServer vcenter -Confirm:0 -Force | Out-Null
}

# Redirect (>&) all streams (*) to the output/success stream (1) to store errors, warnings and information in $rdgToBeBackedUp variable
$rdgToBeBackedUp = Check-NotBackedUpRDG *>&1
$scriptName = $MyInvocation.MyCommand.Name -replace '\.ps1'
$log = ".\$scriptName.log" 

# If there are any RDG VMs to be tagged/untagged or errors or warnings then log and mail
if($rdgToBeBackedUp | ? {$_ -notlike "backup/rdgjob* has * VMs"}){        
    "-------------------" | Out-File $log -Append
    $objects = @()
    $body = $rdgToBeBackedUp | %{
        if($_.WriteWarningStream){
            $_.Message | Out-File $log -Append
            '<font color="#e77f00">' + $_.Message + '</font><br/>'
        } elseif($_.WriteErrorStream){
            $_.Exception | Out-File $log -Append
            '<font color="red">' + $_.Exception + '</font><br/>'
        } elseif($_.WriteInformationStream){
            $_.MessageData | Out-File $log -Append
            $_.MessageData + '<br/>'
        } else {
            $_.InputObject + " :: " + $_.PowerState + " :: " + $_.Status + " :: " + $_.Folder | Out-File $log -Append
            $objects += $_
        }
    } | Out-String
    
    $messageParameters = @{Subject = "$scriptName task";From = "ztsreports@zonalconnect.com";To = "lewis.connolly@zonal.co.uk";SmtpServer = "mail.zonalconnect.local"}
    $body += '<br/>'
    $body += $objects | ConvertTo-Html -Fragment | Out-String    
    Send-MailMessage @messageParameters -Body $body -BodyAsHtml -Attachments $log    
}