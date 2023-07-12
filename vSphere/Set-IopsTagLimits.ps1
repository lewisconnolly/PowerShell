function Set-IopsTagLimits {

    Connect-VIServer -Server vcenter | Out-Null
    
    $vms = Get-Tag -Name "iops_*" | ? Name -NotMatch 'notalldisks' | % {
        $tag = $_
        Get-VM -Tag $tag | select Name,Id,@{n='Tag';e={$tag}}
    } | Group Name

    $vms | % {
        
        $tag = $_.Group.Tag
        $vm = Get-VM -Id $_.Group.Id

        if($_.Count -eq 1){        
            
            if($tag.name -eq "iops_unlimited") {
                $limit = -1
            } else {
                $limit = (($tag.name).Trim("iops_"))
            }
                                    
            if($vm | Get-HardDisk){
                
                #if(($vm.PowerState -eq 'PoweredOff') -or ((($vm | Get-Datastore).type | Select-Object -Unique) -eq 'VMFS') -or (($vm | Get-HardDisk).count -eq 1)){
                if((($vm | Get-VMResourceConfiguration).DiskResourceConfiguration.DiskLimitIOPerSecond | Select-Object -Unique) -ne $limit){
                        
                    Write-Information "$( (Get-Date).ToString() )`tSetting IOPS limit $limit on all $( $vm.Name ) disks"
                    
                    $vm | Get-VMResourceConfiguration | Set-VMResourceConfiguration -DiskLimitIOPerSecond $limit -Disk ($vm | Get-HardDisk) |
                    Select-Object VM,
                    @{n='Tag';e={$tag.name}},
                    @{n='DiskLimitIOPerSecond'; e={($_.DiskResourceConfiguration.DiskLimitIOPerSecond | Select-Object -Unique) -join ', '}}                  

                }
                #}

                # Check if limits applied successfully and add/or remove iops_notalldisks tag
                # Check is outside block where limit is set to catch:
                # 1) VMs with iops_notalldisks tag that were fixed manually
                # 2) VMs with iops_notalldisks tag that were fixed by above command
                # 3) VMs without iops_notalldisks tag that above command failed to fix

                if((($vm | Get-VMResourceConfiguration).DiskResourceConfiguration.DiskLimitIOPerSecond | Select-Object -Unique) -ne $limit){
                    
                    "$( (Get-Date).ToString() )`tUnable to set IOPS limit $limit on all disks on $( $vm.Name )" | Write-Warning

                    if((Get-TagAssignment -Entity $vm -Category iops).Tag.Name -notcontains 'iops_notalldisks'){
                        Write-Information "$( (Get-Date).ToString() )`tAssigning iops_notalldisks tag to $( $vm.Name )"                        
                        New-TagAssignment -Tag (Get-Tag 'iops_notalldisks') -Entity $vm -Confirm:0 | Out-Null
                    }
                } else {
                    if((Get-TagAssignment -Entity $vm -Category iops).Tag.Name -contains 'iops_notalldisks'){
                        Write-Information "$( (Get-Date).ToString() )`Removing iops_notalldisks tag from $( $vm.Name )"                        
                        Get-TagAssignment -Entity $vm -Category iops | ? {$_.Tag.Name -eq 'iops_notalldisks'} | Remove-TagAssignment -Confirm:0 | Out-Null
                    }    
                }                
            }                        
        } elseif($_.group.tag.name -contains 'iops_excluded') {
            Write-Information "$( (Get-Date).ToString() )`tSkipping $( $vm.Name ) because it is tagged 'iops_excluded'. VM has probably been excluded due to a recurring error when applying IOPS limit and should be investigated."
        } else {
            "$( (Get-Date).ToString() )`t$( $vm.Name ) has several IOPS tags ($( $tag.Name -join ', ' )). Skipping automated setting of limits" | Write-Warning                         
        }   
    }
    Disconnect-VIServer vcenter -Confirm:0 -Force | Out-Null
}

# Redirect (>&) all streams (*) to the output/success stream (1) to store errors, warnings and information in $newIopsLimits variable

$newIopsLimits = Set-IopsTagLimits *>&1
$scriptName = $MyInvocation.MyCommand.Name -replace '\.ps1'
$log = ".\$scriptName.log" 

if($newIopsLimits){        
    "-------------------" | Out-File $log -Append
    $objects = @()
    $body = $newIopsLimits | %{
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
    
    $messageParameters = @{Subject = "Set-IopsTagLimits task";From = "ztsreports@zonalconnect.com";To = "zts@zonal.co.uk";SmtpServer = "mail.zonalconnect.local"}
    #$messageParameters = @{Subject = "$scriptName task";From = "ztsreports@zonalconnect.com";To = "lewis.connolly@zonal.co.uk";SmtpServer = "mail.zonalconnect.local"}
    $body += '<br/>'
    $body += $objects | ConvertTo-Html -Fragment | Out-String    
    Send-MailMessage @messageParameters -Body $body -BodyAsHtml -Attachments $log    
}

