<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-BuildNumber
{
    Get-View -ViewType HostSystem -Property Name, Config.Product | select Name,{$_.Config.Product.FullName},{$_.Config.Product.Build}
}
