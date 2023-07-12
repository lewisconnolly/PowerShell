function Clone-AlarmDefinition ($Name,$Description,$DefinitionToClone,$ActionToClone,$Entity,$AskToConfirm)
{
    $alarmdef = $DefinitionToClone
    $alarmMan = get-view ($global:DefaultVIServer).ExtensionData.content.alarmmanager
    $alarmspec = New-Object VMware.Vim.AlarmSpec

    $alarmname = $Name

    if(Get-AlarmDefinition -Name $alarmname -Entity $Entity -ErrorAction Ignore){"`nAlarm already exists`n"}else{

        $alarmdesc = $Description
        $alarmexp = $alarmdef.ExtensionData.Info.Expression
        
        if(!$ActionToClone){$ActionToClone = $DefinitionToClone.ExtensionData.Info.Action}
        $alarmaction = $ActionToClone
        
        $alarmsetting = (Get-AlarmDefinition -Name 'template_alarm').ExtensionData.info.setting


        $alarmspec.Name = $alarmname
        $alarmspec.Description = $alarmdesc
        $alarmspec.Expression = $alarmexp
        $alarmspec.Action = $alarmaction
        $alarmspec.Setting = $alarmsetting

        $alarmmoref = (get-view $Entity).MoRef

        $alarmspec
        
        if(!$AskToConfirm){
            $alarmMan.CreateAlarm($alarmmoref,$alarmspec)
            "`nAlarm created`n"
            Get-AlarmDefinition -Name $alarmspec.Name -Entity $Entity
        }else{
            $confirm = Read-Host -Prompt "Create alarm?[y/n]`n`nDefault is y`n`n" 

            if($confirm -eq '') {$confirm = 'y'}

            if($confirm -eq 'y'){
                $alarmMan.CreateAlarm($alarmmoref,$alarmspec)
                "`nAlarm created`n"
                Get-AlarmDefinition -Name $alarmspec.Name
            }else{"`nAlarm not created`n"}
        }
    }
}

<#
$def = Get-AlarmDefinition -Name "DCA - Host swapping"
$ent = get-datacenter DCB
$name = $def.name -replace 'DCA','TF'
$desc = $def.Description

Clone-AlarmDefinition -Name $name -Description $desc -DefinitionToClone $def -Entity $ent -AskToConfirm $true
#>