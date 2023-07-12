function Set-PersistentLocations {
    param (
        $VMhost
    )
    
    $vmhostName = $VMhost.name -replace '\.zhost'
    
    $scratch = "/vmfs/volumes/5cb85f03-33fa2a24-ae57-a41f72d330c3/zHostLogs/$vmhostName/Scratch"
    $syslog = "[DCA-SSD-PURE101] zHostLogs/$vmhostName"
    
    "Setting vmkdump file vmstore:\DCA\DCA-SSD-PURE101\vmkdump\$vmhostName-vmkdump.dumpfile" | Write-Host
    $esxcli = Get-EsxCli -V2 -VMHost $VMhost
    $esxcli.system.coredump.file.set.Invoke(@{enable = 0}) | Out-Null
    $esxcli.system.coredump.file.set.Invoke(@{unconfigure = 1}) | Out-Null
    $esxcli.system.coredump.file.add.Invoke(@{datastore = 'DCA-SSD-PURE101';enable = 1; file = "$vmhostName-vmkdump"}) | Out-Null
    $dumpfile = $esxcli.system.coredump.file.get.invoke()
    $dumpfile
    
    "Removing old vmkdump file vmstore:\DCA\DCA-10K-EQL01\vmkdump\$vmhostName-vmkdump.dumpfile" | Write-Host
    Remove-Item -Path "vmstore:\DCA\DCA-10K-EQL01\vmkdump\$vmhostName-vmkdump.dumpfile"
    
    "`nAdding host folder vmstore:\DCA\DCA-SSD-PURE101\zHostLogs\$vmhostName`n" | Write-Host
    New-Item -Path 'vmstore:\DCA\DCA-SSD-PURE101\zHostLogs\' -Name $vmhostName -ItemType Directory

    "Adding scratch folder vmstore:\DCA\DCA-SSD-PURE101\zHostLogs\$vmhostName\Scratch" | Write-Host
    New-Item -Path "vmstore:\DCA\DCA-SSD-PURE101\zHostLogs\$vmhostName\" -Name 'Scratch' -ItemType Directory

    "Setting ScratchConfig.ConfiguredScratchLocation to $scratch" | Write-Host
    $VMhost | Get-AdvancedSetting -Name 'ScratchConfig.ConfiguredScratchLocation' | Set-AdvancedSetting -Value $scratch
    
    "Setting Syslog.global.logDir to $syslog" | Write-Host
    $VMhost | Get-AdvancedSetting -Name 'Syslog.global.logDir' | Set-AdvancedSetting -Value $syslog
    
    Read-Host -Prompt "Update product locker via https://$( $VMhost.Name )/mob/?moid=ha-host`n`n/vmfs/volumes/5cb85f03-33fa2a24-ae57-a41f72d330c3/productLocker/packages/vmtoolsRepo`n"
}


function Get-PersistentLocations {
    param (
        $VMhost
    )
    
    $esxcli = Get-EsxCli -V2 -VMHost $VMhost
    $esxcli.system.coredump.file.get.invoke() | select @{n='Name';e={'coredump'}}, @{n='Value';e={$_.Active}}
       
    $VMhost | Get-AdvancedSetting -Name 'ScratchConfig.ConfiguredScratchLocation' | select Name, Value
    $VMhost | Get-AdvancedSetting -Name 'ScratchConfig.CurrentScratchLocation' | select Name, Value
    
    $VMhost | Get-AdvancedSetting -Name 'Syslog.global.logDir' | select Name, Value
    
    $VMhost | Get-AdvancedSetting -Name 'UserVars.ProductLockerLocation' | select Name, Value

}