Function Enable-VMHotAdd($VM){

    $VM | % {

        $vmview = Get-vm $_ | Get-view
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

        $vmConfigSpec.MemoryHotAddEnabled = $true
        $vmConfigSpec.CPUHotAddEnabled = $true

        $vmview.ReconfigVM($vmConfigSpec) | Out-Null
    }
}