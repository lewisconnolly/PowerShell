function Get-MoveVMParams ($VM, $DstHost, $DstDS, $DstNet, $DstFolder, $DstVC)
{
    @{
        VM = $VM
        Destination = $DstHost
        Datastore = $DstDS
        NetworkAdapter = $VM | Get-NetworkAdapter
        PortGroup = $DstNet
        InventoryLocation = $DstFolder
        Server = $DstVC
    }
}
