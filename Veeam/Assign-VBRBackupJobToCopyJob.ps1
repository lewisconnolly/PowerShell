<#
.Synopsis
    Based on number of desired backup copy jobs, decide, based on start time, how to assign backup jobs to copy jobs
.DESCRIPTION
    Job assignment based on total backup size and time.
.EXAMPLE
    Assign-VBRBackupJobToCopyJob -RequiredNumberOfCopyJobs 7
#>
function Assign-VBRBackupJobToCopyJob
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true)]
        $RequiredNumberOfCopyJobs
    )

    Begin
    {
        Add-PSSnapin VeeamPSSnapin
    }

    Process
    {        
        $jobs = Get-VBRJob | ? JobType -eq Backup | Select Name,
        @{n='Start';e={($_ | Get-VBRJobScheduleOptions).StartDateTimeLocal.TimeOfDay}},
        @{n='Size';e={$_.FindLastSession().Info.BackupTotalSize}}

        $copyJobSize = ($jobs | measure Size -Sum).Sum/$RequiredNumberOfCopyJobs

        $tally = 0
        $n = 1
        $copyJobTargets = @()

        $copyJobs = $jobs | sort Start | % {

            if((($tally + $_.Size) -lt $copyJobSize) -or ($tally -eq 0))
            {
                $tally += $_.Size
                $copyJobTargets += $_ | Select *,@{n='CopyJob';e={$n}}
            }
            else
            {
                $copyJobTargets
        
                $tally = 0
                $n++
                $copyJobTargets = @()
                $copyJobTargets += $_ | Select *,@{n='CopyJob';e={$n}}
            }
        }
        $copyJobs += $copyJobTargets

        $copyJobs
        $copyJobs | group copyjob | select {($_.Group.Size | measure -Sum).Sum/1TB}
    }
}