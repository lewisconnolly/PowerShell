<#
.Synopsis
   - Outputs "-count $int" hosts from array of "-hosts $hosts".
   - If more than 3 hosts in initial array then same host will not be output twice within 3 hosts.
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-RandomishHost ($count,$hosts) {
    if (!$count){$count = 1}
    if (!$hosts){$hosts = get-vmhost}
    $inithosts = $hosts
    for($i=0;$i -lt $count){
        if ($inithosts.count -gt 3) {
            if($i%2){
                $oddhost = ($hosts | get-random)
                $oddhost
            }else{
                $evenhost = ($hosts | get-random)
                $evenhost
            }
            if($i -gt 0){
                $hosts=($inithosts | where {($_.name -notmatch $oddhost.name)-and($_.name -notmatch $evenhost.name)})
            }
        }else{($hosts |get-random)}
        $i++
    }
}