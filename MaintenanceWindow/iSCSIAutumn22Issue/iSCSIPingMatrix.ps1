
$cred = Get-Credential -Message 'Enter domain.local credential'
$iscsiHosts = Import-Excel -Path (Read-Host -Prompt 'Enter path of iSCSI hosts spreadsheet')
$resultsSheet = Read-Host -Prompt 'Enter path of iSCSI results spreadsheet'
$tested = @()
$count = 3

function EnterResult {
    param (
        $excelPkg,
        $target,
        $curHost,
        $result
    )
    
    $cellWithCorrectColumn = ($excelPkg.Sheet1.Cells | ? Value -eq $target)[0].Address
    $cellWithCorrectRow = ($excelPkg.Sheet1.Cells | ? Value -eq $curHost)[1].Address

    [regex]$ptrn = '[A-Z]+'
    $column = $ptrn.Match($cellWithCorrectColumn).Value

    [regex]$ptrn = '[0-9]+'
    $row = $ptrn.Match($cellWithCorrectRow).Value

    Set-ExcelRange -Range $excelPkg.Sheet1.Cells[$column + $row] -Value $result
}

$iscsiHosts | ? Name -NotMatch 'zrds-hsan' | % {
    
    $excelPkg = Open-ExcelPackage -Path $resultsSheet
    
    $curHost = $_.Name
    $curHostIP = $_.IP
    $curHostParent = ($curHost -split ' ')[0]
    $tested += $curHost

    switch -Regex ($curHost) {
        'zhost'     {
                        $esxcli = Get-EsxCli -V2 -VMHost ($curHostParent + '.zhost')
                        
                        $iscsiHosts | ? {($_.Name -split ' ')[0] -ne $curHostParent} | ? Name -NotIn $tested | % {
                            
                            $result = ' '                                                        
                            $target = $_.Name

                            $params = $esxcli.network.diag.ping.CreateArgs()
                            $params.ipv4 = $true                                                
                            $params.host = $_.IP
                            $params.count = $count
                            
                            if($curHost -match 'iscsi1'){
                                $params.interface = 'vmk1'
                            }elseif($curHost -match 'iscsi2'){
                                $params.interface = 'vmk2'
                            }else{
                                $params.interface = 'vmk3'
                                $params.netstack = 'vmotion'
                            }
                            
                            try{
                                $ping = $esxcli.network.diag.ping.Invoke($params) | select -ExpandProperty summary
                                $result = "{0}% loss" -f $ping.PacketLost
                            }
                            catch [VMware.VimAutomation.Sdk.Types.V1.ErrorHandling.VimException.MethodFault]{
                                if($_.Exception.Message -match 'sendto\(\) failed \(Host is down\)'){
                                    $result = "100% loss"
                                }
                            }
                            
                            EnterResult -excelPkg $excelPkg -target $target -curHost $curHost -result $result
                        }
                    }

        'vbp|nas'   {
                        $vm = Get-VM $curHostParent
                        
                        $iscsiHosts | ? {($_.Name -split ' ')[0] -ne $curHostParent} | ? Name -NotIn $tested | % {
                            
                            $result = ' '
                            $target = $_.Name

                            $ping = Invoke-VMScript -ScriptText "ping $( $_.IP ) -S $curHostIP -n $count -w 2500" -VM $vm -GuestCredential $cred -ScriptType Powershell
                            $result = (($ping.ScriptOutput -split "`n" | ? {$_ -match 'lost'}) -split '\(')[1] -replace '\),'

                            EnterResult -excelPkg $excelPkg -target $target -curHost $curHost -result $result
                        }                        
                    }

        'fa'       {
                        if($curHost -match 'fa1'){ $array = 'dca-flasharray1.domain.local' }else{ $array = 'dca-flasharray2.domain.local' }

                        $SSHSession = New-SSHSession -ComputerName $array -Credential $cred -AcceptKey 

                        $iscsiHosts | ? {($_.Name -split ' ')[0] -ne $curHostParent} | ? Name -NotIn $tested | % {
                            
                            $result = ' '
                            $target = $_.Name

                            $command = "purenetwork eth ping --count $count --interface $curHostIP --no-hostname $( $_.IP )"
                            $ping = Invoke-SSHCommand -SSHSession $SSHSession -Command $command
                            
                            if($ping.Output){
                                $result = (($ping.Output -split "`n" | ? {$_ -match 'loss'}) -split ',')[-2].Trim() -replace 'packet '
                            }elseif($ping.Error){
                                $result = (($ping.Error -split "`n" | ? {$_ -match 'loss'}) -split ',')[-2].Trim() -replace 'packet '
                            }else{
                                $result = 'no result'
                            }
                            
                            EnterResult -excelPkg $excelPkg -target $target -curHost $curHost -result $result
                        }

                        Remove-SSHSession -SessionId $SSHSession.SessionId | Out-Null
                    }
    }
    
    Export-Excel -ExcelPackage $excelPkg

}