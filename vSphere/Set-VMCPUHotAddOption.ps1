
function Set-VMCPUHotAddOption {
    Param (        
        [Parameter(Mandatory=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]
        $VMs,

        [Parameter(Mandatory=$true)]
        [ValidateSet($true, $false)]
        $Enabled
    )
    
    # Store provided VMs and create empty array to store VMs requiring change

    $originalVMList = $VMs
    $VMs = $originalVMList | ? {$_.ExtensionData.Config.CpuHotAddEnabled -ne $Enabled}

    if($VMs){
    
        "VMs requiring CPU hot-add change: $( ($VMs | sort Name).Name -join ', ' )" | Write-Host        

        if(Get-VM -Id $VMs.Id | ? PowerState -ne 'PoweredOff'){
            
            "Shutting down VMs" | Write-Host
            Get-VM -Id $VMs.Id | ? PowerState -ne 'PoweredOff' | Stop-VMGuest -Confirm:0 | Out-Null
            sleep 10

            # Start stopwatch to wait 60 seconds for VMs to shut down

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # While any VMs are still powered on and 60 seconds haven't elapsed, keep trying to shut down VMs and wait

            while(((Get-VM -Id $VMs.Id).PowerState -contains 'PoweredOn') -and $stopwatch.IsRunning){                

                Get-VM -Id $VMs.Id | ? PowerState -ne 'PoweredOff' | Stop-VMGuest -Confirm:0 -ErrorAction Ignore | Out-Null

                "Waiting on VMs to shut down" | Write-Host
                
                if($stopwatch.Elapsed.TotalSeconds -ge 60){            
                    
                    "It's been 60 seconds. Force powering off VMs yet to shut down" | Write-Host            
                    Get-VM -Id $VMs.Id | ? PowerState -ne 'PoweredOff' | Stop-VM -Confirm:0 | Out-Null            
                    sleep 3

                    $stopwatch.Stop()
                }
                
                sleep 10
            }

            # Exit if VMs requiring change fail to shut down (required for change)

            if((Get-VM -Id $VMs.Id).PowerState -contains 'PoweredOn'){
                
                "Failed to shut down $( (Get-VM -Id $VMs.Id | sort Name | ? PowerState -ne 'PoweredOff').Name -join ', ' )" | Write-Host
                "Exiting" | Write-Host        
                return
            }
        }

        # Disable or enable CPU hot-add
        
        if($Enabled){ "Enabling CPU hot-add" | Write-Host }else{ "Disabling CPU hot-add" | Write-Host }
        
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec    
        $vmConfigSpec.CPUHotAddEnabled = $Enabled    
        (Get-View $VMs).ReconfigVM($vmConfigSpec)
                    
        # Find VMs where CPU hot-add change failed

        if((Get-VM -Id $VMs.Id).ExtensionData.Config.CpuHotAddEnabled -contains (!$Enabled)){
            
            "CPU hot-add failed to change on $( (Get-VM -Id $VMs.Id | ? {$_.ExtensionData.Config.CpuHotAddEnabled -ne $Enabled}).Name -join ', ' )" | Write-Host
        }

        # Find powered off VMs that were originally powered on and start them
        
        $toStart = Get-VM -Id $VMs.Id | % {
            
            $id = $_.Id
            if(($_.PowerState -eq 'PoweredOff') -and (($originalVMList | ? Id -eq $id).PowerState -eq 'PoweredOn')){ $_ }
        }
        
        if($toStart){
        
            "Starting VMs" | Write-Host
            $toStart | Start-VM | Out-Null
            sleep 5

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Wait for VMs to start and keep trying to start while waiting

            while(((Get-VM -Id $toStart.Id).PowerState -contains 'PoweredOff') -and $stopwatch.IsRunning){
                
                Get-VM -Id $toStart.Id | ? PowerState -ne 'PoweredOn' | Start-VM -ErrorAction Ignore | Out-Null
                
                "Waiting on all VMs to start" | Write-Host

                if($stopwatch.Elapsed.TotalSeconds -ge 30){            
                                
                    $stopwatch.Stop()
                }

                sleep 5
            }        

            # Check for powered off VMs that were originally powered on that failed to start and print them

            if((Get-VM -Id $toStart.Id).PowerState -contains 'PoweredOff'){
                
                "Failed to start $( (Get-VM -Id $toStart.Id | sort Name | ? PowerState -ne 'PoweredOn').Name -join ', ' )" | Write-Host
            }
        }

        # Stop stopwatch if VMs shut down in 60s, no VMs required starting or VMs started in less than 30 seconds

        if($stopwatch){ $stopwatch.Stop() }

    }else{ "No CPU hot-add options need to be changed" | Write-Host }
        
    # Output all provided VMs and their CPU hot-add configuration

    Get-VM -Id $originalVMList.Id | select name, powerstate,
    @{n='CpuHotAddEnabled';e={$_.ExtensionData.Config.CpuHotAddEnabled}} |
    sort name
}