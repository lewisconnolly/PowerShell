function Set-VIAlarmActions ($Entity, $Enabled) {

    $alarmMgr = Get-View AlarmManager
    $Entity | % { 
        $alarmMgr.EnableAlarmActions($_.Extensiondata.MoRef,$Enabled)
    }
}