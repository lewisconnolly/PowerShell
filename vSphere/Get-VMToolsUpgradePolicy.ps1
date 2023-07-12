function Get-VMToolsUpgradePolicy ($VM) {
    $VM | % {
        $vmview = get-view -VIObject $_
        $policy = $vmview.Config.Tools.ToolsUpgradePolicy
        [pscustomobject]@{
            Name=$_.name
            Policy = $policy
        }
    }
}
