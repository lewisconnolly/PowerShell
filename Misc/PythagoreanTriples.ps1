

$sols = @()

$n=25
$a = $n*$n

for($i=1;($i-le$a/2);$i++) {
    
    $x=$a/$i
    
    if(($x-ne$i)-and($x -is [int])){
            
        $diff = $x+$i
        if(($diff%2-eq0) -and (($x+$i)-notin $sols))
        {
            $sols+= $x+$i

            "a = $n, b = $($x-($x+$i)/2), c = $(($x+$i)/2)"
        }
    }
}




$limit= 1000

foreach($n in (0..$limit))
{
    $sols = @()

    $a = $n*$n
    
    $result = [pscustomobject]@{
        SqrRt = $n.ToString()
    }

    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    for($i=1;$i-le($a/2);$i++) {
    
        $x=$a/$i
    
        if(($x-ne$i)-and($x -is [int])){
            
            $diff = $x+$i
            if(($diff%2-eq0) -and (($x+$i)-notin $sols))
            {
                $sols+= $x+$i

                #"a = $n, b = $($x-($x+$i)/2), c = $(($x+$i)/2)"
            }
        }
    }

    $timer.Stop()
    
    $result | Add-Member -MemberType NoteProperty -Name Milliseconds -Value $timer.elapsed.Milliseconds
    $result | Add-Member -MemberType NoteProperty -Name NumSolutions -Value $sols.count
    $result
}