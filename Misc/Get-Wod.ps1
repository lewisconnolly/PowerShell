function Get-Wod {
[Alias('wod')]
[CmdletBinding(DefaultParameterSetName='NoParams')]
Param(
    [Parameter(ParameterSetName='LastN')]
    [int]$LastN,

    [Parameter(ParameterSetName='All')]
    [switch]$All,

    [Parameter(ParameterSetName='Weekend')]
    [switch]$Weekend
)
    try {

        $wodfeed = Invoke-RestMethod "http://www.oed.com/rss/wordoftheday" |
        select title,link,
        @{n='definition';e={$_.description.replace('OED Word of the Day: ','').TrimStart(' ')}},
        @{n='pubDate';e={$_.pubDate.replace(' 00:00:00 -0400','')}}

        if ($LastN) {
            $wodfeed[-1..-$LastN]
        } elseif ($All) {
            $wodfeed
        } elseif ($Weekend) {
            $wodfeed | ? {($_.pubDate -like "Sat*") -or ($_.pubDate -like "Sun*")}
        } else {
            $wodfeed[-1]
        }
    }
    catch {throw}
    #import csv
    #get wodfeed where not in csv
    #write to csv
    #if last n greater than 7, get from csv
    #if all and weekend, get all weekend from csv
}


