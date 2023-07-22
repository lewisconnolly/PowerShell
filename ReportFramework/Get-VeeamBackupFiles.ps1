############################
### Get-VeeamBackupFiles ###
###    lewis.connolly    ###
############################

# Creates report of Veeam backup files and repo usage
function Get-VeeamBackupFiles {

    $repos = Get-VBRBackupRepository | ? Type -eq WinLocal

    $repos | % {
        $path = '\\' + $_.Host.Name + '\' + ($_.FriendlyPath -replace ':','$')
        $repoName = $_.Name
        $repoPath = $_.FriendlyPath
        $repoDescription = $_.Description
        
        ls $path | % {
            
            $files = $_ | ls -Recurse

            $numVBK = ($files | ? Extension -eq '.vbk' | measure).Count
            $numVIB = ($files | ? Extension -eq '.vib' | measure).Count
            $numVRB = ($files | ? Extension -eq '.vrb' | measure).Count
            $numVBM = ($files | ? Extension -eq '.vbm' | measure).Count
            $totalLengthGB = [math]::Round((($files | measure Length -Sum).Sum / 1GB), 2)
            
            [PSCustomObject]@{
            
                Repo = $repoName
                RepoPath = $repoPath
                RepoDesc = $repoDescription
                Folder = $_.Name
                NumVBK = $numVBK
                NumVIB = $numVIB
                NumVRB = $numVRB
                NumVBM = $numVBM
                TotalSizeGB = $totalLengthGB
            }
        }
    }
}    


function Get-VeeamBackupRepoSpace {

    $repos = Get-VBRBackupRepository | ? Type -eq WinLocal

    $repos | sort Name | % {

        "{0} - {1:N0} out of {2:N0} GB remaining<br>" -f $_.Name, $_.GetContainer().CachedFreeSpace.InGigabytes, $_.GetContainer().CachedTotalSpace.InGigabytes
    }    
}

### Report Framework

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

$veeamBackupFiles = Get-VeeamBackupFiles

$veeamRepoSpace = Get-VeeamBackupRepoSpace

$reportContext = "VBK - Full backup file<br>
VIB - Forward incremental backup file<br>
VBR - Reverse incremental backup file<br>
VBM - Backup metadata file<br><br>
$veeamRepoSpace"

$veeamBackupFiles |
ConvertTo-HtmlReport `
    -ReportTitle "Veeam Backup Files" `
    -ReportDescription "Location, file type breakdown and size of Veeam backups on disk" `
    -ReportContext $reportContext `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\Html Reports\veeambackupfiles.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "\\dcautlprdwrk01\c$\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "\\dcautlprdwrk01\c$\inetpub\wwwroot\index.html" `
    -VirtualPath "/"