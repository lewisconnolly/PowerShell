try
{
    # Suppress warning messages
    
    $WarningPreference = 'SilentlyContinue'

    #$admin = Get-Credential

    $c2Src = Get-VDPortgroup 'temp_DCA-DSw0-DPG-VLAN:200-src'
    $c1Src = Get-VDPortgroup 'temp_DCA-DSw0-DPG-VLAN:39-src'
    $dmzSrc = Get-VDPortgroup 'temp_DCA-DSw0-DPG-VLAN:198-src'
    $c2Dst = Get-VDPortgroup 'temp_DCA-DSw0-DPG-VLAN:200-dst'
    $c1Dst = Get-VDPortgroup 'temp_DCA-DSw0-DPG-VLAN:39-dst'
    $dmzDst = Get-VDPortgroup 'temp_DCA-DSw0-DPG-VLAN:198-dst'

    $c2VmSrc = gvm lc-test3
    $c1VmSrc = gvm lc-test2
    $dmzVmSrc = gvm lc-test5
    $c2VmDst = gvm lc-test7
    $c1VmDst = gvm lc-test6
    $dmzVmDst = gvm lc-test8

    $xcelPkg = Open-ExcelPackage -Path "C:\Users\Lewisc\Documents\Notes\UplinkChangeIssue\uplink_change_tests.xlsx"

### C2 source VM tests

    # Set C2 source and target to A1

    Get-VDPortgroup $c2Src | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    Get-VDPortgroup $c2Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1
    Get-VDPortgroup $c1Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1
    Get-VDPortgroup $dmzDst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    # Test pings

    Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 1 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell

    Invoke-VMScript -ScriptText {ping 172.31.200.169 -n 1 -w 1} -VM $c2VmDst -GuestCredential $admin -ScriptType Powershell
    Invoke-VMScript -ScriptText {ping 172.31.200.169 -n 1 -w 1} -VM $c1VmDst -GuestCredential $admin -ScriptType Powershell
    Invoke-VMScript -ScriptText {ping 172.31.200.169 -n 1 -w 1} -VM $dmzVmDst -GuestCredential $admin -ScriptType Powershell

    # Move C2 source from A1 to A2

    Get-VDPortgroup $c2Src | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0

    $c2IntraVlanA1toA2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #B3
    $c2InterVlanA1toA2C2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.250.6 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #F3
    $c2InterVlanA1toA2C1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #J3
    $c2InterVlanA1toA2DmzDstA1 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #N3
    $c2Nas2A1toA2 = Invoke-VMScript -ScriptText {ping 172.31.200.201 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #R3

    # Set target to A2
    
    Get-VDPortgroup $c2Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0
    Get-VDPortgroup $c1Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0
    Get-VDPortgroup $dmzDst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0    

    $c2IntraVlanA1toA2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #D3
    $c2InterVlanA1toA2C2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.250.251 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #H3
    $c2InterVlanA1toA2C1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #L3
    $c2InterVlanA1toA2DmzDstA2 = Invoke-VMScript -ScriptText {ping 172.31.19.21 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #P3

    Start-Sleep 600

    # Move C2 source from A2 to A1

    Get-VDPortgroup $c2Src | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    $c2IntraVlanA2toA1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #E3
    $c2InterVlanA2toA1C2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.250.251 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #I3
    $c2InterVlanA2toA1C1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #M3
    $c2InterVlanA2toA1DmzDstA2 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #Q3
    $c2Nas2A2toA1 = Invoke-VMScript -ScriptText {ping 172.31.200.201 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #S3

    # Set targets to A1

    Get-VDPortgroup $c2Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1
    Get-VDPortgroup $c1Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1
    Get-VDPortgroup $dmzDst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    $c2IntraVlanA2toA1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #C3
    $c2InterVlanA2toA1C2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.250.6 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #G3
    $c2InterVlanA2toA1C1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powershell #K3
    $c2InterVlanA2toA1DmzDstA1 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $c2VmSrc -GuestCredential $admin -ScriptType Powersh #O3

### C1 source VM tests

    # Set C1 source to A1

    Get-VDPortgroup $c1Src | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 1 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell

    # Move C1 source from A1 to A2

    Get-VDPortgroup $c1Src | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0

    $c1IntraVlanA1toA2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #B4
    $c1InterVlanA1toA2C2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #F4
    $c1InterVlanA1toA2C1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.8.73 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #J4
    $c1InterVlanA1toA2DmzDstA1 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #N4
    $c1Nas2A1toA2 = Invoke-VMScript -ScriptText {ping 172.31.200.201 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #R4

    # Set targets to A2
    
    Get-VDPortgroup $c2Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0
    Get-VDPortgroup $c1Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0
    Get-VDPortgroup $dmzDst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0    

    $c1IntraVlanA1toA2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #D4
    $c1InterVlanA1toA2C2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #H4
    $c1InterVlanA1toA2C1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.8.151 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #L4
    $c1InterVlanA1toA2DmzDstA2 = Invoke-VMScript -ScriptText {ping 172.31.19.21 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #P4

    Start-Sleep 600
    
    # Move C1 source from A2 to A1

    Get-VDPortgroup $c1Src | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    $c1IntraVlanA2toA1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #E4
    $c1InterVlanA2toA1C2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #I4
    $c1InterVlanA2toA1C1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.8.151 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #M4
    $c1InterVlanA2toA1DmzDstA2 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #Q4
    $c1Nas2A2toA1 = Invoke-VMScript -ScriptText {ping 172.31.200.201 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #S4

    # Set targets to A1

    Get-VDPortgroup $c2Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1
    Get-VDPortgroup $c1Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1
    Get-VDPortgroup $dmzDst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    $c1IntraVlanA2toA1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #C4
    $c1InterVlanA2toA1C2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #G4
    $c1InterVlanA2toA1C1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.8.73 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powershell #K4
    $c1InterVlanA2toA1DmzDstA1 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $c1VmSrc -GuestCredential $admin -ScriptType Powersh #O4

### DMZ source VM tests

    # Set DMZ source to A1

    Get-VDPortgroup $dmzSrc | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 1 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell

    # Move DMZ source from A1 to A2

    Get-VDPortgroup $dmzSrc | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0

    $dmzIntraVlanA1toA2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #B5
    $dmzInterVlanA1toA2C2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #F5
    $dmzInterVlanA1toA2C1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #J5
    $dmzInterVlanA1toA2DmzDstA1 = Invoke-VMScript -ScriptText {ping 172.31.19.22 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #N5

    # Set targets to A2
    
    Get-VDPortgroup $c2Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0
    Get-VDPortgroup $c1Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0
    Get-VDPortgroup $dmzDst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic1 -UnusedUplinkPort Dvmnic0    

    $dmzIntraVlanA1toA2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #D5
    $dmzInterVlanA1toA2C2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #H5
    $dmzInterVlanA1toA2C1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #L5
    $dmzInterVlanA1toA2DmzDstA2 = Invoke-VMScript -ScriptText {ping 172.31.19.21 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #P5

    Start-Sleep 600
    
    # Move DMZ source from A2 to A1

    Get-VDPortgroup $dmzSrc | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    $dmzIntraVlanA2toA1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #E5
    $dmzInterVlanA2toA1C2DstA2 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #I5
    $dmzInterVlanA2toA1C1DstA2 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #M5
    $dmzInterVlanA2toA1DmzDstA2 = Invoke-VMScript -ScriptText {ping 172.31.19.21 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #Q5

    # Set targets to A1

    Get-VDPortgroup $c2Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1
    Get-VDPortgroup $c1Dst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1
    Get-VDPortgroup $dmzDst | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort Dvmnic0 -UnusedUplinkPort Dvmnic1

    $dmzIntraVlanA2toA1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.198.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #C5
    $dmzInterVlanA2toA1C2DstA1 = Invoke-VMScript -ScriptText {ping 172.31.200.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #G5
    $dmzInterVlanA2toA1C1DstA1 = Invoke-VMScript -ScriptText {ping 172.31.6.189 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powershell #K5
    $dmzInterVlanA2toA1DmzDstA1 = Invoke-VMScript -ScriptText {ping 172.31.19.22 -n 10 -w 1} -VM $dmzVmSrc -GuestCredential $admin -ScriptType Powersh #O5

### Update spreadsheet

    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["b3"] -Value ((($c2IntraVlanA1toA2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["f3"] -Value ((($c2InterVlanA1toA2C2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["j3"] -Value ((($c2InterVlanA1toA2C1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["n3"] -Value ((($c2InterVlanA1toA2DmzDstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["r3"] -Value ((($c2Nas2A1toA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["d3"] -Value ((($c2IntraVlanA1toA2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["h3"] -Value ((($c2InterVlanA1toA2C2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["l3"] -Value ((($c2InterVlanA1toA2C1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["p3"] -Value ((($c2InterVlanA1toA2DmzDstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["e3"] -Value ((($c2IntraVlanA2toA1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["i3"] -Value ((($c2InterVlanA2toA1C2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["m3"] -Value ((($c2InterVlanA2toA1C1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["q3"] -Value ((($c2InterVlanA2toA1DmzDstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["s3"] -Value ((($c2Nas2A2toA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["c3"] -Value ((($c2IntraVlanA2toA1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["g3"] -Value ((($c2InterVlanA2toA1C2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["k3"] -Value ((($c2InterVlanA2toA1C1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["o3"] -Value ((($c2InterVlanA2toA1DmzDstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')

    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["b4"] -Value ((($c1IntraVlanA1toA2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["f4"] -Value ((($c1InterVlanA1toA2C2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["j4"] -Value ((($c1InterVlanA1toA2C1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["n4"] -Value ((($c1InterVlanA1toA2DmzDstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["r4"] -Value ((($c1Nas2A1toA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["d4"] -Value ((($c1IntraVlanA1toA2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["h4"] -Value ((($c1InterVlanA1toA2C2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["l4"] -Value ((($c1InterVlanA1toA2C1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["p4"] -Value ((($c1InterVlanA1toA2DmzDstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["e4"] -Value ((($c1IntraVlanA2toA1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["i4"] -Value ((($c1InterVlanA2toA1C2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["m4"] -Value ((($c1InterVlanA2toA1C1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["q4"] -Value ((($c1InterVlanA2toA1DmzDstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["s4"] -Value ((($c1Nas2A2toA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["c4"] -Value ((($c1IntraVlanA2toA1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["g4"] -Value ((($c1InterVlanA2toA1C2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["k4"] -Value ((($c1InterVlanA2toA1C1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["o4"] -Value ((($c1InterVlanA2toA1DmzDstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')

    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["b5"] -Value ((($dmzIntraVlanA1toA2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["f5"] -Value ((($dmzInterVlanA1toA2C2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["j5"] -Value ((($dmzInterVlanA1toA2C1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["n5"] -Value ((($dmzInterVlanA1toA2DmzDstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["d5"] -Value ((($dmzIntraVlanA1toA2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["h5"] -Value ((($dmzInterVlanA1toA2C2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["l5"] -Value ((($dmzInterVlanA1toA2C1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["p5"] -Value ((($dmzInterVlanA1toA2DmzDstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["e5"] -Value ((($dmzIntraVlanA2toA1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["i5"] -Value ((($dmzInterVlanA2toA1C2DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["m5"] -Value ((($dmzInterVlanA2toA1C1DstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["q5"] -Value ((($dmzInterVlanA2toA1DmzDstA2 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["c5"] -Value ((($dmzIntraVlanA2toA1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["g5"] -Value ((($dmzInterVlanA2toA1C2DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["k5"] -Value ((($dmzInterVlanA2toA1C1DstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')
    Set-ExcelRange -Range $xcelPkg.sheet1.Cells["o5"] -Value ((($dmzInterVlanA2toA1DmzDstA1 -split "`n"|? {$_ -match 'lost'}) -split '\(')[1] -replace '\),')

    Export-Excel -ExcelPackage $xcelPkg 


    # Re-enable warning messages

    $WarningPreference = 'Continue'
}
catch
{    
    $Error[0]
}