function AlertGrabber {

    Switch -Wildcard ($env:VMWARE_ALARM_TARGET_ID)
        {
            "vm-*" {
                $objectId = "VirtualMachine-" + $env:VMWARE_ALARM_TARGET_ID
                $AlertedObject = Get-VM -ID $objectId
            }
            "host-*" {
                $objectId = "HostSystem-" + $env:VMWARE_ALARM_TARGET_ID
                $AlertedObject = Get-VMHost -ID $objectId
            }
            "datastore-*" {
                $objectId = "Datastore-" + $env:VMWARE_ALARM_TARGET_ID
                $AlertedObject = Get-Datastore -ID $objectId
            }
            "datacenter-*" {
                $objectId = "Datacenter-" + $env:VMWARE_ALARM_TARGET_ID
                $AlertedObject = Get-Datacenter -ID $objectId
            }
            "domain-*" {
                $objectId = "ClusterComputeResource-" + $env:VMWARE_ALARM_TARGET_ID
                $AlertedObject = Get-Cluster -ID $objectId
            }
        }
    
    $header += "<b>$($DefaultVIServer.name.ToUpper())</b></td>"

    $header += "<td><ul><li>$($env:VMWARE_ALARM_EVENTDESCRIPTION.TrimEnd(`"'`"))</li>"

    $header += "<li>$($env:VMWARE_ALARM_DECLARINGSUMMARY -replace '[([\])]')</li>"

    <#$header += '<li><font color="'

    $header += $env:VMWARE_ALARM_NEWSTATUS
    
    $header += "`"><b>$env:VMWARE_ALARM_TRIGGERINGSUMMARY</b></font></li></ul>"
    #>
    $header += '<li><b>$env:VMWARE_ALARM_TRIGGERINGSUMMARY</b></li></ul>'

    $AlertGrab = [pscustomobject]@{

        HTMLHeader = $header
        AlertedObject = $AlertedObject
        AlertId = $env:VMWARE_ALARM_ID
        AlertDesc = $env:VMWARE_ALARM_EVENTDESCRIPTION
        AlertOldStatus = $env:VMWARE_ALARM_OLDSTATUS
        AlertStatus = $env:VMWARE_ALARM_NEWSTATUS
        AlertName = $env:VMWARE_ALARM_NAME
        AlertTargetId = $objectId
        AlertValue = $env:VMWARE_ALARM_ALARMVALUE

    }

    $AlertGrab

}

function Get-HTMLVMHostGraph {

Param(
    $VMHost,

    $LengthBar = 30

)

Begin {
      
    $Table = @()
    
}

Process {

    $VMHost | ForEach-Object {
        
        $vHost = [pscustomobject]@{

            Name          = $_.Name
            HostGHz       = [math]::round($_.CpuTotalMHz / 1000,0)
            HostGB        = [math]::round($_.ExtensionData.Summary.Hardware.MemorySize / 1GB,0)
            CPUUsageGHz   = [math]::round($_.CpuUsageMHz / 1000,0)
            MemoryUsageGB = [math]::round($_.MemoryUsageGB,0)
        }

        $UsedCPUBar = [math]::round($vHost.CPUUsageGHz / $vHost.HostGHz * $LengthBar,0)
        $FreeCPUBar = $LengthBar - $UsedCPUBar

        $UsedMEMBar = [math]::round($vHost.MemoryUsageGB / $vHost.HostGB * $LengthBar,0)
        $FreeMEMBar = $LengthBar - $UsedMEMBar



        $Table += [pscustomobject]@{

            Hostname = $vHost.name
            "CPU Usage" = "$("o" * $UsedCPUBar)$("_" * $FreeCPUBar): $($vHost.HostGHz)GHz  "
            "MEM Usage" = "$("o" * $UsedMEMBar)$("_" * $FreeMEMBar): $($vHost.HostGB)GB   "

        }
                
    }

}

End {

    $Table = $Table | ConvertTo-Html | Out-String

    $Table

}

}

function Get-HTMLTopVMList {

param(
    $Container,
    
    [int]$NbVM,

    [ValidateSet("descending","ascending")]
    [string]$sort
)

    Try {

        $AlertedHostVMs = $Container | Get-VM | where powerstate -eq poweredon


        if ($sort = "descending") {
            $TopVMCPU = $AlertedHostVMs | Sort-Object {$_.ExtensionData.Summary.QuickStats.OverallCpuDemand} -descending | select name,@{l="CPUDemand";e={$_.ExtensionData.Summary.QuickStats.OverallCpuDemand}},@{l="CPUUsage";e={$_.ExtensionData.Summary.QuickStats.OverallCpuUsage}} | select -First $NbVM
        } else {        
            $TopVMCPU = $AlertedHostVMs | Sort-Object {$_.ExtensionData.Summary.QuickStats.OverallCpuDemand} | select name,@{l="CPUDemand";e={$_.ExtensionData.Summary.QuickStats.OverallCpuDemand}},@{l="CPUUsage";e={$_.ExtensionData.Summary.QuickStats.OverallCpuUsage}} | select -First $NbVM
        }

        if ($sort = "descending") {
            $TopVMMEM = $AlertedHostVMs | Sort-Object {$_.ExtensionData.Summary.QuickStats.HostMemoryUsage} -Descending | select name,@{l="Consumed Mem";e={$_.ExtensionData.Summary.QuickStats.HostMemoryUsage}},@{l="Active Mem";e={$_.ExtensionData.Summary.QuickStats.GuestMemoryUsage}} | select -First $NbVM
        } else {
            $TopVMMEM = $AlertedHostVMs | Sort-Object {$_.ExtensionData.Summary.QuickStats.HostMemoryUsage} | select name,@{l="Consumed Mem";e={$_.ExtensionData.Summary.QuickStats.HostMemoryUsage}},@{l="Active Mem";e={$_.ExtensionData.Summary.QuickStats.GuestMemoryUsage}} | select -First $NbVM
        }
    
        $TopList = [pscustomobject]@{
            CPUHtml = $TopVMCPU | ConvertTo-Html | Out-String
            MEMHtml = $TopVMMEM | ConvertTo-Html | Out-String
        }

        $TopList

    } CATCH {
        Write-Error $_.Exception -ErrorAction Stop
    }

}

function Get-HTMLTopProcessList {

    param(
        $AlertedVM,
        $Description 
    )
            
    Try {
        
        switch ($Description)
        {
            {$_ -match "CPU"} {$SortBy = "% Processor Time"}
            {$_ -match "memory"} {$SortBy = "IO Data Bytes/sec"}
            Default {$SortBy=""}
        }       

        $PcsCpu = $AlertedVM | Invoke-VMScript -ScriptText `
        "(Get-Counter '\Process(*)\% Processor Time' -SampleInterval 60 -ErrorAction Ignore).countersamples |
        Group-Object -Property instancename |
        select count,name,@{n='% Processor Time';e={[math]::Round((`$_.group.cookedvalue|Measure-Object -sum).sum,2)}} |
        ? {(`$_.name -ne '_total') -and (`$_.name -ne 'idle')} | Convertto-JSON" -ScriptType Powershell
        $PcsIOPS = $AlertedVM | Invoke-VMScript -ScriptText `
        "(Get-Counter '\Process(*)\IO Data Operations/sec' -SampleInterval 60 -ErrorAction Ignore).countersamples |
        Group-Object -Property instancename |
        select count,name,@{n='IO Data Bytes/sec';e={[math]::Round((`$_.group.cookedvalue|Measure-Object -sum).sum,2)}} |
        ? {(`$_.name -ne '_total') -and (`$_.name -ne 'idle')} | Convertto-JSON" -ScriptType Powershell
        
        $PcsCpu = $PcsCpu.ScriptOutput -replace '[|]' | ConvertFrom-Json
        $PcsIOPS = $PcsIOPS.ScriptOutput -replace '[|]' | ConvertFrom-Json

        $TopProcessList = Join-Object -Left $PcsCpu -Right $PcsIOPS -LeftJoinProperty name -RightJoinProperty name `
        -Type OnlyIfInBoth -RightProperties 'IO Data Bytes/sec' | Sort $SortBy -Descending |
        ? {($_.'% Processor Time' -ne 0) -or ($_.'IO Data Bytes/sec' -ne 0)} | ConvertTo-Html | Out-String
            
        return $TopProcessList
    } 
    CATCH {  $ErrorMessage = "VM login failed"
              Break }
}

function Get-HTMLVMPerformanceGraph {

    param(
        $AlertedVM,
        $Description
    )

    switch ($Description)
    {
        {$_ -match "CPU"} {$metric = '"\Processor(_Total)\% Processor Time"'; $YTitle = "% Processor Time"}
        {$_ -match "memory"} {$metric = '"\Memory\Available MBytes"'; $YTitle = "% Available MBytes"}
        Default {$metric = '"\Processor(_Total)\% Processor Time"'; $YTitle = "% Processor Time"}
    }
    $counter = $AlertedVM | Invoke-VMScript -ScriptText "Get-Counter $metric -MaxSamples 61 -SampleInterval 1 | select timestamp,@{N='Value';E={`$_.CounterSamples.CookedValue}} | ConvertTo-Csv -NoTypeInformation" -ScriptType Powershell
    
    $Dataset = [ordered]@{}

    if ($Description -match "memory"){
        $totalMem = ($AlertedVM | Invoke-VMScript -ScriptText '(get-wmiobject -class "Win32_ComputerSystem" -namespace "root\CIMV2").TotalPhysicalMemory/1MB').ScriptOutput
        $counter.ScriptOutput | ConvertFrom-Csv | foreach {
            $Dataset[($_.TimeStamp -split 2018)[1].Trim()] = (($_.Value/$totalMem)*100)
        }
    } else {
        $counter.ScriptOutput | ConvertFrom-Csv | foreach {
            $Dataset[($_.TimeStamp -split 2018)[1].Trim()] = $_.Value
        }
    }

    # Create chart and save it
    $chart = New-Chart -Dataset $Dataset -XInterval 10 -YInterval 10 -YTitle $YTitle -Width 600 -Height 400
    $chart.ChartAreas["ChartArea1"].AxisY.Maximum = 100   
    $chart.ChartAreas["ChartArea1"].AxisX.IsMarginVisible = $false
    $chart.ChartAreas["ChartArea1"].AxisX.MajorGrid.LineColor =  [System.Drawing.Color]::LightGray
    $chart.ChartAreas["ChartArea1"].AxisY.MajorGrid.LineColor =  [System.Drawing.Color]::LightGray
    $chart.Series[0].Color = [System.Drawing.Color]::$env:VMWARE_ALARM_NEWSTATUS
    $chart.ChartAreas["ChartArea1"].AxisY.TitleFont = New-Object System.Drawing.Font("Microsoft Sans Serif",12,[System.Drawing.FontStyle]::Regular)
    $chart.SaveImage("\\domain\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMProcessReport\PerfChart.png","png")

}