function Get-VIAlarmActions ($Entity)
{
    $alarmMgr = Get-View AlarmManager
    $Entity | % { 
        $alarmMgr.AreAlarmActionsEnabled($_.ExtensionData.moref)
    }
}