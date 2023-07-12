<#
.SYNOPSIS
    Return the configuration related custom attributes for VMs
.DESCRIPTION
    Queries default VI server for VMs that have pre-defined custom attributes for tracking configuration consistency. Those attributes are:

    AdapterTypeVMXNET3
    HotAddEnabled
    MaxHVForCluster
    NameEqualsFolder
    NameEqualsVMX
    ThinProvisioned
    ToolsCurrent
.EXAMPLE
    Get-VM lc-test1 | Get-VMConfigurationCustomAttributes
.EXAMPLE
    Get-VM lc-test1 | Get-VMConfigurationCustomAttributes -CustomAttributes HotAddEnabled, NameEqualsVMX 
.INPUTS
    VM(s), Custom attributes
.OUTPUTS
    VM and custom attribute values
.NOTES
    General notes
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    The functionality that best describes this cmdlet
#>
function Get-VMConfigurationCustomAttributes {
    [CmdletBinding(DefaultParameterSetName='Parameter Set 1',
                   SupportsShouldProcess=$true,
                   PositionalBinding=$false,
                   HelpUri = 'http://www.microsoft.com/',
                   ConfirmImpact='Medium')]
    [Alias()]
    [OutputType([String])]
    Param (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ValueFromRemainingArguments=$false, 
                   ParameterSetName='Parameter Set 1')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateCount(0,5)]
        [ValidateSet("sun", "moon", "earth")]
        [Alias("p1")] 
        $Param1,
        
        # Param2 help description
        [Parameter(ParameterSetName='Parameter Set 1')]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [ValidateScript({$true})]
        [ValidateRange(0,5)]
        [int]
        $Param2,
        
        # Param3 help description
        [Parameter(ParameterSetName='Another Parameter Set')]
        [ValidatePattern("[a-z]*")]
        [ValidateLength(0,15)]
        [String]
        $Param3
    )
    
    begin {
    }
    
    process {
        if ($pscmdlet.ShouldProcess("Target", "Operation")) {
            
        }
    }
    
    end {
    }
}