Invoke-WebRequest -Uri "http://script-server.domain.local:8888/"

$command = "C:\Users\task-vmw-admin\Documents\AlertScripts\AlertCreator.ps1 -TRIGGERINGSUMMARY `"Metric CPU Usage = 100%`" -ALARMVALUE `"Current values for metric/state`" -ID `"alarm-6`" -NAME `"alarm.VmCPUUsageAlarm`" -EVENTDESCRIPTION `"Alarm 'Virtual machine CPU usage' on Robinsons changed from Yellow to Red`" -TARGET_ID `"vm-8794`" -OLDSTATUS `"Yellow`" -DECLARINGSUMMARY `"([Yellow metric Is above 75%; Red metric Is above 90%])`" -TARGET_NAME `"Robinsons`" -NEWSTATUS `"Red`" -VCENTER `"dca-vcenter`""
$command1 = "C:\Users\task-vmw-admin\Documents\AlertScripts\AlertCreator.ps1  -TRIGGERINGSUMMARY `"Metric CPU Usage = 100%`" -ALARMVALUE `"Current values for metric/state`" -ID `"alarm-6`" -NAME `"alarm.VmCPUUsageAlarm`" -EVENTDESCRIPTION `"Alarm 'Virtual machine CPU usage' on dca-cp-api2 changed from Green to Red`" -TARGET_ID `"vm-326187`" -OLDSTATUS `"Green`" -DECLARINGSUMMARY `"([Yellow metric Is above 75%; Red metric Is above 90%])`" -TARGET_NAME `"dca-cp-api2`" -NEWSTATUS `"Red`" -VCENTER `"dca-vcenter`""
Invoke-WebRequest -Uri "http://script-server.domain.local:8888/?command=$command"
Invoke-WebRequest -Uri "http://script-server.domain.local:8888/?command=$command1"



