<#
.Synopsis
   Set guest interaction proxies on backup jobs
.DESCRIPTION
   Set guest interaction proxies on backup jobs using a reference job
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Set-VBRGIProxies
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
    
    if($ReferenceJob){ $guestProxies = $ReferenceJob.GetGuestProcessingProxyHosts() }
        
    if((!$AutoSelect)-and($guestProxies.count -gt 0))
    {                
        $targJobs = $TargetJobs | ? {($_.Name -ne $ReferenceJob.Name) -and ($_.jobtype -eq 'backup')}

        $targJobs | % {

            $targ = $_
            $targJobVSS = $targ.GetVSSOptions()
            $targJobVSS.GuestProxyAutoDetect = $False
            $targ.SetVssOptions($targJobVSS)
            $curProxies =  [Veeam.Backup.Core.CJobProxy]::GetJobProxies($targ.Id) | ? Type -eq 'EGuest'

            $guestProxies | % {

                $GPID = (Get-VBRServer -Name $_.Name).Id
                if ($curProxies | ? ProxyId -eq $GPID)
                { 
                    Write-Host "`n$($_.Name) is already a guest interaction proxy for $($targ.Name)`n"
                }
                else
                {
                    Write-Host "`nAdding $($_.Name) as guest interaction proxy to $($targ.Name)`n"
                    [Veeam.Backup.Core.CJobProxy]::Create($targ.Id, $GPID, 'EGuest')
                }
            }

            $curProxies | % {

                if($_.ProxyId -notin $guestProxies.Id)
                {
                    Write-Host "`nRemoving $($_.ProxyServer.Name) as guest interaction proxy from $($targ.Name)`n"
                    [Veeam.Backup.Core.CJobProxy]::Delete($_.Id)
                }
            }
        }       
    }
    else
    {
        $targJobs = $TargetJobs | ? JobType -eq 'backup'
        
        $targJobs | % {            

            $targ = $_

            Write-Host "`nSetting guest interaction proxy selection to Automatic for $($targ.Name)`n"

            $targJobVSS = $targ.GetVSSOptions()
            $targJobVSS.GuestProxyAutoDetect = $true
            $targ.SetVssOptions($targJobVSS)
        }
    }
    #}
}