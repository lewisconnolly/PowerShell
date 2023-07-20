function Invoke-ESXiSshCommand ($VMHost, $Command, $Credential) {

    foreach ($hosty in $VMHost){

        $sessh = New-SSHSession -ComputerName $hosty.name -Credential $Credential -AcceptKey
    
        Out-default -inputobject "`nRunning:`n`n$Command`n`non $($hosty.name)"

        $invoke = Invoke-SSHCommand -Command $Command -SSHSession $sessh
        <#
        Out-Default -InputObject "`n"
        Out-default -inputobject $invoke.Output
        Out-Default -InputObject "`n"
        #>

        Remove-SSHSession $sessh | Out-Null
    
        $invoke    
    }
}

