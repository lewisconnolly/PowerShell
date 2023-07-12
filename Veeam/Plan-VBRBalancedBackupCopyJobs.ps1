<#
.Synopsis
    Calculate which backups to move from current backup copy jobs if now jobs are to be created
.DESCRIPTION
    This function tries to create new backup copy jobs while keeping all jobs close to the same total size
.EXAMPLE
    # Collect current backup copy jobs and plan for 6 jobs in total
    
    $backupCopyJobs = Get-VBRJob | ? JobType -eq BackupSync

    Plan-BalancedBackupCopyJobs -BackupCopyJobs $backupCopyJobs -RequiredNumberOfCopyJobs 6
#>
function Plan-VBRBalancedBackupCopyJobs
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        $BackupCopyJobs,

        [Parameter(Mandatory=$true)]
        $RequiredNumberOfCopyJobs
    )

    Begin
    {
        Add-PSSnapin VeeamPSSnapin
    }

    Process
    {
        "`nCollecting offsite backups...`n" | Write-Host

        $backups = Get-VBRBackup -Name $BackupCopyJobs.Name

        $backupsInfo = @()

        "Calculating backup sizes and finding linked onsite jobs...`n" | Write-Host

        $backups | % {
            
            $repo =
            $_.GetHost().Name

            $path = ($_ | Select -ExpandProperty DirPath) -replace ':','$'

            $fullPath = "\\$repo\$path"
            
            $tp = Test-Path $fullPath

            if($tp)
            {
                 $backupSize = (ls -R $fullPath | ? Length -ne $null | Measure -Property Length -Sum).Sum
            }

            $backupJobs = (Get-VBRJob -Name $_.Name).LinkedJobIds.Guid | % {

                $ID = $_
                Get-VBRJob | ? Id -eq $ID | Select Name,
                @{n='Size';e={$_.FindLastSession().Info.BackupTotalSize}}
            }

            $backupsInfo += [pscustomobject]@{

                Name = $_.Name
                Path = $fullPath
                Size = $backupSize
                BackupJobs = $backupJobs
            }
        }

        $sizeAim = ($backupsInfo | measure Size -Sum).Sum/$RequiredNumberOfCopyJobs

        $numNewJobs = $RequiredNumberOfCopyJobs - $backups.count

        $backupsToMove = @()

        "Deciding backups to move to new jobs...`n" | Write-Host

        0..($numNewJobs-1) | % {
            
            $newJobName = "DCA-DCB-daily-copy$($RequiredNumberOfCopyJobs-$_)"
            $newJobSize = 0
            $stuck = $false

            while(($newJobSize -lt $sizeAim) -and (!$stuck))
            {
                $target = $sizeAim - $newJobSize
                
                $curLargest = ($backupsInfo | Sort Size | Select -last 1)
                
                $backupToMove = $curLargest.BackupJobs |
                Select Name,Size,
                @{n='DiffFromTarget';e={
                
                    $diff = $target - $_.Size
                    if($diff -lt 0){ $diff*-1 }else{ $diff }

                }} | Sort DiffFromTarget | Select -Last 1

                $newJobSize = $newJobSize + $backupToMove.Size
                
                if($newJobSize -le ($sizeAim+$sizeAim/3))
                {
                    $backupsInfo | % {

                        $_.BackupJobs = $_.BackupJobs | ? Name -ne $backupToMove.Name
                    }

                    $backupsInfo = $backupsInfo | select Name,Path,BackupJobs,
                    @{n='Size';e={
                        if($_.Name -eq $curLargest.Name){ $_.Size - $backupToMove.Size }
                        else { $_.Size }
                    }}
                
                    $backupsToMove += $backupToMove | Select Name,Size,
                    @{n='OriginalCopyJob';e={$curLargest.Name}},
                    @{n='NewCopyJob';e={$newJobName}}
                }
                
                if($prevBackupToMove -eq $backupToMove.Name) { $stuck = $true }
                
                $prevBackupToMove = $backupToMove.Name                
            }
        }

        "`nTotal offsite backup size divided by $($RequiredNumberOfCopyJobs): $([math]::Round($sizeAim/1GB)) GB`n" |
        Write-Host -BackgroundColor Black

        $backupsInfo | Sort Name | % {
        
            "$($_.Name) new size: $([math]::Round($_.Size/1GB)) GB`n" | Write-Host -BackgroundColor Black
        }
        
        $backupsToMove | Group-Object NewCopyJob | Sort Name | % {

            "$($_.Name) total size: $([math]::Round(($_.Group.Size | Measure -Sum).Sum/1GB)) GB`n" |
            Write-Host -BackgroundColor Black
        }
        
        $backupsToMove | Select Name,@{n='SizeGB';e={[math]::Round($_.Size/1GB)}},OriginalCopyJob,NewCopyJob |
        Sort NewCopyJob,OriginalCopyJob
    }
}

$backupCopyJobs = Get-VBRJob | ? JobType -eq BackupSync
Plan-BalancedBackupCopyJobs -BackupCopyJobs $backupCopyJobs -RequiredNumberOfCopyJobs 7

