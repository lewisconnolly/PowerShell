
# Only do anything if it's the second Wednesday or Thursday after the second Tuesday of the month

if(
    (((Get-Date).Day -ge 17) -and ((Get-Date).Day -le 23) -and ((Get-Date).DayOfWeek -eq 'Thursday')) -or
    (((Get-Date).Day -ge 16) -and ((Get-Date).Day -le 22) -and ((Get-Date).DayOfWeek -eq 'Wednesday'))
){

    function Set-AztecRdgTempIopsLimits {

        Connect-VIServer -Server vcenter | Out-Null
        
        $vms = Get-Folder -Location DCA RDG* | Get-VM -Tag (Get-Tag iops_500,iops_1000,iops_1500)
        #$vms = Get-VM MS-NTT,MS-TOKYOIND

        $vms | % {
            
            $vm = $_

            if($vm | Get-HardDisk){
                            
                if((($vm | Get-VMResourceConfiguration).DiskResourceConfiguration.DiskLimitIOPerSecond | Select-Object -Unique) -ne 2000){
                        
                    Write-Information "$( (Get-Date).ToString() )`tSetting IOPS limit 2000 on all $( $vm.Name ) disks"
                    
                    $vm | Get-VMResourceConfiguration | Set-VMResourceConfiguration -DiskLimitIOPerSecond 2000 -Disk ($vm | Get-HardDisk) |
                    Select-Object VM,
                    @{n='DiskLimitIOPerSecond'; e={($_.DiskResourceConfiguration.DiskLimitIOPerSecond | Select-Object -Unique) -join ', '}}                  

                }

                if((($vm | Get-VMResourceConfiguration).DiskResourceConfiguration.DiskLimitIOPerSecond | Select-Object -Unique) -ne 2000){
                    
                    "$( (Get-Date).ToString() )`tUnable to set IOPS limit 2000 on all disks on $( $vm.Name )" | Write-Warning

                }                
            }        
        }
        
        Disconnect-VIServer vcenter -Confirm:0 -Force | Out-Null
    }

    # Redirect (>&) all streams (*) to the output/success stream (1) to store errors, warnings and information in $tempIopsLimits variable

    $tempIopsLimits = Set-AztecRdgTempIopsLimits *>&1
    $scriptName = $MyInvocation.MyCommand.Name -replace '\.ps1'
    $log = ".\$scriptName.log"    

    if($tempIopsLimits){                
        $objects = @()
        $body = $tempIopsLimits | %{
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
                $objects += $_
            }
        } | Out-String
        "-------------------" | Out-File $log -Append
        
        $messageParameters = @{Subject = "$scriptName task";From = "replace@me.com";To = "replace@me.co.uk";SmtpServer = "mail.replace.me"}
    
        $body += '<br/>'
        $body += $objects | ConvertTo-Html -Fragment | Out-String    
        Send-MailMessage @messageParameters -Body $body -BodyAsHtml -Attachments $log
    }
}