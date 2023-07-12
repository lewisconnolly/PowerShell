function Get-LastWeekDayOfMonthForward {

    Param (
        [DateTime] $StartDate = (Get-Date),
        [string] $WeekDay = "Monday", 
	    [int] $NumberOfMonths = 1,
        [switch] $IncludeStartDate
    ) 

    $dates = @()
    if($IncludeStartDate){$dates+=$StartDate}

    (0..($NumberOfMonths-1)) | % {

        $i=1
        $lastWeekDayOfMonth=0
        
        while(
            !(
                ($StartDate.AddDays($i).DayOfWeek -eq $WeekDay) -and 
                ($StartDate.AddDays($i).Month -eq $StartDate.AddMonths(1).Month) -and
                ($lastWeekDayOfMonth -eq 1)
            )
        ){
            $i++

            if($StartDate.AddDays($i+7).Month -eq $StartDate.AddDays($i).AddMonths(1).Month){
                $lastWeekDayOfMonth = 1
            }else{$lastWeekDayOfMonth = 0}
        }
        $LastDate = $StartDate.AddDays($i)
        $dates += $LastDate
        $StartDate = $LastDate
    }
    $dates | sort date | select @{n='Dates';e={get-date $_ -Format d/M/y}}, DayOfWeek
}
