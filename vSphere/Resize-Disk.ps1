function Get-VMDiskMap {

    <#
    .NOTES
        ######################
            mail@nimbus117.co.uk
        ######################

        Based on a script by NiTRo - http://www.hypervisor.fr/?p=5070
    
    .SYNOPSIS
        Map VMWare hard disks to Windows guest disks.

    .DESCRIPTION
        Get-VMDiskMap uses vSphere PowerCLI and WMI to map VMWare hard disks to Windows guest disks by matching UUID's.
        It requires vSphere PowerCLI and an established connection to a vCenter server.
        By default remote WMI queries are made over RPC.
        When the guest VM can not be reached over the network the UseVIX switch parameter allows for the WMI query to be run via VMWare Tools.
        The current session credentials will be used to authenticate against the guest VM whether using RPC or VIX.
        Alternative guest credentials can by specified using the GuestCreds parameter.

    .PARAMETER VMName
        VM Object.

    .PARAMETER GuestCreds
        Windows guest credentials.

    .PARAMETER UseVIX
        Connect to the Windows guest via VIX (VMware Tools).

    .EXAMPLE
        PS C:\>Get-VM VM1 | Get-VMDiskMap | Format-Table

        VMName VMScsiId VMDisk      WinDisk VMSize WinSize VMPath
        ------ -------  ------      ------- ------ ------- ------
        VM1    0:0      Hard disk 1 Disk 0      30      30 [DS1] VM1/VM1.vmdk
        VM1    1:0      Hard disk 2 Disk 2      20      20 [DS1] VM1/VM1_1.vmdk
        VM1    2:0      Hard disk 3 Disk 3      20      20 [DS1] VM1/VM1_2.vmdk
        VM1    3:15     Hard disk 4 Disk 1      10      10 [DS1] VM1/VM1_3.vmdk


        Description

        -----------

        This command maps VMWare hard disks to Windows disks for VM1 and displays the results as a table.

    .EXAMPLE
        PS C:\>$creds = Get-Credential
        PS C:\>Get-VM *sql* | Get-VMDiskMap -GuestCreds $creds


        Description

        -----------

        The first comand prompts for and saves credentials to the variable $creds.
        The seccond command maps VMWare hard disks to Windows disks for all VM's with sql in their name, using the GuestCreds parameter with the saved credentials.

    .EXAMPLE
        PS C:\>$VM = Get-VM VM2,VM3
        PS C:\>Get-VMDiskMap -VM $VM -UseVIX -GuestCreds domain\user | Out-GridView


        Description

        -----------

        The first command saves the VirtualMachine objects to the variable $VM.
        The second command maps VMWare hard disks to Windows disks for VM2 and VM3 then displays the results in a grid.
        The UseVIX parameter runs the WMI query using VMWare Tools. The GuestCreds parameter prompts for a password when a username is specified.
    #>

    param (
    
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]
        $VM,
        [Parameter(Position=1)]
        [PSCredential][System.Management.Automation.CredentialAttribute()]
        $GuestCreds,
        [Switch]
        $UseVIX
    )

    process {

        $VM | ForEach-Object {

            try {

                $VMDevice = ($_ | Get-View -ea Stop).Config.Hardware.Device

                if (!$VMDevice) {throw 'No VM hard disks returned.'}

                if ($UseVIX) {
        
                    $ScriptText = "powershell.exe -NoProfile -Command `"Get-WmiObject Win32_DiskDrive ^| Select-Object SerialNumber,Index,Size ^| ConvertTo-CSV -NoTypeInformation`""

                    $Invoke_VMScriptParams = @{ScriptText = $ScriptText ; ScriptType = 'Bat'}

	                if ($GuestCreds) {$Invoke_VMScriptParams += @{GuestCredential = $GuestCreds}}
        
                    $WinDisks = ($_ | Invoke-VMScript @Invoke_VMScriptParams -ea Stop).ScriptOutput | ConvertFrom-Csv
	            }

                else {

                    $Get_WmiObjectParams = @{Class = 'Win32_DiskDrive' ; ComputerName = $_.Guest.HostName}

                    if ($GuestCreds) {$Get_WmiObjectParams += @{Credential = $GuestCreds}}

                    $WinDisks = Get-WmiObject @Get_WmiObjectParams -ea Stop | Select-Object SerialNumber,Index,Size
	            }

                if (!$WinDisks) {throw 'No WMI data returned.'}

                foreach ($SCSIController in ($VMDevice | Where-Object {$_.DeviceInfo.Label -match "SCSI Controller"})) {

                    foreach ($VMDisk in ($VMDevice | Where-Object {$_.ControllerKey -eq $SCSIController.Key})) {

	                    $WinDisk = $WinDisks | Where-Object {$_.SerialNumber -eq $VMDisk.Backing.Uuid.Replace('-','')}

	                    if ($WinDisk) {

                            [PSCustomObject]@{

                                VMName = $_.Name
                                VMScsiId = "{0}:{1}" -f $SCSIController.BusNumber,$VMDisk.UnitNumber
		                        VMDisk = $VMDisk.DeviceInfo.label
		                        WinDisk = 'Disk {0}' -f $WinDisk.Index
		                        VMSize = [Math]::Round($VMDisk.CapacityInKB/1MB, 1)
		                        WinSize = [Math]::Round($WinDisk.Size/1GB, 1)
		                        VMPath = $VMDisk.Backing.FileName
                            }
		                }
                    }
	            }
            }
            catch {Write-Error $_}
        }
    }
}

function Resize-Disk ($VM, $Credential)
{
    try
    {  
        #Initiate CIM sesh
        $CimSesh = New-CimSession -ComputerName $VM.guest.hostname -Credential $Credential
        #Select partition to resize
        $WinPart = get-partition -CimSession $CimSesh | Select disknumber, driveletter,
        @{l='SizeGB';e={[math]::Round($_.Size/1GB)}}, PartitionNumber,DiskPath | ogv -PassThru -Title 'Select Win partition:'
        #Get disk partition is on
        $WinDisk = Get-Disk -CimSession $CimSesh | ? path -eq "$($WinPart.DiskPath)" | Select-Object SerialNumber,DiskNumber,Size
        #Map win disk to vmdk
        $VmDiskMap = $VM | Get-VMDiskMap -GuestCreds $Credential | ? WinDisk -eq "Disk $($WinDisk.DiskNumber)"
        #Get vmdk
        $VmDisk = $VM | Get-HardDisk -Name $VMDiskMap.VMDisk

        #Enter new capacity
        $SizeGB = Read-Host -Prompt "Current capacity is $([math]::Round($WinPart.SizeGB))GB. Enter new capacity in GB"
        
        #Set vmdk capacity
        $VmDisk | Set-HardDisk -CapacityGB $SizeGB

        #Resize partition in guest
        $ScriptText = "
        Update-HostStorageCache
        `$MaxSize = (Get-PartitionSupportedSize -DriveLetter $($WinPart.DriveLetter)).sizeMax
        Resize-Partition -DriveLetter $($WinPart.DriveLetter) -Size `$MaxSize
        Get-Partition -DriveLetter $($WinPart.DriveLetter) |
        Select PSComputerName,DriveLetter,@{l='Size';e={[math]::Round(`$_.Size/1GB)}} |
        ConvertTo-CSV -NoTypeInformation"

        $Invoke_VMScriptParams = @{ScriptText = $ScriptText ; ScriptType = 'Powershell' ; GuestCredential = $Credential}
        
        $ResizedPart = ($VM | Invoke-VMScript @Invoke_VMScriptParams -ea Stop).ScriptOutput | ConvertFrom-Csv

        $ResizedPart
    }
    catch
    {
        Write-Warning 'Disk not resized'
    }
}

