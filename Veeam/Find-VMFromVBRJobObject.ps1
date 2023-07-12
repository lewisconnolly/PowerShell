Add-PSSnapin VeeamPSSnapin | Out-Null

function Find-VMFromVBRJobObject ($JobObjects)
{
    $jobObjects | % {
        $path = $_.Location
        $type = $_.Type
        $continue = $true
        $VM = ''
        $splitPath = $path -split '\\'
        $command = "Get-Folder -Name vm -Location $($splitPath[1]) -server $($splitPath[0])"
        $splitPath = $splitPath[2..$splitPath.count]

        $splitPath | % {
            if($continue)
            {
                $parID = (Invoke-Expression $command -ErrorAction SilentlyContinue).id

                $test = $command + "| Get-Folder -Name '$_' -ErrorAction SilentlyContinue | ? Parentid -eq '$parID'"

                $result = Invoke-Expression $test -ErrorAction SilentlyContinue

                if($result)
                {
                    $command = $test
                }
                else
                {   
                    if(Get-VM $_ -ErrorAction Ignore)
                    {
                        $VM = Get-VM $_ -ErrorAction Ignore
                    }
                    elseif(Get-VM $splitPath[-1] -ErrorAction Ignore)
                    {
                        $VM = Get-VM $splitPath[-1] -ErrorAction Ignore
                    }
                    $continue = $false
                }
            }
        }
            
        if(!$continue)
        {
            if($VM)
            {
                [pscustomobject]@{
                    Name = $VM.Name
                    Type = $type
                }
            }
            else
            {
                "`n`n$path`n`nVM(s) not found`n`n" | Write-Warning
            }
        }
        else
        {
            $folder = Invoke-Expression -Command $command
            $folder | Get-VM | ? folderid -eq $folder.id | select Name,
                @{N='Type';e={$type}},
                @{N='Hostname';e={$_.guest.hostname}}
        }
    }
}
Connect-VIServer vcenter | Out-Null
$backupJobs = Get-VBRJob | ? jobtype -eq backup 
$jobObjects = $backupJobs | Get-VBRJobObject
$backedUpVMs = Find-VMFromVBRJobObject -JobObjects $jobObjects | ? type -ne 'Exclude' 
$backedUpVMs