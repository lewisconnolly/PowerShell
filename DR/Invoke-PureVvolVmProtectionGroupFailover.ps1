<#
.SYNOPSIS
    Create replicas of all vVol VMs in a Pure Storage Protection Group with a replication target that is a Pure Storage FlashArray with an ESXi connected vVol datastore.
.DESCRIPTION
    This function takes an SPBM Replication Group object that represents a Pure Storage Protection Group and creates replica VM files of its member VMs. Said files can then be registered to an ESXi cluster connected to the Protection Group's target Pure Storage FlashArray's vVol datastore.

    It then enables replication of newly created replica vVol VMs back to the source FlashArray.

    A storage policy is created if it doesn't already exist and is then applied to the replica VMs if they are registered in the VM inventory.

    Optional parameters are included to shut down and/or remove source VMs and to synchronise Protection Groups before creation of replica vVol VMs.
.PARAMETER SpbmReplicationGroup
    The object of a Storage Policy-Based Management Replication Group that represents a Pure Storage Protection Group. Must be a single object. Returned by Get-SpbmReplicationGroup Cmdlet.
.PARAMETER ReplicaVmsSuffix
    The string to append to the source VM names for use as replica VM names. 
.PARAMETER RegisterReplicaVms
    Include if replica VMs are to be registered in destination cluster. If used without -DestinationCluster and/or -DestinationFolder they will be automatically chosen.
.PARAMETER DestinationCluster
    The destination cluster where the replica VMs are to be registered. Must be connected to target array's vVol datastore.
.PARAMETER DestinationFolder
    The destination folder where the replica VMs are to be registered. Must be available in the same datacenter as the target array's vVol datastore.
.PARAMETER FlashArrayCredential
    The credential object for the source and target Pure Storage FlashArrays. Username should not contain domain name prefix, e.g "ZONALCONNECT\lewisc".
.PARAMETER SyncProtectionGroup
    Create and replicate an on-demand snapshot from the source Protection Group before creating the replica VMs.
.PARAMETER MostRecentSnapshot
    Use the most recently replicated source Protection Group snapshot to create the replica VMs from.    
.PARAMETER ShutdownSourceVmsFirst
    Shut down the source VMs before creating the replica VMs.
.PARAMETER RemoveSourceVms
    Shut down the source VMs if they are still powered on and remove from inventory after the replica VMs have been created. 
.PARAMETER RemoveSourceVmsPermanently
    Shut down the source VMs if they are still powered on and delete from disk after the replica VMs have been created. 
.EXAMPLE
    #
    # Create replicas of VMs in TestSvc-Repl8hrsRetain48hrs-NoSnap Pure Storage Protection Group on FlashArray dca-flasharray2
    # Register replica VMs as "<SourceVmName>_replica"
    # $faCred has previously been assigned to appropriate credential
    # -DestinationFolder omitted and so is chosen automatically
    # Source VMs are shut down before creation of replicas
    # Output verbose logging messages
    
    Invoke-PureVvolVmProtectionGroupFailover -SpbmReplicationGroup (Get-SpbmReplicationGroup -Name 'dca-flasharray2:TestSvc-Repl8hrsRetain48hrs-NoSnap') `
    -ReplicaVmsSuffix '_replica' `
    -DestinationCluster (Get-Cluster DCB*) `
    -FlashArrayCredential $faCred `
    -ShutdownSourceVmsFirst `
    -Verbose
.OUTPUTS
    $null or UniversalVirtualMachineImpl objects or vmx file path strings.
.NOTES
    Module dependencies:

    Name                               TestedVersion
    ----                               -------
    PureStorage.FlashArray.VMware.VVol 1.4.0.2
    PureStoragePowerShellSDK           1.17.3.0
    VMware.Vim                         7.0.0.15939650
    VMware.VimAutomation.Core          12.0.0.15939655
    VMware.VimAutomation.Storage       12.0.0.15939648
#>
function Invoke-PureVvolVmProtectionGroupFailover {
    [CmdletBinding(DefaultParameterSetName='Remove source VMs',
                   PositionalBinding=$false)]
    [Alias()]
    [OutputType([VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl[]])]
    [OutputType([String[]])]
    Param (        
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Alias("ProtectionGroup")]
        [ValidateScript({ $_.PSObject.TypeNames[0] -eq 'VMware.VimAutomation.Storage.Impl.V1.Spbm.Replication.SpbmReplicationGroupImpl' })]
        $SpbmReplicationGroup,

        [Parameter(Mandatory=$true)]
        [Alias("Suffix")]
        [String]
        $ReplicaVmsSuffix,

        [Alias("Register")]
        [Switch]
        $RegisterReplicaVms,

        [Alias("Cluster")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.PSObject.TypeNames[0] -eq 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl' })]
        $DestinationCluster,

        [Alias("Folder")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.PSObject.TypeNames[0] -eq 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl' })]
        $DestinationFolder,

        [Alias("FaCred")]
        [Parameter(Mandatory=$true)]
        [PSCredential]
        $FlashArrayCredential,

        [Alias("Sync")]
        [Switch]
        $SyncProtectionGroup,

        [Switch]
        $MostRecentSnapshot,

        [Alias("ShutdownSource")]
        [Switch]
        $ShutdownSourceVmsFirst,

        [Alias("RemoveSource")]
        [Parameter(ParameterSetName='Remove source VMs')]
        [Switch]
        $RemoveSourceVms,

        [Alias("DeleteSource")]
        [Parameter(ParameterSetName='Remove source VMs permanently')]
        [Switch]
        $RemoveSourceVmsPermanently
    )

    process {
        try {
            
            # Create helper function used throughout
            
            function Confirm-Continue {
                param (
                    $Warning,
                    $Prompt,
                    $ScriptIfNo,
                    $ScriptIfYes
                )
                
                # Display specified warning

                if($Warning){ $Warning | Write-Warning }
                
                # Discard invalid input

                while($confirm -notin @('y','n')){
                    $confirm = Read-Host -Prompt $Prompt
                    "" | Write-Host
                    # Warn on invalid input
                
                    if(!$confirm -or ($confirm -notin @('y','n'))){ "Invalid input, enter y or n" | Write-Warning } 
                }

                # Run specified script depending on user input

                if($confirm -eq 'n'){
                    if($ScriptIfNo){ Invoke-Command -ScriptBlock $ScriptIfNo }
                } else {
                    if($ScriptIfYes){ Invoke-Command -ScriptBlock $ScriptIfYes }
                }
            }                        
            
            "$( (Get-Date).ToString() ) Checking required modules are installed ...`n" | Write-Verbose
            
            # Check for module dependencies

            'VMware.Vim', 'VMware.VimAutomation.Core', 'VMware.VimAutomation.Storage',
            'PureStorage.FlashArray.VMware.VVol', 'PureStoragePowerShellSDK' | % {

                # If module not loaded, check if available

                if(!(Get-Module -Name $_)){
                    
                    # if module available then import

                    if(Get-Module -ListAvailable | ? {$_.name -eq $_}){
                        Import-Module -Name $_
                    
                    # If module not available, throw error and exit
                    
                    } else {
                        if($_ -like "VMware*"){
                            throw "`n$( (Get-Date).ToString() ) Install module manifest VMware.PowerCLI to get module $_ before using this function`n"  
                        } else { throw "`n$( (Get-Date).ToString() ) Install module $_ before using this function`n" }
                    }
                }
            }

            # Validate parameters

            "$( (Get-Date).ToString() ) Validating parameters ...`n" | Write-Verbose
                        
            # Check a vCenter is connected

            if(!$global:DefaultVIServer){
                Confirm-Continue -Warning "$( (Get-Date).ToString() ) No connected VI servers" `
                -Prompt "`nAttempt to connect to vcenter.zonalconnect.local? [y/n]`n" `
                -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                -ScriptIfYes {
                    "`n$( (Get-Date).ToString() ) Connecting to vcenter.zonalconnect.local ...`n" | Write-Host
                    Connect-VIServer vcenter.zonalconnect.local | Out-Null }                           
                
                if($exit){ return }
            }

            # Get VMs from source Protection Group

            $sourceVms = $SpbmReplicationGroup | Get-VM

            if(!$sourceVms){ throw "`n$( (Get-Date).ToString() ) SBPM Replication Group $( $SpbmReplicationGroup.Name ) does not contain any vVol VMs`n" } else {
                "`n$( (Get-Date).ToString() ) Creating replicas of source VMs:`n`n" + ($sourceVms.Name -join "`n") + "`n" | Write-Host
            }

            # Get corresponding Protection Group on target array

            $tgtReplGroup = Get-SpbmReplicationPair -Source $SpbmReplicationGroup | select -ExpandProperty target

            if(!$tgtReplGroup){ throw "`n$( (Get-Date).ToString() ) Unable to retrieve corresponding Protection Group for $( $SpbmReplicationGroup.name ) on target array`n" }
            
            # Exit if the Protection Group is already in a failed over state
            
            if($tgtReplGroup.State -eq 'FailedOver'){
                throw "`n$( (Get-Date).ToString() ) Target replication group $( ($tgtReplGroup.Description -split ' ')[0] ) on $( $tgtReplGroup.FaultDomain.Name ) is already in the FailedOver state`n"
            }

            # Get vVol datastore of target array

            $tgtDatastore = Get-Datastore | ? Type -eq 'VVOL' | ? {$_.ExtensionData.Info.VvolDS.StorageArray.Name -eq $tgtReplGroup.FaultDomain.Name}
            
            # Throw error and exit if no vVol datastore for target array

            if(!$tgtDatastore){ throw "`n$( (Get-Date).ToString() ) Unable to find vVol datastore for target array`n" }

            # Test source FlashArray credential (mandatory)
                        
            "$( (Get-Date).ToString() ) Connecting to $( $SpbmReplicationGroup.FaultDomain.Name ) ...`n" | Write-Verbose
            $sourceFlashArray = New-PfaArray -EndPoint $SpbmReplicationGroup.FaultDomain.Name -Credentials $FlashArrayCredential -IgnoreCertificateError
 
            if(!$sourceFlashArray){ throw "`n$( (Get-Date).ToString() ) Couldn't connect to $( $SpbmReplicationGroup.FaultDomain.Name )`n" }            
 
            # Test target FlashArray credential (mandatory)
 
            "$( (Get-Date).ToString() ) Connecting to $( $tgtReplGroup.FaultDomain.Name ) ...`n" | Write-Verbose
            $targetFlashArray = New-PfaArray -EndPoint $tgtReplGroup.FaultDomain.Name -Credentials $FlashArrayCredential -IgnoreCertificateError
 
            if(!$targetFlashArray){ throw "`n$( (Get-Date).ToString() ) Couldn't connect to $( $tgtReplGroup.FaultDomain.Name )`n" }
            
            # Check replica vVols don't already exist on target array

            $sourceVms | % {
                $sourceVm = $_
                
                $sourceVm.ExtensionData.LayoutEx.File | ? {($_.type -eq 'config') -or ($_.type -eq 'diskDescriptor')} | % {
                    
                    # Try block required to ignore error because Get-PfaVolumeNameFromVvolUuid creates a terminating error if no vVols found,
                    # even when setting ErrorAction to SilentlyContinue
                    
                    try{
                        if(Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray -VvolUUID $_.BackingObjectId){
                            "`n$( (Get-Date).ToString() ) $( $sourceVm.Name ) vVol $( $_.Name ) already exists on $( $tgtReplGroup.FaultDomain.Name )`n" | Write-Error                        
                            $exit = $true
                        }
                    } catch {}
                }
            }

            if($exit){ return }

            # If replica VMs are to be registered, check for VMs with same names + replica suffix as specified and throw error then exit if they exist
                        
            if($RegisterReplicaVm -or $DestinationCluster -or $DestinationFolder){
                $sourceVms | % {
                    if((Get-VM ($_.Name + $ReplicaVmsSuffix) -ErrorAction SilentlyContinue)){
                        throw "`n$( (Get-Date).ToString() ) VM with name $( $_.Name + $ReplicaVmsSuffix ) already exists in connected vcenter(s): $( $global:DefaultVIServers.Name -join '/')`n"
                    }
                }
            }
            
            # If -DestinationCluster provided then check it is connected to target array vVol datastore
            
            if($DestinationCluster){
                if(($DestinationCluster | Get-Datastore | select -ExpandProperty Name) -notcontains $tgtDatastore.Name){
                    throw "`n$( (Get-Date).ToString() ) Target datastore $( $tgtDatastore.Name ) is not accessible by destination cluster`n"
                }
            }
            
            # If provided -DestinationFolder folder doesn't exist, confirm use of 'Discovered virtual machine' folder in datacenter of target datastore

            if($DestinationFolder){
                if(($tgtDatastore.Datacenter | Get-Folder | select -ExpandProperty Id) -notcontains $DestinationFolder.Id){
                    Confirm-Continue -Warning  "$( (Get-Date).ToString() ) $( $DestinationFolder.Name ) folder doesn't exist at target site" `
                    -Prompt "`nUse 'Discovered virtual machine' folder? [y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                    -ScriptIfYes { $script:DestinationFolder = Get-Folder 'Discovered virtual machine' -Location $tgtDatastore.Datacenter }

                    if($exit){ return }
                }
            }

            # Take a new storage snapshot and replicate to the target array before failover if -SyncProtectionGroup switch specified
            
            if($SyncProtectionGroup){
                "`n$( (Get-Date).ToString() ) Synchronising Protection Group $( $SpbmReplicationGroup.name ) ...`n" | Write-Host                                                
                "$( (Get-Date).ToString() ) Creating new snapshot for Protection Group $( $SpbmReplicationGroup.name ) to be replicated to $( $tgtReplGroup.FaultDomain.Name ) ...`n" |
                Write-Verbose

                # Take snapshot for source Protection Group and replicate. Apply retention policy if number of snapshots exceeds retention setting

                $newSnap = New-PfaProtectionGroupSnapshot -Array $sourceFlashArray -ProtectionGroups ($SpbmReplicationGroup.name -split ':')[1] `
                -ReplicateNow -ApplyRetention
                
                if($newSnap){
                                    
                    # Wait for the snapshot to be replicated

                    while((($tgtReplGroup | Get-SpbmPointInTimeReplica).id -join ', ') -eq ($replSnapshots.id -join ', ')){
                        "$( (Get-Date).ToString() ) Waiting on new snapshot to be replicated to target array ...`n" | Write-Verbose
                        sleep 5
                    }
                } else {
                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) Unable to create new snapshot" `
                    -Prompt "`nContinue? [y/n]`n" -ScriptIfNo { "`nExiting ...`n" | Write-Host; $script:exit = $true }

                    if($exit){ return }
                }
                
                # Get storage snapshots replicated to the target array (including new snapshot)

                $script:replSnapshots = $tgtReplGroup | Get-SpbmPointInTimeReplica
            } else {
                
                # Get storage snapshots replicated to the target array 

                $script:replSnapshots = $tgtReplGroup | Get-SpbmPointInTimeReplica
            }

            # If snapshots exist on the array, proceed to snapshot selection

            if($replSnapshots){
                
                # If -MostRecentSnapshot switch not provided, proceed to snapshot selection

                if(!$MostRecentSnapshot){
                    
                    # If only one snapshot exists, confirm selection of it

                    if ($replSnapshots.Count -eq 1){
                        $prompt =
                        "`nThere is only one snapshot. Do you want replicas to be created from $( get-date ($replSnapshots).CreationTime -Format 'dd/MM/yyyy - HH:mm:ss' ) snapshot? [y/n]`n"
                        Confirm-Continue -Prompt $prompt `
                        -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                        -ScriptIfYes { $script:replSnapshot = $replSnapshots }

                        if($exit){ return }

                    } else {

                        # Set snapshot selection number

                        $n = 1

                        # Output snapshot selection menu to console host

                        "`n$( $SpbmReplicationGroup.Name ) snapshots:`n" | Write-Host
                        $replSnapshots | sort CreationTime -Descending | % {
                            "$n) $( get-date $_.CreationTime -Format 'dd/MM/yyyy - HH:mm:ss' )" | Write-Host
                            $n++
                        }

                        # Prompt for user selection of snapshot. Discard invalid input

                        while($replSnapshot -notin (1..($n-1))){
                            $replSnapshot = Read-Host -Prompt "`nEnter snapshot number (1-$( $n-1 )) to create replicas from`n"
                            "" | Write-Host

                            # Warn on invalid input

                            if(!$replSnapshot -or ($replSnapshot -notin (1..($n-1)))){
                                "Invalid input, enter a number between 1 and $( $n-1 )" | Write-Warning
                            }
                        }

                        # Output confirmation of chosen snapshot

                        "$( (Get-Date).ToString() ) Replicas will be created from $( get-date ($replSnapshots | sort CreationTime -Descending)[$replSnapshot-1].CreationTime -Format 'dd/MM/yyyy - HH:mm:ss' ) snapshot`n" |
                        Write-Host

                        # Store chosen snapshot

                        $replSnapshot = ($replSnapshots | sort Creationtime -Descending)[$replSnapshot-1]
                    }            
                } else {
                    
                    # Get most recent snapshot
                    
                    $script:snap = ($replSnapshots | sort CreationTime -Descending)[0]
                    
                    # Convert date of snapshot to UK format and ask for confirmation

                    $snapTime = get-date $snap.CreationTime -Format 'dd/MM/yyyy - HH:mm:ss'

                    # Confirm choice of most recent snapshot if -MostRecentSnapshot specified

                    Confirm-Continue -Prompt "`nDo you want replicas to be created from the most recent snapshot: $snapTime ? [y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                    -ScriptIfYes { $script:replSnapshot = $snap }

                    if($exit){ return }
                }

            # Throw error and exit if no snapshots have been replicated to target array
            
            } else { throw "`n$( (Get-Date).ToString() ) Unable to retrieve snapshots on target array`n" }

            # Shut down source VMs if -ShutdownSourceVmsFirst specified

            if($ShutdownSourceVmsFirst){
                "`n$( (Get-Date).ToString() ) Shutting down source VMs ...`n" | Write-Host
                
                # Attempt guest OS shutdown process for all source VMs
                
                $sourceVms | ? PowerState -ne 'PoweredOff' | Stop-VMGuest | Out-Null
                if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
                
                # Create stopwatch to wait 60 seconds for guest OS shutdowns down to finish                    

                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # While waiting for shutdown, check time on stopwatch

                while((((Get-VM $sourceVms).PowerState | select -Unique) -ne 'PoweredOff') -and $stopwatch.IsRunning){
                    "`n$( (Get-Date).ToString() ) Waiting on guest OS shutdowns to finish ...`n" | Write-Host
                    
                    # If all VMs not in powered off state after 60 seconds then confirm force power off
                    
                    if($stopwatch.Elapsed.TotalSeconds -ge 60){
                        "`n$( (Get-Date).ToString() ) It has been at least 60 seconds and not all source VMs have shut down. Confirm if you want to power off VMs ...`n" | Write-Host
                        Get-VM $sourceVms | ? PowerState -ne 'PoweredOff' | Stop-VM | Out-Null
                        if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

                        # Stop stopwatch once VM force powered off or not
                        
                        $stopwatch.Stop()
                    }
                    sleep 5
                }

                if(((Get-VM $sourceVms).PowerState | select -Unique) -ne 'PoweredOff'){
                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) Failed to shut down/power off $( (Get-VM $sourceVms | sort Name | ? PowerState -ne 'PoweredOff').Name -join ', ' )" `
                    -Prompt "`nContinue? [y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }

                    if($exit){ return }
                } 
            }

            # Store disks in source Protection Group to re-apply storage policy to once source Protection Group has been recreated

            $sourceDisks = $SpbmReplicationGroup | Get-HardDisk
            "`n$( (Get-Date).ToString() ) Starting failover ...`n" | Write-Host
            
            # Set state of target replication group to "FailedOver" and create vVols on target array. Store VM datastore paths in $replicaVms for later registration 
            # Automatically create Protection Group on target array for replicating failed over vVols back to source array
            
            $replicaVms = Start-SpbmReplicationFailover -ReplicationGroup $tgtReplGroup -PointInTimeReplica $replSnapshot -Confirm:1
            if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
            
            # Throw error and exit if no paths for replica VMs or unable to retrieve target array vVol datastore 

            if(!$replicaVms){
                throw "`n$( (Get-Date).ToString() ) Unable to failover source VMs or find replicated config vVols. Check status of VASA providers and target vVol datastore`n"
            } else {                        
                
                # If replica VMs are to be registered in inventory, continue to placement
                
                if($RegisterReplicaVms -or $DestinationCluster -or $DestinationFolder){
                    if(!$DestinationCluster){
                        "$( (Get-Date).ToString() ) No destination cluster provided. Selecting first returned cluster that can access target datastore ...`n" | Write-Verbose
                        
                        # Select first returned cluster connected to target array vVol datastore
                        
                        $DestinationCluster = $tgtDatastore.Datacenter | Get-Cluster |
                        ? {($_ | Get-Datastore | select -ExpandProperty Name) -contains $tgtDatastore.Name} | select -First 1                                                
                    }
                    
                    # Skip VM registration if no clusters in destination datacenter connected to target vVol datastore

                    if(!$DestinationCluster){
                        "$( (Get-Date).ToString() ) Target datastore is not accessible by clusters in target datacenter. Skipping registration of replica VMs ...`n" | Write-Warning
                    } else {
                        "`n$( (Get-Date).ToString() ) Destination cluster is $( $DestinationCluster.Name )`n" | Write-Host
                        
                        if(!$DestinationFolder){

                            # If no destination folder provided, try to use folder with same name as majority of source VMs' folder but in destination datacenter

                            "$( (Get-Date).ToString() ) No destination folder provided. Selecting folder in target datacenter with same name as source folder containing most (or tied most) of the source VMs ...`n" |
                            Write-Verbose
                            $DestinationFolder = Get-Folder ($sourceVms | group Folder | sort Count)[-1].Name -Location $tgtDatastore.Datacenter
                            
                            # If same name folder doesn't exist, use 'Discovered virtual machine folder'
                            
                            if(!$DestinationFolder){
                                "$( (Get-Date).ToString() ) $( ($sourceVms | group Folder | sort Count)[-1].Name ) folder does not exist at target site. Using 'Discovered virtual machine' folder`n" |
                                Write-Warning
                                $DestinationFolder = Get-Folder 'Discovered virtual machine' -Location $tgtDatastore.Datacenter
                            }                                        
                        }

                        "`n$( (Get-Date).ToString() ) Destination folder is $( $DestinationFolder.Name )`n" | Write-Host
                        
                        # Using previously stored datastore paths $replicaVms, register the replica VMs in the destination cluster and folder with suffix appended to names 

                        "`n$( (Get-Date).ToString() ) Registering replica VMs ...`n" | Write-Host
                        $registeredReplicas = @()
                        $replicaVms | % {
                            
                            # Register VM with name of source VM + provided suffix
                            
                            $sourceVmName = ($_ -split '/')[-1] -replace '\.vmx'
                            $replicaVm = New-VM -Name ($sourceVmName + $ReplicaVmsSuffix) -VMFilePath $_ -ResourcePool $DestinationCluster -Location $DestinationFolder -Confirm:1
                            if(!$replicaVm){ "$( (Get-Date).ToString() ) Unable to register $( $sourceVmName + $ReplicaVmsSuffix ). Check datastore path: $_`n" | Write-Warning } else {
                                $registeredReplicas += $replicaVm
                            }
                        }
                        "" | Write-Host
                    }
                }
            }
            
            # If -RemoveSourceVms or -RemoveSourceVmsPermanently is provided, check VMs are powered off then remove them

            if($RemoveSourceVms -or $RemoveSourceVmsPermanently){
                "$( (Get-Date).ToString() ) Shutting down source VMs ...`n" | Write-Verbose

                # Same procedure for shutdown as before
                
                if(((Get-VM $sourceVms).PowerState | select -Unique) -ne 'PoweredOff'){                
                    $sourceVms | ? PowerState -ne 'PoweredOff' | Stop-VMGuest -ErrorAction SilentlyContinue | Out-Null
                    
                    # Create stopwatch to wait 60 seconds for guest OS shutdowns down to finish                    

                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()                    

                    # While waiting for shutdown, check time on stopwatch

                    while((((Get-VM $sourceVms).PowerState | select -Unique) -ne 'PoweredOff') -and $stopwatch.IsRunning){
                        "$( (Get-Date).ToString() ) Waiting on guest OS shutdowns to finish ...`n" | Write-Verbose
                        
                        # If all VMs not in powered off state after 60 seconds then confirm force power off
                        
                        if($stopwatch.Elapsed.TotalSeconds -ge 60){
                            "`n$( (Get-Date).ToString() ) It has been at least 60 seconds and not all source VMs have shut down. Confirm if you want to power off VMs ...`n" | Write-Host
                            Get-VM $sourceVms | ? PowerState -ne 'PoweredOff' | Stop-VM | Out-Null
                            if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

                            # Stop stopwatch once VM force powered off or not
                            
                            $stopwatch.Stop()
                        }
                        sleep 5
                    }

                    if(((Get-VM $sourceVms).PowerState | select -Unique) -ne 'PoweredOff'){
                        Confirm-Continue -Warning "$( (Get-Date).ToString() ) Failed to shut down/power off $( (Get-VM $sourceVms | sort Name | ? PowerState -ne 'PoweredOff').Name -join ', ' )" `
                        -Prompt "`nSkip removal of them and continue? [y/n]`n" `
                        -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }
    
                        if($exit){ return }
                    }
                } else { "$( (Get-Date).ToString() ) Source VMs are already powered off`n" | Write-Verbose }
                
                # If VMs are powered off, proceed to removal. Else, leave as is
                
                $offVMs = Get-VM $sourceVms | ? PowerState -eq 'PoweredOff'
                if($offVMs){
                    if($RemoveSourceVmPermanently){
                        "`n$( (Get-Date).ToString() ) Deleting source VMs from disk:`n`n" + ($offVMs.name -join "`n") + "`n" | Write-Host
                        
                        # Delete VMs from disk. Prompt for confirmation
                        
                        $offVMs | Remove-VM -DeletePermanently
                        if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
                    } else {
                        "`n$( (Get-Date).ToString() ) Removing source VMs from inventory:`n`n" + ($offVMs.name -join "`n") + "`n" | Write-Host                    
                        
                        # Remove VMs from inventory. Prompt for confirmation

                        $offVMs | Remove-VM
                        if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
                    }

                    $triedRemoveVms = Get-VM $offVMs -ErrorAction SilentlyContinue
                    if($triedRemoveVms){
                        "$( (Get-Date).ToString() ) Failed to remove source VMs:`n`n" + ($triedRemoveVms.name -join "`n") + "`n" | Write-Warning
                    }
                }
            }
            
            "`n$( (Get-Date).ToString() ) Reversing replication ...`n" | Write-Host

            # Change state of target replication group from "FailedOver" to "Source"
            # Enable replication on automatically created reverse replication Protection Group            

            Start-SpbmReplicationReverse -ReplicationGroup $tgtReplGroup | Out-Null
            
            "$( (Get-Date).ToString() ) Creating new source Protection Group on $( $SpbmReplicationGroup.FaultDomain.Name ) (original used for failover can no longer be referenced by SPBM) ...`n" |
            Write-Verbose

            # Get original source Protection Group
            
            $sourcePgName = $SpbmReplicationGroup.Name -replace "$( $SpbmReplicationGroup.FaultDomain.Name ):"
            $sourcePg = Get-PfaProtectionGroup -Array $sourceFlashArray -Name $sourcePgName
                
            if($sourcePg){                
                $guid = ((New-Guid).Guid -split '-')[1]
                $newName = "$sourcePgName-$guid"

                # Check new name doesn't exceed character limit. Truncate if it does. (limit a variable in case it changes in future)
                
                $limit = 63

                if($newName.length -gt $limit){
                    $newName = "$( $sourcePgName.Substring(0,($sourcePgName.length - ($newName.length - $limit))) )-$guid"
                }

                # Rename original source Protection Group                
                
                "$( (Get-Date).ToString() ) Renaming original source Protection Group $sourcePgName to $newName before creating new source Protection Group ...`n" |
                Write-Verbose

                Rename-PfaProtectionGroup -Array $sourceFlashArray -Name $sourcePgName -NewName $newName | Out-Null

                if(!(Get-PfaProtectionGroup -Array $sourceFlashArray -Name $newName -ErrorAction SilentlyContinue)){
                    "$( (Get-Date).ToString() ) Failed to rename original source Protection Group`n" | Write-Warning 
                } else {

                    # Create new source Protection Group

                    "$( (Get-Date).ToString() ) Creating new $sourcePgName ...`n" | Write-Verbose

                    $newSourcePg = New-PfaProtectionGroup -Array $sourceFlashArray -Name $sourcePgName

                    if($newSourcePg){
                        
                        # Adding target(s) to new source Protection Group

                        Set-PfaTargetArrays -Array $sourceFlashArray -Name $sourcePgName -Targets $sourcePg.targets.name | Out-Null
                            
                        # Get retention settings for original Protection Group and apply to new one
                        
                        $retention = Get-PfaProtectionGroupRetention -Array $sourceFlashArray -ProtectionGroupName $newName |
                        select @{n='Array';e={$sourceFlashArray}},
                        @{n='GroupName';e={$sourcePgName}},
                        @{n='PostDefaultTargetSnapshotsPerDay';e={$_.target_per_day}},
                        @{n='PostDefaultSourceSnapshotRetentionInDays';e={$_.days}},
                        @{n='PostDefaultSourceSnapshotsPerDay';e={$_.per_day}},
                        @{n='DefaultRetentionForAllTargetSnapshots';e={$_.target_all_for}},
                        @{n='PostDefaultTargetSnapshotRetentionInDays';e={$_.target_days}},
                        @{n='DefaultRetentionForAllSourceSnapshots';e={$_.all_for}}

                        $splatParams = @{}

                        $retention.PSObject.Properties | select Name, Value | % {
                            $splatParams += @{ $_.Name = $_.Value }
                        }

                        Set-PfaProtectionGroupRetention @splatParams | Out-Null

                        # Get schedule settings for original Protection Group and apply to new one

                        $schedule = Get-PfaProtectionGroupSchedule -Array $sourceFlashArray -ProtectionGroupName $newName |
                        select @{n='Array';e={$sourceFlashArray}},
                        @{n='GroupName';e={$sourcePgName}},
                        @{n='SnapshotFrequencyInSeconds';e={$_.snap_frequency}},
                        @{n='ReplicationFrequencyInSeconds';e={$_.replicate_frequency}},
                        @{n='replicate_enabled';e={$_.replicate_enabled}},
                        @{n='snap_enabled';e={$_.snap_enabled}},
                        @{n='PreferredTimeOfDayToGenerateSnapshot';e={$_.snap_at}},
                        @{n='ReplicateAtSecondsOfDay';e={$_.replicate_at}},
                        @{n='Blackouts';e={$_.replicate_blackout}}

                        $splatParams = @{}

                        ($schedule | Select * -ExcludeProperty replicate_enabled, snap_enabled).PSObject.Properties | select Name, Value | % {
                            if($_.Value){
                                $splatParams += @{ $_.Name = $_.Value }
                            }
                        }

                        Set-PfaProtectionGroupSchedule @splatParams | Out-Null

                        # Enable replication if enabled on original
                        
                        if($schedule.replicate_enabled){ Enable-PfaReplicationSchedule -Array $sourceFlashArray -Name $sourcePgName | Out-Null }

                        # Enable snapshots if enabled on original

                        if($schedule.snap_enabled){ Enable-PfaSnapshotSchedule -Array $sourceFlashArray -Name $sourcePgName | Out-Null }

                        # Create custom object for original Protection Group to compare to new one

                        $srcRetention = Get-PfaProtectionGroupRetention -Array $sourceFlashArray -ProtectionGroupName $newName
                        $srcSchedule = Get-PfaProtectionGroupSchedule -Array $sourceFlashArray -ProtectionGroupName $newName
                        $srcGroupFull = Get-PfaProtectionGroup -Array $sourceFlashArray -Name $newName |
                        select Name,
                        Targets,
                        @{n='target_per_day';e={$srcRetention.target_per_day}},
                        @{n='days';e={$srcRetention.days}},
                        @{n='per_day';e={$srcRetention.per_day}},
                        @{n='target_all_for';e={$srcRetention.target_all_for}},
                        @{n='target_days';e={$srcRetention.target_days}},
                        @{n='all_for';e={$srcRetention.all_for}},
                        @{n='snap_frequency';e={$srcSchedule.snap_frequency}},
                        @{n='replicate_frequency';e={$srcSchedule.replicate_frequency}},
                        @{n='replicate_enabled';e={$srcSchedule.replicate_enabled}},
                        @{n='snap_enabled';e={$srcSchedule.snap_enabled}},
                        @{n='snap_at';e={$srcSchedule.snap_at}},
                        @{n='replicate_at';e={$srcSchedule.replicate_at}},
                        @{n='replicate_blackout';e={$srcSchedule.replicate_blackout}}
                        
                        # Create custom objects for new Protection Group

                        $newRetention = Get-PfaProtectionGroupRetention -Array $sourceFlashArray -ProtectionGroupName $sourcePgName
                        $newSchedule = Get-PfaProtectionGroupSchedule -Array $sourceFlashArray -ProtectionGroupName $sourcePgName
                        $newGroupFull = Get-PfaProtectionGroup -Array $sourceFlashArray -Name $sourcePgName |
                        select Name,
                        Targets,
                        @{n='target_per_day';e={$newRetention.target_per_day}},
                        @{n='days';e={$newRetention.days}},
                        @{n='per_day';e={$newRetention.per_day}},
                        @{n='target_all_for';e={$newRetention.target_all_for}},
                        @{n='target_days';e={$newRetention.target_days}},
                        @{n='all_for';e={$newRetention.all_for}},
                        @{n='snap_frequency';e={$newSchedule.snap_frequency}},
                        @{n='replicate_frequency';e={$newSchedule.replicate_frequency}},
                        @{n='replicate_enabled';e={$newSchedule.replicate_enabled}},
                        @{n='snap_enabled';e={$newSchedule.snap_enabled}},
                        @{n='snap_at';e={$newSchedule.snap_at}},
                        @{n='replicate_at';e={$newSchedule.replicate_at}},
                        @{n='replicate_blackout';e={$newSchedule.replicate_blackout}}

                        # Check new source Protection Group is a copy of the original

                        if(!(Compare ($newGroupFull | select * -Exc Name).PSObject.Properties ($srcGroupFull | select * -Exc Name).PSObject.Properties)){
                            
                            # If copy created successfully, re-apply policy to VMs and disks in original Protection Group

                            $sourceSp = Get-SpbmStoragePolicy |
                            ? {($_.AnyOfRuleSets.AllOfRules | ? {$_.Capability.Name -eq 'com.purestorage.storage.replication.ReplicationConsistencyGroup'}).Value -eq $sourcePgName}

                            # Get SPBM Replication Group (VASA reference to new source Protection Group)

                            $newSrcReplGroup = Get-SpbmReplicationGroup -Name $SpbmReplicationGroup.Name

                            if($sourceSp){
                                if($newSrcReplGroup){
                                    if($sourceDisks -or $sourceVms){
                                        "$( (Get-Date).ToString() ) Re-applying storage policy to $sourcePgName members to refresh compliance ...`n" | Write-Verbose    
                                        
                                        # If there are any, re-apply policy to VMDKs then VMs in original Protection Group. Fails if VMs are done first
                                        
                                        $disksToRefresh = @()

                                        if($sourceDisks){
                                            $sourceDisks | % {
                                                if($_.Parent.Id){
                                                    if(Get-VM -Id $_.Parent.Id -ErrorAction SilentlyContinue){
                                                        if(Get-HardDisk -VM $_.Parent -Id $_.Id -ErrorAction SilentlyContinue){
                                                           $disksToRefresh += Get-HardDisk -VM $_.Parent -Id $_.Id
                                                        }
                                                    }
                                                }
                                            }
                                        }
    
                                        $vmsToRefresh = @()
    
                                        if($sourceVms){
                                            $sourceVms | % {
                                                if($_.Id){
                                                    if(Get-VM -Id $_.Id -ErrorAction SilentlyContinue){
                                                        $vmsToRefresh += Get-VM -Id $_.Id
                                                    }
                                                }
                                            }
                                        }

                                        if($disksToRefresh){
                                            
                                            # Re-apply to disks in source Protection Group

                                            $disksToRefresh | Get-SpbmEntityConfiguration |
                                            Set-SpbmEntityConfiguration -StoragePolicy $sourceSp -ReplicationGroup $newSrcReplGroup | Out-Null
                                            
                                            # If disks compliant, re-apply to VMs if there are any

                                            if((($disksToRefresh | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant'){
                                                
                                                # Re-apply to VMs in source Protection Group
                                                
                                                if($vmsToRefresh){

                                                    $vmsToRefresh | Get-SpbmEntityConfiguration |
                                                    Set-SpbmEntityConfiguration -StoragePolicy $sourceSp -ReplicationGroup $newSrcReplGroup | Out-Null

                                                    # Check VMs under policy now compliant

                                                    if(!((($vmsToRefresh | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant')){
                                                        "$( (Get-Date).ToString() ) Failed to re-apply $( $sourceSp.Name ) to VMs in $sourcePgName`n" | Write-Warning
                                                    }
                                                }
                                            } else { "$( (Get-Date).ToString() ) Failed to re-apply $( $sourceSp.Name ) to disks in $sourcePgName`n" | Write-Warning }
                                        } elseif($vmsToRefresh){
                                            
                                            # Re-apply to VMs in source Protection Group

                                            $vmsToRefresh | Get-SpbmEntityConfiguration |
                                            Set-SpbmEntityConfiguration -StoragePolicy $sourceSp -ReplicationGroup $newSrcReplGroup | Out-Null

                                            # Check VMs under policy now compliant

                                            if(!((($vmsToRefresh | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant')){
                                                "$( (Get-Date).ToString() ) Failed to re-apply $( $sourceSp.Name ) to VMs in $sourcePgName`n" | Write-Warning
                                            }
                                        } else { "$( (Get-Date).ToString() ) No VMs or disks in old source Protection Group to re-apply $( $sourceSp.Name ) policy to`n" | Write-Verbose }                                                                                                                  
                                    } else { "$( (Get-Date).ToString() ) Failed to get VMs or disks in old source Protection Group to re-apply $( $sourceSp.Name ) policy to`n" | Write-Warning }
                                } else {
                                    $warning = "$( (Get-Date).ToString() ) Failed to find Replication Group for new source Protection Group. Manually check for Replication Group for"
                                    $warning += " $sourcePgName and re-apply to VMs and disks under policy $( $sourceSp.Name )`n"
                                    $warning | Write-Warning
                                }
                            } else {
                                $warning = "$( (Get-Date).ToString() ) Failed to find policy for source Protection Group. Manually check for policy that references $sourcePgName"
                                $warning += " and re-apply to VMs and disks`n"
                                $warning | Write-Warning
                            }

                            if(!((Get-PfaProtectionGroup -Array $sourceFlashArray -Name $newName).volumes)){                                                                                        
                                            
                                "$( (Get-Date).ToString() ) Removing renamed original source Protection Group $newName ...`n" | Write-Verbose

                                # Remove renamed original source Protection Group

                                Remove-PfaProtectionGroupOrSnapshot -Array $sourceFlashArray -Name $newName | Out-Null

                                # Check original source Protection group removed

                                if($newName -in (Get-PfaProtectionGroups -Array $sourceFlashArray | select -ExpandProperty Name)){
                                    "$( (Get-Date).ToString() ) Unable to remove renamed original source Protection Group $newName`n" | Write-Warning
                                }
                            } else {
                                "$( (Get-Date).ToString() ) Renamed original source Protection Group $newName still has volumes. Review and clean up manually`n" |
                                Write-Warning
                            }
                            
                            # Synchronise new source Protection Group if not empty

                            if((Get-PfaProtectionGroup -Array $sourceFlashArray -Name $sourcePgName).volumes){                                
                                "$( (Get-Date).ToString() ) Creating new snapshot for newly created source Protection Group $sourcePgName to be replicated to $( $tgtReplGroup.FaultDomain.Name ) ...`n" |
                                Write-Verbose

                                # Take snapshot for source Protection Group and replicate. Apply retention policy if number of snapshots exceeds retention setting

                                New-PfaProtectionGroupSnapshot -Array $sourceFlashArray -ProtectionGroups $sourcePgName -ReplicateNow -ApplyRetention | Out-Null
                            }
                        } else {
                            $warning = "$( (Get-Date).ToString() ) New source Protection Group $sourcePgName is not an exact copy of old, renamed one - $newName."
                            $warning += " Manually check its settings then re-apply storage policy that references $sourcePgName to VMs and disks`n"
                            $warning | Write-Warning
                        }
                    } else {
                        "$( (Get-Date).ToString() ) Failed to create new source Protection Group. Manually recreate $newName or it cannot be referenced by SPBM`n" |
                        Write-Warning
                    }
                }
            } else {
                "$( (Get-Date).ToString() ) Unable to retrieve original source Protection Group $sourcePgName. Manually recreate $newName or it cannot be referenced by SPBM`n" |
                Write-Warning
            }

            # Get vVol for one of the replica VMs home (vmx file, logs etc.) - known as config vVol

            # If VMs registered, use first VM's storage object property to find config vVol

            if($registeredReplicas){
                $configVvol = Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray `
                -VvolUuid $registeredReplicas[0].ExtensionData.Config.VmStorageObjectId
            } else {
                
                # If VMs not registered, use vmx path (in $replicaVms) to find config vVol                

                $configVvol = Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray `
                -VvolUuid (($replicaVms[0] -split ' ')[1] -split '/')[0]
            }

            if($configVvol){
                
                # Use config vVol to get automatically created reverse replication Protection Group
                
                $pGroup = Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $configVvol
                
                if($pGroup){
                    
                    # Get replica vVols

                    $replicaVvols = (Get-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group).volumes

                    # If Protection Group with same name as source Protection Group and same settings as auto-created reverse replication Protection Group exists,
                    # move members of auto-created reverse replication Protection Group to it. Else rename auto-created reverse replication Protection Group to
                    # same as source Protection Group
                                            
                    if(Get-PfaProtectionGroup -Array $targetFlashArray -Name $sourcePgName -ErrorAction SilentlyContinue | ? time_remaining -eq $null){
    
                        # Create custom object for automatically created Protection Group to compare to Protection Group with same name as source
    
                        $autoTargetGroupRetention = Get-PfaProtectionGroupRetention -Array $targetFlashArray -ProtectionGroupName $pGroup.protection_group
                        $autoTargetGroupSchedule = Get-PfaProtectionGroupSchedule -Array $targetFlashArray -ProtectionGroupName $pGroup.protection_group
                        $autoTargetGroupFull = Get-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group |
                        select Name,
                        Targets,
                        @{n='target_per_day';e={$autoTargetGroupRetention.target_per_day}},
                        @{n='days';e={$autoTargetGroupRetention.days}},
                        @{n='per_day';e={$autoTargetGroupRetention.per_day}},
                        @{n='target_all_for';e={$autoTargetGroupRetention.target_all_for}},
                        @{n='target_days';e={$autoTargetGroupRetention.target_days}},
                        @{n='all_for';e={$autoTargetGroupRetention.all_for}},
                        @{n='snap_frequency';e={$autoTargetGroupSchedule.snap_frequency}},
                        @{n='replicate_frequency';e={$autoTargetGroupSchedule.replicate_frequency}},
                        @{n='replicate_enabled';e={$autoTargetGroupSchedule.replicate_enabled}},
                        @{n='snap_enabled';e={$autoTargetGroupSchedule.snap_enabled}},
                        @{n='snap_at';e={$autoTargetGroupSchedule.snap_at}},
                        @{n='replicate_at';e={$autoTargetGroupSchedule.replicate_at}},
                        @{n='replicate_blackout';e={$autoTargetGroupSchedule.replicate_blackout}}
    
                        # Create custom object for Protection Group with same name as source
    
                        $targetGroupRetention = Get-PfaProtectionGroupRetention -Array $targetFlashArray -ProtectionGroupName $sourcePgName
                        $targetGroupSchedule = Get-PfaProtectionGroupSchedule -Array $targetFlashArray -ProtectionGroupName $sourcePgName
                        $targetGroupFull = Get-PfaProtectionGroup -Array $targetFlashArray -Name $sourcePgName |
                        select Name,
                        Targets,
                        @{n='target_per_day';e={$targetGroupRetention.target_per_day}},
                        @{n='days';e={$targetGroupRetention.days}},
                        @{n='per_day';e={$targetGroupRetention.per_day}},
                        @{n='target_all_for';e={$targetGroupRetention.target_all_for}},
                        @{n='target_days';e={$targetGroupRetention.target_days}},
                        @{n='all_for';e={$targetGroupRetention.all_for}},
                        @{n='snap_frequency';e={$targetGroupSchedule.snap_frequency}},
                        @{n='replicate_frequency';e={$targetGroupSchedule.replicate_frequency}},
                        @{n='replicate_enabled';e={$targetGroupSchedule.replicate_enabled}},
                        @{n='snap_enabled';e={$targetGroupSchedule.snap_enabled}},
                        @{n='snap_at';e={$targetGroupSchedule.snap_at}},
                        @{n='replicate_at';e={$targetGroupSchedule.replicate_at}},
                        @{n='replicate_blackout';e={$targetGroupSchedule.replicate_blackout}}
    
                        # Check Protection Groups are identical (excluding name)
    
                        if(!(Compare ($autoTargetGroupFull | select * -Exc Name).PSObject.Properties ($targetGroupFull | select * -Exc Name).PSObject.Properties)){                            
                            $moveVols = $true

                            $pGroupName = $sourcePgName
                        } else {
                            
                            # Match found but settings are different
                            # Check if replica VMs should be moved to name matching group. If not, rename matching group 
                            
                            $i=1
    
                            $newDuplicateTargetGroupName = $sourcePgName + "-$i"

                            while($newDuplicateTargetGroupName -in (Get-PfaProtectionGroups -Array $targetFlashArray | select -ExpandProperty name)){
                                $i++
                                $newDuplicateTargetGroupName = $sourcePgName + "-$i"                                            
                            }

                            $limit = 63

                            if($newDuplicateTargetGroupName.length -gt $limit){
                                $newDuplicateTargetGroupName = "$( $sourcePgName.Substring(0,($sourcePgName.length - ($newDuplicateTargetGroupName.length - $limit))) )-$i"
                            }

                            $warning = "$( (Get-Date).ToString() ) A Protection Group on the target array with the same name but different settings as the source Protection Group already exists"
                            $prompt = "`nMove replica VMs to that group? If no, it will be renamed `"$newDuplicateTargetGroupName`" and the automatically created"
                            $prompt += " reverse replication Protection Group (where the replica VMs are currently) with the same settings as the source Protection"
                            $prompt += " Group will be renamed to `"$sourcePgName`" (same as source) [y/n]`n"
                            
                            Confirm-Continue -Warning $warning -Prompt $prompt `
                            -ScriptIfNo {                                
                                
                                # Get VMs currently in target array Protection Group with same name but different settings as source

                                $matchingGroupRepGroup = Get-SpbmReplicationGroup | ? name -eq "$( $tgtReplGroup.FaultDomain.Name ):$sourcePgName"

                                if($matchingGroupRepGroup){
                                    $matchingGroupDisks = $matchingGroupRepGroup | Get-HardDisk
                                    $matchingGroupVms = $matchingGroupRepGroup | Get-VM                                    
                                } else {
                                    $warning = "$( (Get-Date).ToString() ) Unable to retrieve SPBM replication group for target array Protection Group with same name but different settings as source."
                                    $warning += " Manually re-apply storage policy to its VMs and/or disks after it has been renamed`n"
                                    $warning | Write-Warning
                                }
                                
                                # Rename duplicate target Protection Group

                                Rename-PfaProtectionGroup -Array $targetFlashArray -Name $sourcePgName -NewName $newDuplicateTargetGroupName | Out-Null
                            
                                if(!(Get-PfaProtectionGroup -Array $targetFlashArray -Name $newDuplicateTargetGroupName -ErrorAction SilentlyContinue)){
                                    "$( (Get-Date).ToString() ) Failed to rename duplicate target Protection Group to $newDuplicateTargetGroupName`n" | Write-Warning
                                
                                # Rename auto-created Protection Group to same as source if existing target group with same name has been renamed
        
                                } else {                                    

                                    # Rename auto-created group to same as source

                                    $script:newAutoGroupName = $sourcePgName

                                    # Make VMs and/or disks in renamed, duplicate target group compliant for storage policy (non-compliant after rename)

                                    if($matchingGroupVms -or $matchingGroupDisks){
                                        $renamedGroupSp = Get-SpbmStoragePolicy |
                                        ? {($_.AnyOfRuleSets.AllOfRules | ? {$_.Capability.Name -eq 'com.purestorage.storage.replication.ReplicationConsistencyGroup'}).Value -eq $newDuplicateTargetGroupName}

                                        if(!$renamedGroupSp){
                                            "$( (Get-Date).ToString() ) Creating storage policy for renamed, duplicate target Protection Group $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName ...`n" |
                                            Write-Verbose
                        
                                            $spName = "[vVol]$newDuplicateTargetGroupName"

                                            # Create rule that adds VM, to which policy is applied, to Protection Group
                                            
                                            $rule1 = New-SpbmRule -Capability 'com.purestorage.storage.replication.ReplicationConsistencyGroup' -Value $newDuplicateTargetGroupName
                                            
                                            # Create rule requiring VM to be stored on Pure Storage FlashArray
                                            
                                            $rule2 = New-SpbmRule -Capability 'com.purestorage.storage.policy.PureFlashArray' -Value $true
                                            
                                            # Add rules to ruleset and create storage policy

                                            $ruleset = New-SpbmRuleSet -AllOfRules $rule1,$rule2
                                            $renamedGroupSp = New-SpbmStoragePolicy -Name $spName -AnyOfRuleSets $ruleset
                                        }

                                        $renamedRepGroup = Get-SpbmReplicationGroup | ? name -eq "$( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName"

                                        if($renamedGroupSp -and $renamedRepGroup){
                                            if($matchingGroupDisks){
                                            
                                                # Re-apply to disks in renamed, duplicate Protection Group                                            
                                                
                                                "$( (Get-Date).ToString() ) Assigning storage policy to $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName disks...`n" | Write-Verbose
                                                $matchingGroupDisks | Get-SpbmEntityConfiguration |
                                                Set-SpbmEntityConfiguration -StoragePolicy $renamedGroupSp -ReplicationGroup $renamedRepGroup | Out-Null
                                                
                                                # If disks compliant, re-apply to VMs if there are any
    
                                                if((($matchingGroupDisks | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant'){
                                                    
                                                    # Re-apply to VMs in renamed, duplicate Protection Group
                                                    
                                                    if($matchingGroupVms){
                                                        "$( (Get-Date).ToString() ) Assigning storage policy to $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName VMs...`n" | Write-Verbose
                                                        $matchingGroupVms | Get-SpbmEntityConfiguration |
                                                        Set-SpbmEntityConfiguration -StoragePolicy $renamedGroupSp -ReplicationGroup $renamedRepGroup | Out-Null
    
                                                        # Check VMs under policy now compliant
    
                                                        if(!((($matchingGroupVms | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant')){
                                                            "$( (Get-Date).ToString() ) Failed to re-apply $( $renamedGroupSp.Name ) to VMs in $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName`n" | Write-Warning
                                                        }
                                                    }
                                                } else { "$( (Get-Date).ToString() ) Failed to re-apply $( $renamedGroupSp.Name ) to disks in $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName`n" | Write-Warning }
                                            } else {
                                                
                                                # Re-apply to VMs in renamed, duplicate Protection Group

                                                "$( (Get-Date).ToString() ) Assigning storage policy to $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName VMs...`n" | Write-Verbose
                                                $matchingGroupVms | Get-SpbmEntityConfiguration |
                                                Set-SpbmEntityConfiguration -StoragePolicy $renamedGroupSp -ReplicationGroup $renamedRepGroup | Out-Null
    
                                                # Check VMs under policy now compliant
    
                                                if(!((($matchingGroupVms | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant')){
                                                    "$( (Get-Date).ToString() ) Failed to re-apply $( $renamedGroupSp.Name ) to VMs in $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName`n" | Write-Warning
                                                }
                                            }                            
                                        } else {
                                            $warning = "$( (Get-Date).ToString() ) Unable to get storage policy and/or SPBM object for Protection Group $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName."
                                            $warning += " Skipping application of storage policy to its VMs and/or disks ...`n"
                                            $warning | Write-Warning
                                        }
                                    } else {
                                        $warning = "$( (Get-Date).ToString() ) Unable to get VMs and/or disks, or there are none, for $( $tgtReplGroup.FaultDomain.Name ):$newDuplicateTargetGroupName."
                                        $warning += " Skipping application of storage policy to them ..."
                                        $warning | Write-Warning
                                    }
                                }
                            } `
                            -ScriptIfYes { $script:moveVols = $true; $script:pGroupName = $sourcePgName }
                            <# If match found but settings are different, rename match
    
                            $i=1
    
                            $newDuplicateTargetGroupName = $sourcePgName + "-$i"
    
                            while($newDuplicateTargetGroupName -in (Get-PfaProtectionGroups -Array $targetFlashArray | select -ExpandProperty name)){
                                $i++
                                $newDuplicateTargetGroupName = $sourcePgName + "-$i"                                            
                            }
    
                            Rename-PfaProtectionGroup -Array $targetFlashArray -Name $sourcePgName -NewName $newDuplicateTargetGroupName | Out-Null
                            
                            if(!(Get-PfaProtectionGroup -Array $targetFlashArray -Name $newDuplicateTargetGroupName -ErrorAction SilentlyContinue)){
                                "Failed to rename duplicate target Protection Group to $newDuplicateTargetGroupName`n" | Write-Warning
                            
                            # Rename auto-created Protection Group to same as source if existing target group with same name has been renamed
    
                            } else { $newAutoGroupName = $sourcePgName }#>
                        }          
    
                    # Rename auto-created Protection Group to same as source if no existing target group with same name
    
                    } else { $newAutoGroupName = $sourcePgName }                    
                    
                    if(!$pGroupName){
                        if($newAutoGroupName){
                                                
                            # Rename auto-created reverse Protection Group to same name as source if no Protection Group on target already has that name or has been renamed successfully 
        
                            "$( (Get-Date).ToString() ) Renaming auto-created Protection Group $( $pGroup.protection_group ) to $newAutoGroupName ...`n" | Write-Verbose
                            Rename-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group -NewName $newAutoGroupName |Out-Null
                            
                            if(!(Get-PfaProtectionGroup -Array $targetFlashArray -Name $newAutoGroupName -ErrorAction SilentlyContinue)){
                                "$( (Get-Date).ToString() ) Failed to rename auto-created target Protection Group $( $pGroup.protection_group )`n" | Write-Warning
                                $pGroupName = $pGroup.protection_group
                            } else { $pGroupName = $newAutoGroupName }
                        
                        # Keep replica VM in auto-created Protection Group if target group with same name as source but different settings to auto-created group is unable to be renamed
                        
                        } else { $pGroupName = $pGroup.protection_group }
                    }
                            
                    # Create storage policy for replica VMs Protection Group if policy with same Protection Group requirement doesn't already exist            

                    $sp = Get-SpbmStoragePolicy |
                    ? {($_.AnyOfRuleSets.AllOfRules |? {$_.Capability.Name -eq 'com.purestorage.storage.replication.ReplicationConsistencyGroup'}).Value -eq $pGroupName}
                    
                    if(!$sp){
                        "$( (Get-Date).ToString() ) Creating storage policy for Protection Group $pGroupName on $( $tgtReplGroup.FaultDomain.Name ) ...`n" | Write-Verbose
                        
                        $spName = "[vVol]$pGroupName"

                        # Create rule that adds VMs to which policy is applied to target Protection Group
                        
                        $rule1 = New-SpbmRule -Capability 'com.purestorage.storage.replication.ReplicationConsistencyGroup' -Value $pGroupName
                        
                        # Create rule requiring VMs to be stored on Pure Storage FlashArray
                        
                        $rule2 = New-SpbmRule -Capability 'com.purestorage.storage.policy.PureFlashArray' -Value $true
                        
                        # Add rules to ruleset and create storage policy

                        $ruleset = New-SpbmRuleSet -AllOfRules $rule1,$rule2
                        $sp = New-SpbmStoragePolicy -Name $spName -AnyOfRuleSets $ruleset
                    }
                    
                    if($registeredReplicas){

                        # Get SPBM object for replica VMs Protection Group and policy
                    
                        $replGroup = Get-SpbmReplicationGroup | ? name -eq "$( $tgtReplGroup.FaultDomain.Name ):$pGroupName"

                        if($sp -and $replGroup){
                            
                            "$( (Get-Date).ToString() ) Assigning storage policy to replica VMs' home vVols ...`n" | Write-Verbose

                            # Apply policy and Protection Group to replica VM
                            
                            $registeredReplicas | Get-SpbmEntityConfiguration |
                            Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $replGroup | Out-Null                
                            
                            # Confirm storage policy has been applied
                            
                            $replicasSpNotApplied =
                            $registeredReplicas | select Name, @{n='StoragePolicy';e={($_ | Get-SpbmEntityConfiguration).StoragePolicy}} | ? StoragePolicy -ne $sp
                            
                            if($replicasSpNotApplied){ "$( (Get-Date).ToString() ) Failed to assign storage policy $( $sp.Name ) to:`n`n" + ($replicasSpNotApplied.Name -join "`n") | Write-Warning }

                            "$( (Get-Date).ToString() ) Assigning storage policy to replica VMs' disks ...`n" | Write-Verbose

                            # Apply policy and Protection Group to replica VMs' disks
                            
                            $registeredReplicas | Get-HardDisk | Get-SpbmEntityConfiguration |
                            Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $replGroup | Out-Null                                

                            # Confirm storage policy has been applied to disks

                            $disksSpNotApplied = $registeredReplicas | Get-HardDisk |
                            select @{n='Disk';e={$_.Parent.Name + " - " + $_.Name}}, @{n='StoragePolicy';e={($_ | Get-SpbmEntityConfiguration).StoragePolicy}} |
                            ? StoragePolicy -ne $sp

                            if($disksSpNotApplied){ "$( (Get-Date).ToString() ) Failed to assign storage policy $( $sp.Name ) to:`n`n" + ($disksSpNotApplied.Disk -join "`n") | Write-Warning }                            
                        } else { "$( (Get-Date).ToString() ) Unable to get storage policy and/or SPBM object for Protection Group $pGroupName. Skipping storage policy management`n" | Write-Warning }
                    
                    # Move replica VM vVols to existing Protection Group with same settings as auto-created one if it exists

                    } elseif($moveVols){

                        "$( (Get-Date).ToString() ) Moving replica vVols to $pGroupName. It has the same settings as the auto-created $( $pGroup.protection_group )`n" | Write-Verbose
                        
                        # Remove replica VM vVols from auto-created Protection Group

                        Remove-PfaVolumesFromProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group -VolumesToRemove $replicaVvols | Out-Null

                        # Check vVols have been removed

                        if(!($replicaVvols | % { Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $_ -ErrorAction SilentlyContinue })){

                            # Add vVols to existing Protection Group with same settings

                            Add-PfaVolumesToProtectionGroup -Array $targetFlashArray -Name $pGroupName -VolumesToAdd $replicaVvols | Out-Null

                            if(($replicaVvols | % { Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $_ -ErrorAction SilentlyContinue } |
                            select -ExpandProperty protection_group -Unique) -eq $pGroupName){
                                "$( (Get-Date).ToString() ) Replica vVols successfully moved to $pGroupName`n" | Write-Verbose
                            } else { "$( (Get-Date).ToString() ) Unable to confirm move of all replica vVols to $pGroupName`n" | Write-Warning }
                        } else { "$( (Get-Date).ToString() ) Unable to confirm removal of replica vVols from $( $pGroup.protection_group ). Skipping move to $pGroupName ...`n" | Write-Warning }
                    }

                    if($moveVols){
                        if(!(Get-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group).volumes){
                            $verbose = "$( (Get-Date).ToString() ) Replica vVols have been moved to newly created Protection Group with same settings as"
                            $verbose += " automatically created reverse replication Protection Group $( $pGroup.protection_group ). Removing it ...`n"
                            $verbose | Write-Verbose

                            # Remove memberless auto-created target Protection Group

                            Remove-PfaProtectionGroupOrSnapshot -Array $targetFlashArray -Name $pGroup.protection_group | Out-Null
                            Remove-PfaProtectionGroupOrSnapshot -Array $targetFlashArray -Name $pGroup.protection_group -Eradicate | Out-Null
                            
                            if($pGroup.protection_group -in (Get-PfaProtectionGroups -Array $targetFlashArray | select -ExpandProperty Name)){
                                "$( (Get-Date).ToString() ) Unable to remove empty Protection Group $( $pGroup.protection_group )`n" | Write-Warning
                            }
                        } else { "$( (Get-Date).ToString() ) Unable to remove auto-created Protection Group $( $pGroup.protection_group ) as it still contains vVols`n" | Write-Warning }
                    }

                    # Synchronise target Protection Group

                    "$( (Get-Date).ToString() ) Creating new snapshot for target Protection Group $pGroupName to be replicated to $( $SpbmReplicationGroup.FaultDomain.Name ) ...`n" |
                    Write-Verbose

                    # Take snapshot for target Protection Group and replicate. Apply retention policy if number of snapshots exceeds retention setting

                    New-PfaProtectionGroupSnapshot -Array $targetFlashArray -ProtectionGroups $pGroupName -ReplicateNow -ApplyRetention | Out-Null
                } else {
                    $warning = "$( (Get-Date).ToString() ) Unable to retrieve automatically created reverse replication Protection Group of replica VMs."
                    $warning += " Skipping Protection Group clean up and storage policy management ...`n"
                    $warning | Write-Warning
                }
            } else {
                "$( (Get-Date).ToString() ) Unable to retrieve config vVol of a replica VM. Skipping Protection Group clean up and storage policy management ...`n" |
                Write-Warning
            }
            
            # Return VM objects or vmx paths

            if($registeredReplicas){ Get-VM $registeredReplicas } else { $replicaVms }            
        } catch {            
            $Error[0] | Write-Error
            "`n$( (Get-Date).ToString() ) A terminating error occurred`n" | Write-Error
        } finally {
            
            # Remove script scoped variables to prevent interference with repeat use of function in same shell context
            
            $scriptVars = 'exit', 'DestinationFolder', 'useTempPgs', 'replSnapshots', 'replSnapshot', 'snap', 'newAutoGroupName', 'moveVols', 'pGroupName'
            
            Get-Variable -Name $scriptVars -Scope Script -ErrorAction SilentlyContinue | Remove-Variable -Scope Script -ErrorAction SilentlyContinue                
        }
    }
}