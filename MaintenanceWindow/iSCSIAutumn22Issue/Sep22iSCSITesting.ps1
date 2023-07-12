
cvi vcenter -Credential $lcred | Out-Null

function RunProxyTests ($Rows, $Credential){

    $vbp01 = [PSCustomObject]@{
        VM = gvm 'dcautlprdvbp01'
        IP = '172.31.254.74'
    }
    $vbp05 = [PSCustomObject]@{
        VM = gvm 'dcautlprdvbp05'
        IP = '172.31.254.78'
    }
    $dstIPs = @(
        '172.31.254.205', # FA1
        '172.31.254.206', # FA1
        '172.31.254.207', # FA1
        '172.31.254.208', # FA1
        '172.31.254.209', # FA1
        '172.31.254.210', # FA1
        '172.31.254.211', # FA1
        '172.31.254.212', # FA1
        '172.31.254.213', # FA2
        '172.31.254.214', # FA2
        '172.31.254.215', # FA2
        '172.31.254.216', # FA2
        '172.31.254.217', # FA2
        '172.31.254.218', # FA2
        '172.31.254.219', # FA2
        '172.31.254.220', # FA2
        '172.31.254.41', # sg-b4-zhost1
        '172.31.254.48', # sg-b8-zhost8
        '172.31.254.50', # sg-b8-zhost10
        '172.31.254.43' # sg-b4-zhost3        
    )
    $excelPkg = Open-ExcelPackage -Path 'C:\Users\lewis\OneDrive - Zonal Retail Data Systems Limited\Documents\Spreadsheets\dca_iscsi_issues_sep22.xlsx'
    $columns = 69..88 | ForEach-Object {[Char]$PSItem} # ASCII code for E to X inclusive
    $results = @()

    $vbp01, $vbp05 | % {
        $vm = $_.VM
        $IP = $_.IP

        $dstIPs | % {
            $ping = Invoke-VMScript -ScriptText "ping $_ -S $IP -n 3 -w 2500" -VM $vm -GuestCredential $Credential -ScriptType Powershell
            $results += (($ping.ScriptOutput -split "`n" | ? {$_ -match 'lost'}) -split '\(')[1] -replace '\),'
        }
    }

    $i = 0
    $rows | % {
        $row = $_
        $columns | % {
            Set-ExcelRange -Range $excelPkg.sheet1.Cells["$_$row"] -Value $results[$i]
            $i++
        }
    }

    Export-Excel -ExcelPackage $excelPkg 
}

RunProxyTests -Rows 4, 5 -Credential $lcred

<# Host tests start #>

$faIPs = @(
    '172.31.254.205', # FA1
    '172.31.254.206', # FA1
    '172.31.254.207', # FA1
    '172.31.254.208', # FA1
    '172.31.254.209', # FA1
    '172.31.254.210', # FA1
    '172.31.254.211', # FA1
    '172.31.254.212', # FA1
    '172.31.254.213', # FA2
    '172.31.254.214', # FA2
    '172.31.254.215', # FA2
    '172.31.254.216', # FA2
    '172.31.254.217', # FA2
    '172.31.254.218', # FA2
    '172.31.254.219', # FA2
    '172.31.254.220' # FA2
)
$columns = 69..84 | ForEach-Object {[Char]$PSItem} # ASCII code for E to X inclusive
$rows = 6..9
$faResults = @()
$vmhosts = @(
    [PSCustomObject]@{
        VMHost = gvh sg*t1.*
        IP = '172.31.254.41'
    },
    [PSCustomObject]@{
        VMHost = gvh sg*t8*
        IP = '172.31.254.48'
    },
    [PSCustomObject]@{
        VMHost = gvh sg*10*
        IP = '172.31.254.50'
    },
    [PSCustomObject]@{
        VMHost = gvh sg*t3*
        IP = '172.31.254.43'
    }
)

$vmhosts | % {
    $vmhost = $_.VMHost
    #$IP = $_.IP
    #$dstIPs = $vmhosts | ? {$_.VMHost.Name -ne $vmhost.name} | sel -ExpandProperty IP
    $esxcli = Get-EsxCli -V2 -VMHost $vmhost    

    $faIPs | % {
        $params = $esxcli.network.diag.ping.CreateArgs()
        $params.host = $_
        $params.netstack = 'vmotion'
        $params.ipv4 = $true
        $params.interface = 'vmk3'

        $ping = $esxcli.network.diag.ping.Invoke($params) | sel -ExpandProperty summary
        $faResults += "{0}% loss" -f $ping.PacketLost
    }
}

$excelPkg = Open-ExcelPackage -Path 'C:\Users\lewis\OneDrive - Zonal Retail Data Systems Limited\Documents\Spreadsheets\dca_iscsi_issues_sep22.xlsx'

$i = 0
$rows | % {
    $row = $_
    $columns | % {
        Set-ExcelRange -Range $excelPkg.sheet1.Cells["$_$row"] -Value $faResults[$i]
        $i++
    }
}

Export-Excel -ExcelPackage $excelPkg 

$columns = 'U', 'V', 'W', 'X'
$vMotionResults = @()

$vmhosts | % {
    $vmhost = $_.VMHost
    $IP = $_.IP
    #$dstIPs = $vmhosts | ? {$_.VMHost.Name -ne $vmhost.name} | sel -ExpandProperty IP
    $esxcli = Get-EsxCli -V2 -VMHost $vmhost    

    $vmhosts.IP | % {
        if($_ -ne $IP){
            $params = $esxcli.network.diag.ping.CreateArgs()
            $params.host = $_
            $params.netstack = 'vmotion'
            $params.ipv4 = $true
            $params.interface = 'vmk3'

            $ping = $esxcli.network.diag.ping.Invoke($params) | sel -ExpandProperty summary
            $vMotionResults += "{0}% loss" -f $ping.PacketLost
        } else { $vMotionResults += 'NA'}
    }
}

$excelPkg = Open-ExcelPackage -Path 'C:\Users\lewis\OneDrive - Zonal Retail Data Systems Limited\Documents\Spreadsheets\dca_iscsi_issues_sep22.xlsx'

$i = 0
$rows | % {
    $row = $_
    $columns | % {
        Set-ExcelRange -Range $excelPkg.sheet1.Cells["$_$row"] -Value $vMotionResults[$i]
        $i++
    }
}

Export-Excel -ExcelPackage $excelPkg 

<# Host tests end #>

gvm dcautlprdvbp01 | Move-VM -Destination sg-b4-zhost3.zhost
gvm dcautlprdvbp05 | Move-VM -Destination sg-b8-zhost10.zhost

RunProxyTests -Rows 20, 21 -Credential $lcred

gvm dcautlprdvbp01 | Move-VM -Destination sg-b8-zhost10.zhost
gvm dcautlprdvbp05 | Move-VM -Destination sg-b4-zhost3.zhost

RunProxyTests -Rows 31, 32 -Credential $lcred