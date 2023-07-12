$origstring = get-content C:\Users\Lewisc\Desktop\r640procs.txt

$processorlist = $origstring -split "`n"

$processors = @()

$processorlist |

% {
    $fulldesc = $_ -split ','
    $cpuname = $fulldesc[0] -split ' '
    $candt = $fulldesc[1].Trim()
    $extra = $fulldesc[5]

    ## Get level ##
    $level = $cpuname[2]
   
    ## Get generation ##
    [regex]$regex = '[0-9]{4}'
    $gen = $regex.Matches($cpuname).Value
   
    ## Get clock speed ##
    [double]$speed = $cpuname[-1].Trim('G')

    ## Get no of cores ##
    $candt = ($candt -split '/')
    $cores = $candt[0].Trim('C')
        
    ## Get no of threads ## 
    $threads = $candt[1].Trim('T')
    
    ## Get cache size ##
    $cache = $fulldesc[3].Trim()
    $cache = ($cache -split 'M')[0]

    ## Get transfer rate ##
    $gts = $fulldesc[2].Trim()
    $gts = ($gts -split 'G')[0]

    ## Get turbo on or off ##
    $turbo = $fulldesc[4].Trim()
    if($turbo -match 'no'){$turbo = $false}else{$turbo=$true}

    ## Get wattage ##
    [regex]$regex = '\([0-9]{2,3}W\)'
    $power = $regex.Matches($extra).Value.Trim('()W')   

    ## Get supported mem speed ##
    [regex]$regex = '[0-9]{4}'
    $ramspd = $regex.Matches($extra).Value   
    
    ## Calculated props ##

    $total = [int]$cores * $speed
    
    if ([int]$cores -eq [int]$threads) {$totalHT = $total} else {$totalHT = $total * 1.3}

    $processor = [pscustomobject]@{
        Level = $level
        Generation = $gen
        ClockSpeedGHz = $speed
        NumCores = $cores
        NumThreads = $threads
        CacheSizeMB = $cache
        'GT/S' = $gts
        Turbo = $turbo
        Wattage = $power
        SupportedMemSpeedMHz = $ramspd
        TotalGHz = $total
        TotalHT = $totalHT
    }
    $processors += $processor   
}
$processors