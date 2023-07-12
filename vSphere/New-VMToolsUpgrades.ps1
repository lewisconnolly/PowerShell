
function New-VMToolsUpgrades {
    Param (        
        [Parameter(Mandatory=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]
        $VMs
    )    

    # Load function that sets multiple VMs' VMTools policies at once

    function Set-VmToolsUpgradePolicyParallel ($VMs, $Policy) {
        
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
        $vmConfigSpec.Tools.ToolsUpgradePolicy = $Policy
        
        (Get-View $VMs).ReconfigVM($vmConfigSpec)
    }
    
    # Store list of all provided VMs and store VMs that require VMTools upgrades in $VMs

    $originalVMList = $VMs 
    $VMs = Get-VM -Id $VMs.Id | ? {$_.ExtensionData.Guest.ToolsVersionStatus -eq 'guestToolsNeedUpgrade'}
    
    if($VMs){
    
        "VMs requiring VMTools upgrade: $( ($VMs | sort Name).Name -join ', ' )" | Write-Host
        
        # Set VMtools policy of VMs requiring upgrade to upgradeAtPowerCycle (easiest way to upgrade VMTools)

        "Setting VMTools upgrade policy of VMs to upgradeAtPowerCycle" | Write-Host
        Set-VmToolsUpgradePolicyParallel -VMs $VMs -Policy 'upgradeAtPowerCycle'

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

            # Exit if VMs requiring upgrade fail to shut down

            if((Get-VM -Id $VMs.Id).PowerState -contains 'PoweredOn'){
                
                "Failed to shut down $( (Get-VM -Id $VMs.Id | sort Name | ? PowerState -ne 'PoweredOff').Name -join ', ' )" | Write-Host
                "Setting VMTools upgrade policy of all provided VMs to manual" | Write-Host
                Set-VmToolsUpgradePolicyParallel -VMs $originalVMList -Policy 'manual'
                "Exiting" | Write-Host        
                return
            }
        }

        # Start VMs that require upgrade (should all be powered off) to kick off VMTools upgrade

        "Starting VMs" | Write-Host
        Get-VM -Id $VMs.Id | Start-VM | Out-Null
        sleep 5

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Wait for VMs to start and keep trying to start while waiting

        while(((Get-VM -Id $VMs.Id).PowerState -contains 'PoweredOff') -and $stopwatch.IsRunning){
            
            Get-VM -Id $VMs.Id | ? PowerState -ne 'PoweredOn' | Start-VM -ErrorAction Ignore | Out-Null
            
            "Waiting on all VMs to start" | Write-Host

            if($stopwatch.Elapsed.TotalSeconds -ge 30){            
                            
                $stopwatch.Stop()
            }

            sleep 5
        }

        # Check for powered off VMs that failed to start and print them

        if((Get-VM -Id $VMs.Id).PowerState -contains 'PoweredOff'){
            
            "Failed to start $( (Get-VM -Id $VMs.Id | sort Name | ? PowerState -ne 'PoweredOn').Name -join ', ' )" | Write-Host
        }
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # While any VMs are still being upgraded and 180 seconds haven't elapsed, wait

        while((((Get-VM -Id $VMs.Id).ExtensionData.Guest.ToolsVersionStatus | select -Unique) -ne 'guestToolsCurrent') -and $stopwatch.IsRunning){
            
            "Waiting on VMTools upgrades"

            if($stopwatch.Elapsed.TotalSeconds -ge 180){            
                            
                $stopwatch.Stop()
            }

            sleep 10
        }

        # Stop stopwatch if upgrades completed in less than 180 seconds

        $stopwatch.Stop()

        # Find VMs that still require VMTools upgrades (failed, still in progress or frozen) and print them

        if(((Get-VM -Id $VMs.Id).ExtensionData.Guest.ToolsVersionStatus | select -Unique) -ne 'guestToolsCurrent'){
            
            "VMTools not upgraded on $( (Get-VM -Id $VMs.Id | sort Name | ? {$_.ExtensionData.Guest.ToolsVersionStatus -ne 'guestToolsCurrent'}).Name -join ', ' ) after 3 minutes" | Write-Host
        }

        # Set upgrade policy to manual for all provided VMs (regardless of whether upgrade performed or not)

        "Setting VMTools upgrade policy of all provided VMs to manual" | Write-Host
        Set-VmToolsUpgradePolicyParallel -VMs $originalVMList -Policy 'manual'

        # Find powered on VMs that were originally powered off and stop them
        
        $toStop = Get-VM -Id $VMs.Id | % {
            
            $id = $_.Id
            if(($_.PowerState -eq 'PoweredOn') -and (($originalVMList | ? Id -eq $id).PowerState -eq 'PoweredOff')){ $_ }
        }
        
        if($toStop){
        
            "Shutting down VMs" | Write-Host
            $toStop | Stop-VMGuest -Confirm:0 | Out-Null
            sleep 10

            # Start stopwatch to wait 60 seconds for VMs to shut down

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # While any VMs are still powered on and 60 seconds haven't elapsed, keep trying to shut down VMs and wait

            while(((Get-VM -Id $toStop.Id).PowerState -contains 'PoweredOn') -and $stopwatch.IsRunning){                

                Get-VM -Id $toStop.Id | ? PowerState -ne 'PoweredOff' | Stop-VMGuest -Confirm:0 -ErrorAction Ignore | Out-Null

                "Waiting on VMs to shut down" | Write-Host
                
                if($stopwatch.Elapsed.TotalSeconds -ge 60){            
                    
                    "It's been 60 seconds. Force powering off VMs yet to shut down" | Write-Host            
                    Get-VM -Id $toStop.Id | ? PowerState -ne 'PoweredOff' | Stop-VM -Confirm:0 | Out-Null            
                    sleep 3

                    $stopwatch.Stop()
                }
                
                sleep 10
            }

            # Find VMs that failed to shut down and print them

            if((Get-VM -Id $toStop.Id).PowerState -contains 'PoweredOn'){
                
                "Failed to shut down $( (Get-VM -Id $toStop.Id | sort Name | ? PowerState -ne 'PoweredOff').Name -join ', ' )" | Write-Host            
            }
        }

        # Stop stopwatch if VMs upgraded in less than 60 seconds and no VMs required stopping, or VMs stopped in less than 60 seconds

        if($stopwatch){ $stopwatch.Stop() }

    }else{ "All VMTools up to date" | Write-Host }
    
    # Output VMTools status of all VMS

    Get-VM -Id $originalVMList.Id | select name, powerstate,
    @{n='ToolsVersionStatus';e={$_.ExtensionData.Guest.ToolsVersionStatus}},@{n='ToolsVersion';e={$_.ExtensionData.Guest.ToolsVersion}} |
    sort name
}