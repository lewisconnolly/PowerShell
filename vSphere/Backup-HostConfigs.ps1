# script by xavier avrillier

function Backup-HostConfigs {

    param (
        
        [ValidateNotNullOrEmpty()]
        [string]
        $BackupLocation,
    
        [ValidateNotNullOrEmpty()]
        [int]
        $FileRotation,

        [ValidateNotNullOrEmpty()]
        [string]
        $Datacenter,

        [ValidateNotNullOrEmpty()]
        [string]
        $Server
    
    )
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false  -Confirm:$false | Out-Null

        Connect-VIServer -Server $Server -WarningAction Ignore | Out-Null
    
        TRY {
    
            GET-VMHOST -Location $Datacenter | ForEach-Object {
        
                $ESXiBak = "$BackupLocation\$($_.name)"
                $OldESXiBak = "$ESXiBak\$(get-date -Format yyyy-MM-dd)_$($_.name).tgz"
    
                IF (-not(Test-path $ESXiBak)) {MKDIR $ESXiBak}
    
                WHILE (((Get-ChildItem $ESXiBak).count) -gt $FileRotation) {Get-ChildItem $ESXiBak | Sort-Object lastwritetime | select -First 1 | Remove-Item -Force -Confirm:$false}
            
                #Actual backup cmd
                Get-VMHostFirmware -VMHost $_.name -BackupConfiguration -DestinationPath $ESXiBak
    
                if(Test-path $OldESXiBak){
                    
                    $OldESXiBak | Remove-Item -Force
                }
                
                Get-ChildItem $ESXiBak | Sort-Object lastwritetime | select -Last 1 | Rename-Item -NewName "$(get-date -Format yyyy-MM-dd)_$($_.name).tgz" -Force
            }
        } CATCH {
    
            Write-Error $_.Exception -ErrorAction Continue
    
        } Finally {Disconnect-VIServer -Confirm:$false}
}