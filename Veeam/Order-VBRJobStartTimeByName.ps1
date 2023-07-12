function Order-VBRJobStartTimeByName ($Jobs)
{
    Add-PSSnapin VeeamPSSnapin

    function ResolveOrder ($jobs,$nameorder,$startorder)
    {
        $j=0
        $nameorder | % {
        
            $curjob = $_
            $otherjobs = ($jobs | ? name -ne $curjob.name)
            
            $duplicate_start_time = $curjob.starttime -in $otherjobs.starttime
            $nameorder_notmatch_startorder = $curjob.name -ne $startorder[$j].name
            
            if($duplicate_start_time-or$nameorder_notmatch_startorder)
            {   
                $curjobwrongposition = $false
                $curjobtooearly = $false

                # is it the current job with the wrong schedule based on name order or the job
                # in its schedule position
                if($nameorder_notmatch_startorder)
                {
                    $curjobwrongposition = $startorder[$j].name -eq $nameorder[$j].name
                }

                # do the jobs with the same schedule come before the current job by name order
                # i.e. does the current job start too early
                if($duplicate_start_time)
                {
                    $conflictjobs=($otherjobs | ? starttime -eq $curjob.starttime)
                    $curindex = $nameorder.IndexOf(($nameorder | ? name -eq $curjob.name))
                    
                    $curjobtooearly = $false
                    $checked = $false

                    while(!$curjobtooearly-and!$checked)
                    {
                        $conflictjobs | % {
                            $conflictindex = $nameorder.IndexOf(($nameorder | ? name -eq $_.name))
                            if($conflictindex-lt$curindex)
                            {
                                $curjobtooearly = $true
                            }
                        }
                        $checked = $true
                    }
                }
                
                if($curjobwrongposition -or $curjobtooearly)
                {
                    $before = $nameorder[$j-1].starttime
            
                    if($j -ne ($nameorder.count-1))
                    {
                        $after = $nameorder[$j+1].starttime
                    }
                    else
                    {
                        $after = $nameorder[0].starttime
                    }
           
                    $before = $before -split ':'
                    $before = get-date -Hour $before[0] `
                                    -Minute $before[1] `
                                    -Second 0 `
                                    -Millisecond 0
                
                    $after = $after -split ':'
                    $after = get-date -Hour $after[0] `
                                    -Minute $after[1] `
                                    -Second 0 `
                                    -Millisecond 0

                    $addmins = [math]::Floor((New-TimeSpan -Start $before -End $after ).TotalMinutes/2)
                    $newtime = ($before.AddMinutes($addmins)).TimeOfDay.ToString()

                    Get-VBRJob -Name $curjob.name | Set-VBRJobSchedule -Daily -At $timestr -DailyKind Everyday
                    
                    $jobs = Get-VBRJob  | select name,@{n='StartTime';e={
                        ($_|Get-VBRJobScheduleOptions).StartDateTimeLocal.timeofday.tostring()
                    }}

                    $startorder = $jobs | sort starttime
                }
            }
            
            $j++
        }

        CheckOrder -jobs $jobs
    }

    function CheckOrder ($jobs)
    {
        $nameorder = $jobs | sort name
        $startorder = $jobs | sort StartTime
        $sameorder = $true
        $nodups = $true

        $i = 0
        while(($sameorder-and$nodups)-and($i-lt$jobs.count))
        {
            $sameorder = $nameorder[$i].name -eq $startorder[$i].name
            $nodups = ($jobs | select starttime -Unique).count -eq $jobs.Count
            $i++
        }

        if($sameorder-and$nodups)
        {
            $jobs | sort name
        }
        else
        {   
            ResolveOrder -jobs $jobs -nameorder $nameorder -startorder $startorder
        }
    }

    CheckOrder -jobs $jobs
}

$JobsToOrder = $jobs = Get-VBRJob | ? jobtype -eq backup | select name,@{n='StartTime';e={
        ($_|Get-VBRJobScheduleOptions).StartDateTimeLocal.timeofday.tostring()
}} 

Order-VBRJobStartTimeByName -Jobs $JobsToOrder