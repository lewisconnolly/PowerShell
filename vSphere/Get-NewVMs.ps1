function Get-NewVMs
{
    [CmdletBinding()]
    [Alias()]
    Param
    (        
        $Start=(Get-Date).AddDays(-2),

        $Finish=(Get-Date)
    )

    Begin
    {
        $NewVMs = @()
    }
    
    Process
    {
        Get-VIEvent -Start $Start -MaxSamples ([int]::MaxValue) |
        where {($_.FullFormattedMessage -match "cloned|deployed|created")-and($_.Vm.Name)} |
        ForEach-Object {
            $NewVM = Get-VM -Name $_.Vm.Name -ErrorAction SilentlyContinue
            $NewVMs += $NewVM
        }
        $NewVMs
    }
    
}