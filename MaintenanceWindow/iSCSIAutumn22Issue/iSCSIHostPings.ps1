$iscsiHosts = Import-Excel -Path C:\Users\lewisc\Desktop\iSCSITests\iscsi_hosts.xlsx


$iscsiHosts | ? Name -like sg* | % {

    $excelPkg = Open-ExcelPackage -Path C:\Users\lewisc\Desktop\iSCSITests\dca_iscsi_issues_ping_matrix.xlsx

    $sourceName = $_.Name
    $curHost = ($sourceName -split ' ')[0] + '.zhost'
    $esxcli = Get-EsxCli -V2 -VMHost $curHost

    $iscsiHosts | ? Name -like fa2* | % {

        $result = ' '                                                        
        $target = $_.Name

        $params = $esxcli.network.diag.ping.CreateArgs()
        $params.ipv4 = $true                                                
        $params.host = $_.IP
        $params.count = 3
        
        if($sourceName -match 'iscsi1'){
            $params.interface = 'vmk1'
        }else{
            $params.interface = 'vmk2'
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

        $cellWithCorrectColumn = ($excelPkg.Sheet1.Cells | ? Value -eq $target).Address
        $cellWithCorrectRow = ($excelPkg.Sheet1.Cells | ? Value -eq $sourceName).Address

        [regex]$ptrn = '[A-Z]+'
        $column = $ptrn.Match($cellWithCorrectColumn).Value

        [regex]$ptrn = '[0-9]+'
        $row = $ptrn.Match($cellWithCorrectRow).Value

        Set-ExcelRange -Range $excelPkg.Sheet1.Cells[$column + $row] -Value $result                
    }

    Export-Excel -ExcelPackage $excelPkg
}
