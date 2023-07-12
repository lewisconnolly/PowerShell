
function Copy-VMFolderPath {
    param (
        $Folder,
        $DestinationServer,
        $DestinationDatacenter
    )
    
    # Add Get-VIFolderPath function
    . $env:OneDriveConsumer\Documents\WindowsPowerShell\Modules\vSphereScripts\Get-VIFolderPath.ps1

    # Get paths of passed in folder(s)
    $paths = $Folder | % { (Get-VIFolderPath -VIObject $_) + "\$( $_.Name )" }
    
    $paths | % {

        # Convert path to array
        $split = $_ -split "\\"
        # Remove root datacenter and 'vm' folders
        $folders = $split[2..($split.count-1)]
        # Set command for getting root vm folder in datacenter
        $command = "Get-Folder -Name vm -server $DestinationServer -location $DestinationDatacenter"
        # $continue = $true
        
        $folders | % {            
            
            # Get id of current folder's parent
            $parid = (Invoke-Expression $command -ErrorAction SilentlyContinue).id
            # Append to command the command for getting the current folder (use parent ID to avoid getting different folder with same name)
            $newCommand = $command + "| Get-Folder -Name '$_' -ErrorAction SilentlyContinue | ? Parentid -eq '$parid'"
            # Check if the current folder exists in target server and datacenter
            $testNewCommand = Invoke-Expression $newCommand -ErrorAction SilentlyContinue
            if($testNewCommand){
                # If the folder exists, make the new root command contain it
                $command = $newCommand
            }else{                                
                # If the folder doesn't exist create it
                Invoke-Expression ($command + "| New-Folder -Name '$_'")
                $command = $newCommand                
                    
            }            
        }
    }
}


# Example
# $TFVMFolders = get-folder -Location TF -Server vcenter* | ? type -eq VM | ? name -ne vm | ? name -ne 'Discovered virtual machine'
# $TFVMFolders = $TFVMFolders | ? {(($_|gvm|Measure).count -ne 0) -and ($_.Name -ne 'Templates')}

# Copy-VMFolderPath -Folder $TFVMFolders -DestinationServer 'ztsvcenter*' -DestinationDatacenter 'TF'