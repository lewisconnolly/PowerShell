<#
.Synopsis
    Calculate required disk sizes of Veeam WAN Accelerators
.DESCRIPTION
    Source WA Sizing

    $a = Number of copy jobs (this function assumes there is one Source WA per job)
    $b = Total provisioned size of all backed up VMs
    $c = $b/$a = Average provisioned size of VMs per copy job
    $d = $c/20 = Space required on each Source WA to store VM digests

    If creating $a Source WAs, each should have a disk of size $dGB or greater

    Target WA Sizing

    $e = Number of different OS types in backed up VMs
    $f = $e x 10 = Target WA space required for common OS data
    $g = $b/50 = Target WA space required to store VM digests if not availble from Source WAs
    $h = $a x $f + $g = Total space required on Target WA for common OS data and digests
    
    If only creating one Target WA, it should have a disk of size $hGB or greater and cache size set to $f in Veeam settings
.EXAMPLE
    # Calculate for 6 copy jobs and 10 different OS types (assume 1:1 copy jobs to source WAs ratio)
   
    Calculate-VWASizing -NumberOfCopyJobs 6 -NumberOfDifferentOS 10
#>
function Calculate-VBRWASizing
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        $NumberOfCopyJobs,

        [Parameter(Mandatory=$true)]
        $NumberOfDifferentOS,

        $vCenterCredential
    )

    Begin
    {
        Add-PSSnapin VeeamPSSnapin
    }

    Process
    {
        
        "`nConnecting to vCenter...`n" | Write-Host
        
        if($vCenterCredential)
        {
            Connect-VIServer vcenter -Credential $vCenterCredential | Out-Null
        }
        else
        {
            Connect-VIServer vcenter | Out-Null
        }

        "Getting backup job objects...`n" | Write-Host

        $backupJobs = Get-VBRJob | ? jobtype -eq backup 

        $jobObjects = $backupJobs |
        Get-VBRJobObject

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
                    $folder | Get-VM | ? folderid -eq $folder.id | select Name,@{N='Type';e={$type}}
                }
            }
        }
        
        "Getting backed up VMs to calculate total provisioned size...`n" | Write-Host

        $backedUpVMs = Find-VMFromVBRJobObject -JobObjects $jobObjects | ? type -ne 'Exclude'

        $backedUpVMsProvisionedGB = (Get-VM $backedUpVMs.Name | measure ProvisionedSpaceGB -Sum).Sum

        "Calculating WA size requirements...`n" | Write-Host

        $averageProvPerJob = $backedUpVMsProvisionedGB/$NumberOfCopyJobs
        
        $sourceDigest = [math]::Ceiling($averageProvPerJob*.05)

        $commonOSFiles = $NumberOfDifferentOS*10
        
        $targetDigest = $backedUpVMsProvisionedGB*.02

        $targetWADiskGB = [math]::Ceiling($commonOSFiles*$NumberOfCopyJobs+$targetDigest)

        [pscustomobject]@{
        
            SourceWADiskGB = $sourceDigest
            TargetWAConfigGB = $commonOSFiles
            TargetWADiskGB =  $targetWADiskGB
        }
    }
}