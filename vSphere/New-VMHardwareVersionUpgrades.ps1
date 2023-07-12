
function New-VMHardwareVersionUpgrade {
    Param (        
        [Parameter(Mandatory=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]
        $VMs
    )
    
    # Store provided VMs, create empty hashtable to store HV upgrade level per VM and create empty array to store VMs requiring upgrade

    $originalVMList = $VMs 
    $hvHT = @{}
    $VMs = @()

    $originalVMList | % {
        
        # Check HV upgrade level based on host version of each VM
        
        switch ($_.VMHost.Version){
            
            '6.7.0' { $hv = 'vmx-15' }
            '7.0.2' { $hv = 'vmx-19' }
            Default {}
        }

        # If HV not current, add to $VMs array

        if($_.HardwareVersion -ne $hv){ $VMs += $_ }
        
        # Add ID of VM as key with value as HV upgrade level to hashtable

        $hvHT += @{$_.Id = $hv}
    }

    if($VMs){
        
        "VMs requiring hardware version upgrade: $( ($VMs | sort Name).Name -join ', ' )" | Write-Host        

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

            # Exit if VMs requiring upgrade fail to shut down (required for upgrade)

            if((Get-VM -Id $VMs.Id).PowerState -contains 'PoweredOn'){
                
                "Failed to shut down $( (Get-VM -Id $VMs.Id | sort Name | ? PowerState -ne 'PoweredOff').Name -join ', ' )" | Write-Host
                "Exiting" | Write-Host        
                return
            }
        }

        # Set each VM to HV upgrade level (retrieve level from hashtable using Id of each VM)
        
        "Upgrading hardware versions" | Write-Host    
        $VMs | % { Set-VM -VM $_ -HardwareVersion $hvHT[$_.Id] -Confirm:0 | Out-Null }
        sleep 10

        # Start stopwatch to wait 60 seconds for upgrade and create list of VMs and current upgrade status (false if not yet at latest HV for host version)

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $upgrades = Get-VM -Id $VMs.Id | select Name, Id, @{n='UpgradeStatus';e={ if($_.HardwareVersion -ne $hvHT[$_.Id]){ $false }else{ $true } }}
        
        # While any VMs are still being upgraded and 60 seconds haven't elapsed, wait

        while(($upgrades.UpgradeStatus -contains $false) -and $stopwatch.IsRunning){
            
            "Waiting on hardware version upgrades" | Write-Host

            $upgrades = Get-VM -Id $VMs.Id | select Name, Id, @{n='UpgradeStatus';e={ if($_.HardwareVersion -ne $hvHT[$_.Id]){ $false }else{ $true } }}
            
            if($stopwatch.Elapsed.TotalSeconds -ge 60){            
                
                $stopwatch.Stop()
            }

            sleep 10
        }        
        
        # If after 60 seconds any VMs are not a latest HV then print them

        if($upgrades.UpgradeStatus -contains $false){
            
            "Hardware version not upgraded on $( ($upgrades | sort Name | ? UpdateStatus -eq $false).Name -join ', ' ) after 1 minute" | Write-Host
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

        # Stop stopwatch if VMs upgraded in less than 60 seconds and no VMs required starting, or VMs started in less than 30 seconds

        if($stopwatch){ $stopwatch.Stop() }

    }else{ "All VMs at latest hardware version" | Write-Host }
    
    # Output all provided VMs and their HVs

    Get-VM -Id $originalVMList.Id | select name, powerstate, HardwareVersion | sort name
}