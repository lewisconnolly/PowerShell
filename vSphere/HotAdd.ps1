Function HotAdd($vms){
 

      Foreach ($vm in $vms){

            $vmview = Get-vm $vm | Get-view
            $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

 

            $vmConfigSpec.MemoryHotAddEnabled = $true
            $vmConfigSpec.CPUHotAddEnabled = $true

            (Get-View $vm).name

            $vmview.ReconfigVM($vmConfigSpec)
      }

 

      
}



