<#
.Synopsis
   Set backup proxies on backup jobs
.DESCRIPTION
   Set backup proxies on backup jobs using a reference job
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Set-VBRBackupProxies
{
    [CmdletBinding(DefaultParameterSetName='byRefJob')]
    [Alias()]
    Param
    (
        [Parameter(
            ParameterSetName='byRefJob',
            Mandatory = $true
        )]
        $ReferenceJob,

        [Parameter(
            ParameterSetName='byRefJob',
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName='autoSelect',
            Mandatory = $true
        )]
        $TargetJobs,

        [Parameter(
            ParameterSetName='autoSelect',
            Mandatory = $true
        )]
        $AutoSelect
    )

    #Begin
    #{
    #    Add-PSSnapin VeeamPSSnapin
    #}
    #Process
    #{

    $proxies = Get-VBRViProxy -Name ($ReferenceJob | Get-VBRJobProxy).Name
    $targJobs = $TargetJobs | ? {($_.Name -ne $ReferenceJob.Name) -and ($_.jobtype -eq 'backup')}
    Write-Host "`nProxies to use:`n"
    Write-Host "`n$($proxies.name -join "`n")`n"

    if((!$AutoSelect)-and($proxies.count -gt 0))
    {
        $targJobs | % {

            Write-Host "`nSetting $($_.Name) to use the same backup proxies as $($ReferenceJob.Name)`n"

            Set-VBRJobProxy -Job $_ -Proxy $proxies
        }       
    }
    else
    {
        $targJobs | % {
            Write-Host "`nSetting $($_.Name) to autoselect proxies`n"

            Set-VBRJobProxy -Job $_ -AutoDetect
        }
    }

    #}
}