# ESXi FS uses /productLocker for vmtools location
# /productLocker is a symlink to a vmfs location containing vmtools
# The path /usr/lib/vmware/isoimages redirects to /productLocker
#
# Host advanced setting - UserVars.ProductLockerLocation
# DCA vmfs location - /vmfs/volumes/51fb9543-0aac360f-a642-a41f72d33041/productLocker/packages/6.5.0/
# DCB vmfs location - /vmfs/volumes/5bd875f7-59a1977c-9374-588a5ab97a72/productLocker/packages/vmtoolsRepo/vmtools/
# TF vmfs location - 

function Set-ESXiProductLockerLocation ($vmhost,$fullpath,$password) {

    if(!$vmhost){$vmhost = get-vmhost}

    gvh $vmhost <#| ? name -notmatch '12|25'#> | % {       
            
        $cred = New-Cred -User root -Password $password
        
        Out-Default -InputObject "`n"
        Out-Default -InputObject $_.name
        $sessh = New-SSHSession -ComputerName $_.name -Credential $cred -AcceptKey 
    
        #Get existing locker symlink location
        $cmd = "secpolicytools -d | grep `$(basename `$(readlink /productLocker)) | cut -d' ' -f2 | head -n1"
        $origlocker = (Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId).Output
        Out-Default -InputObject $origlocker
        Out-Default -InputObject "`n"
    
        #Rename isoimages path using symlink
        $cmd = 'mv /usr/lib/vmware/isoimages /usr/lib/vmware/isoimages.tmp'
        $invoke=Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId
        Out-Default -InputObject $invoke.output
        Out-Default -InputObject "`n"
    
        #Change product locker to new location
        $cmd = "updateProductLockerPolicy $origlocker $fullpath"
        $invoke=Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId
        Out-Default -InputObject $invoke.output
        Out-Default -InputObject "`n"

        #Remove existing symlink
        $cmd = 'rm /productLocker'
        $invoke=Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId
        Out-Default -InputObject $invoke.output
        Out-Default -InputObject "`n"
    
        #Create new symlink
        $cmd = "ln -s $fullpath /productLocker"
        $invoke=Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId
        Out-Default -InputObject $invoke.output
        Out-Default -InputObject "`n"

        #Rename back isoimages path
        $cmd = 'mv /usr/lib/vmware/isoimages.tmp /usr/lib/vmware/isoimages'
        $invoke=Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId
        Out-Default -InputObject $invoke.output
        Out-Default -InputObject "`n"

        Remove-SSHSession $sessh
    }
}

function Set-ESXiToolsIsosSymLink ($vmhost,$password) {

    if(!$vmhost){$vmhost = get-vmhost}

    gvh $vmhost <#| ? name -notmatch '12|25'#> | % {
    
    $cred = New-Cred -User root -Password $password
        
        Out-Default -InputObject "`n"
        Out-Default -InputObject $_.name
        $sessh = New-SSHSession -ComputerName $_.name -Credential $cred -AcceptKey        
        

           #Remove existing symlink
        $cmd = 'rm /usr/lib/vmware/isoimages/'
        $invoke=Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId
        Out-Default -InputObject $invoke.output
        Out-Default -InputObject "`n"
    

 #Create new symlink
        $cmd = "ln -s '/productLocker/' '/usr/lib/vmware/isoimages/'"
        $invoke=Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId
        Out-Default -InputObject $invoke.output
        Out-Default -InputObject "`n"

          Remove-SSHSession $sessh

          }
}