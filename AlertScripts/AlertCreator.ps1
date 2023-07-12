Param
(
    $EVENT_DATASTORE,
     
    $EVENT_DVS,
     
    $TRIGGERINGSUMMARY,
     
    $EVENT_COMPUTERESOURCE,
     
    $EVENT_HOST,
     
    $ALARMVALUE,
     
    $ID,
     
    $EVENT_NETWORK,
     
    $EVENT_VM,
     
    $EVENT_USERNAME,
     
    $EVENT_DATACENTER,
     
    $NAME,
     
    $EVENTDESCRIPTION,
     
    $TARGET_ID,
     
    $OLDSTATUS,
     
    $DECLARINGSUMMARY,
     
    $TARGET_NAME,
     
    $NEWSTATUS,
     
    $VCENTER
)
<#
$env:VMWARE_ALARM_ALARMVALUE        ="Current values for metric/state"
$env:VMWARE_ALARM_DECLARINGSUMMARY  ="([Yellow metric Is above 75%; Red metric Is above 90%])"
$env:VMWARE_ALARM_EVENTDESCRIPTION  ="Alarm 'Virtual machine cpu usage' on lc-test changed from Green to Red'"
$env:VMWARE_ALARM_ID                ="alarm-6"
$env:VMWARE_ALARM_NAME              ="alarm.VmCPUUsageAlarm"
$env:VMWARE_ALARM_NEWSTATUS         ="Red"
$env:VMWARE_ALARM_OLDSTATUS         ="Green"
$env:VMWARE_ALARM_TARGET_ID         ="vm-319"
$env:VMWARE_ALARM_TARGET_NAME       ="TestCustomer"
$env:VMWARE_ALARM_TRIGGERINGSUMMARY ="Metric CPU Usage = 100%"
$env:VMWARE_ALARM_VCENTER= "dca-vcenter"
#>
<#
$env:VMWARE_ALARM_ALARMVALUE        ="Current values for metric/state"
$env:VMWARE_ALARM_DECLARINGSUMMARY  ="([Yellow metric Is above 75%; Red metric Is above 90%])"
$env:VMWARE_ALARM_EVENTDESCRIPTION  ="Alarm 'Host CPU usage' on zhost19.zhost changed from Green to Yellow"
$env:VMWARE_ALARM_ID                ="alarm-6"
$env:VMWARE_ALARM_NAME              ="alarm.HostCPUUsageAlarm"
$env:VMWARE_ALARM_NEWSTATUS         ="Yellow"
$env:VMWARE_ALARM_OLDSTATUS         ="Green"
$env:VMWARE_ALARM_TARGET_ID         ="host-246862"
$env:VMWARE_ALARM_TARGET_NAME       ="zhost19.zhost"
$env:VMWARE_ALARM_TRIGGERINGSUMMARY ="Metric CPU Usage = 79%"
$env:VMWARE_ALARM_VCENTER= "dca-vcenter"
#>

$env:VMWARE_ALARM_EVENT_DATASTORE=$EVENT_DATASTORE
$env:VMWARE_ALARM_EVENT_DVS=$EVENT_DVS
$env:VMWARE_ALARM_TRIGGERINGSUMMARY=$TRIGGERINGSUMMARY
$env:VMWARE_ALARM_EVENT_COMPUTERESOURCE=$EVENT_COMPUTERESOURCE
$env:VMWARE_ALARM_EVENT_HOST=$EVENT_HOST
$env:VMWARE_ALARM_ALARMVALUE=$ALARMVALUE
$env:VMWARE_ALARM_ID=$ID
$env:VMWARE_ALARM_EVENT_NETWORK=$EVENT_NETWORK
$env:VMWARE_ALARM_EVENT_VM=$EVENT_VM
$env:VMWARE_ALARM_EVENT_USERNAME=$EVENT_USERNAME
$env:VMWARE_ALARM_EVENT_DATACENTER=$EVENT_DATACENTER
$env:VMWARE_ALARM_NAME=$NAME
$env:VMWARE_ALARM_EVENTDESCRIPTION=$EVENTDESCRIPTION
$env:VMWARE_ALARM_TARGET_ID=$TARGET_ID
$env:VMWARE_ALARM_OLDSTATUS=$OLDSTATUS
$env:VMWARE_ALARM_DECLARINGSUMMARY=$DECLARINGSUMMARY
$env:VMWARE_ALARM_TARGET_NAME=$TARGET_NAME
$env:VMWARE_ALARM_NEWSTATUS=$NEWSTATUS
$env:VMWARE_ALARM_VCENTER=$VCENTER

function Write-Log {
    $AlertVars = Get-ChildItem env: | where name -like vmware* | ft -au
    $Log = "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\AlertCreator.log"
    Add-Content $Log -Value "----------------------------------------------------------------------------------"
    Add-Content $Log -Value "$(get-date)`r`nAlert triggered:$($AlertVars | out-string)Alert processed."
    Add-Content $Log -Value "----------------------------------------------------------------------------------"
}

switch ($env:VMWARE_ALARM_EVENTDESCRIPTION)
{
    {$_ -like "*Virtual machine*usage*"} {
    
        cd "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMProcessReport"

        & "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMProcessReport\Get-VMProcessReport.ps1" | Out-Null
        
        Write-Log
    }

    {$_ -like "*Host*usage*"} {

        cd "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMHostVisualReport\"

        & "\\zonalconnect\FolderRedirect$\lewisc\Documents\AlertScripts\Get-VMHostVisualReport\Get-VMHostVisualReport.ps1" | Out-Null
        Write-Log
    }

    Default { Write-Log }
}
