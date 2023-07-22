<#
.SYNOPSIS
    Create replicas of Pure Storage vVol VMs that are members of replication enabled Pure Storage Protection Groups.  
.DESCRIPTION
    This function takes vVol VMs that have been replicated from a Pure Storage FlashArray to another via Protection Group membership and enables them to be registered to ESXi clusters connected to the destination FlashArray's vVol datastore.
    
    It then enables replication of newly created replica vVol VMs back to the source FlashArray.
    
    A storage policy is created if it doesn't already exist and is then applied to the replica VMs if they are registered in the VM inventory.

    Optional parameters are included to shut down and/or remove source VMs and to synchronise Protection Groups before creation of replica vVol VMs.  
.PARAMETER SourceVms
    The VM objects of Pure Storage vVol VMs in replication enabled Protection Groups.
.PARAMETER SpbmReplicationGroups
    The object of a Storage Policy-Based Management Replication Group that represents a Pure Storage Protection Group. Returned by Get-SpbmReplicationGroup Cmdlet.
.PARAMETER ReplicaNames
    The names to use for the replica VMs to be created. VMs will be registered in inventory if included. Source VMs and replica names are paired by index. For use with -SourceVms.
.PARAMETER ReplicaSuffix
    Replica VMs will have the name of their corresponding source VM appended with the string provided for this parameter. VMs will be registered in inventory if included.
.PARAMETER RegisterReplicaVms
    Include if replica VMs are to be registered to a cluster and folder in the destination datacenter. If used without -DestinationCluster and/or -DestinationFolder they will be automatically chosen.
.PARAMETER StartReplicaVms
    Include if replica VMs are to be registered and powered on. If used without -DestinationCluster and/or -DestinationFolder they will be automatically chosen.
.PARAMETER DestinationCluster
    The destination cluster where replica VMs are to be registered. Must be connected to the target array's vVol datastore.
.PARAMETER DestinationFolder
    The destination folder where the replica VMs are to be registered. Must be available in the same datacenter as the target array's vVol datastore.
.PARAMETER FlashArrayCredential
    The credential object for the source and target Pure Storage FlashArrays. Username should not contain domain name prefix, e.g. Use "lewisc" not "zonalconnect\lewisc".
.PARAMETER SyncProtectionGroups
    Create and replicate an on-demand snapshot from source Protection Groups before creating replica VMs.
.PARAMETER MostRecentSnapshot
    Use the most recently replicated Protection Group snapshot to create the replica VMs.
.PARAMETER ShutdownSourceVmsFirst
    Shut down the source VMs before creating replicas.
.PARAMETER RemoveSourceVms
    Shut down the source VMs if they are powered on and remove from inventory after replica VMs have been created. Cannot be used with -RemoveSourceVmsPermanently (see NOTES section).
.EXAMPLE    
    #
    # Create replicas of lc-test2.1, lc-test7_repl, lc-test8_r, and dcautlprdvbs01r, renaming to 'lc-test2', 'lc-test7', 'lc-test8', 'dcautlprdvbs01'
    # Create new snapshot before creation of replica VMs
    # Shut down source VMs before creation of replica VMs
    # Delete source VMs once replica VMs have been created
    # Output verbose logging messages

    # Order of SourceVms and ReplicaNames is important because they are matched by index, hence why the example below uses Get-VM for each source VM (a manually created array would do the same thing)
    # If "Get-VM lc-test7_repl, lc-test2.1" was used instead, the output would have lc-test2.1 first despite it being last in the list of VM names
    New-PureVvolVmReplicas -SourceVms (Get-VM lc-test2.1), (Get-VM lc-test7_repl), (Get-VM lc-test8_r), (Get-VM dcautlprdvbs01r) `
        -ReplicaNames 'lc-test2', 'lc-test7', 'lc-test8', 'dcautlprdvbs01' `
        -FlashArrayCredential $faCred `
        -SyncProtectionGroups `
        -ShutdownSourceVmsFirst `
        -RemoveSourceVmsPermanently `
        -Verbose
.EXAMPLE    
    #
    # Create replicas of VMs in Protection Groups dca-flasharray2:TestSvc1-Repl8hrsRetain48hrs-NoSnap and dca-flasharray2:TestSvc-Repl8hrsRetain48hrs-NoSnap        
    # Output verbose logging messages

    Get-SpbmReplicationGroup -Name 'dca-flasharray2:TestSvc1-Repl8hrsRetain48hrs-NoSnap', 'dca-flasharray2:TestSvc-Repl8hrsRetain48hrs-NoSnap' |
    New-PureVvolVmReplicas -FlashArrayCredential $faCred -Verbose
.OUTPUTS
    $null or UniversalVirtualMachineImpl objects or String objects.
.NOTES
    Dynamic parameters:

    -RemoveSourceVmsPermanently <Switch>
    Shut down the source VMs if they are powered on and delete from disk after replica VMs have been created. Cannot be used with -RemoveSourceVms.
    
    Required?                    false
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

    -ReplicaSuffix <String>
    Use to rename replicas by appending a suffix if not using -ReplicaNames. 
    
    Required?                    false
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

    -DisconnectNetworkOnReplicaVms <Switch>
    Disconnect network adapters on replica VMs if they are to be registered in inventory.
    
    Required?                    false
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

    -RemoveNetworkOnReplicaVms <Switch>
    Remove network adapters from replica VMs if they are to be registered in inventory.
    
    Required?                    false
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false
    
    Module dependencies:

    Name                               TestedVersion
    ----                               -------
    PureStorage.FlashArray.VMware.VVol 1.4.0.2
    PureStoragePowerShellSDK           1.17.3.0
    VMware.Vim                         7.0.0.15939650
    VMware.VimAutomation.Core          12.0.0.15939655
    VMware.VimAutomation.Storage       12.0.0.15939648
#>
function New-PureVvolVmReplicas {
    [CmdletBinding(DefaultParameterSetName='By VMs',
                   PositionalBinding=$false)]
    [Alias()]    
    [OutputType([VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]])]
    [OutputType([String[]])]
    Param (        
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='By VMs')]
        [Alias("VMs")]                
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]
        $SourceVms,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='By groups')]
        [Alias("ProtectionGroups")]
        [ValidateScript({$_ -is [VMware.VimAutomation.Storage.Impl.V1.StorageObjectImpl]})]
        [Object[]]
        $SpbmReplicationGroups,
        
        [Alias("Names")]
        [ValidateNotNullOrEmpty()]        
        [Parameter(ParameterSetName='By VMs')]
        [String[]]
        $ReplicaNames,

        <#[Alias("Suffix")]
        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='By groups')]
        [String]
        $ReplicaSuffix,#>        

        [Alias("Register")]
        [Switch]
        $RegisterReplicaVms,

        [Alias("PowerOn")]
        [Switch]
        $StartReplicaVms,

        [Alias("Cluster")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]})]
        $DestinationCluster,

        [Alias("Folder")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]})]
        $DestinationFolder,

        [Alias("FaCred")]
        [Parameter(Mandatory=$true)]
        [PSCredential]
        $FlashArrayCredential,

        [Alias("Sync")]
        [Switch]
        $SyncProtectionGroups,

        [Switch]
        $MostRecentSnapshot,

        [Alias("ShutdownSource")]
        [Switch]
        $ShutdownSourceVmsFirst,
        
        [Alias("RemoveSource")]        
        [Switch]
        $RemoveSourceVms
    )
    
    DynamicParam {                  
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary  

        # If no -RemoveSourceVms parameter provided then enable use of -RemoveSourceVmsPermanently parameter

        if(!$RemoveSourceVms){                                               
            $permRemoveAttribute = New-Object System.Management.Automation.ParameterAttribute
            $permRemoveAttribute.Mandatory = $false
            $permRemoveAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $permRemoveAlias = New-Object System.Management.Automation.AliasAttribute 'DeleteSource'
            $permRemoveAttributeCollection.Add($permRemoveAttribute)
            $permRemoveAttributeCollection.Add($permRemoveAlias)
            $permRemoveParam = New-Object System.Management.Automation.RuntimeDefinedParameter('RemoveSourceVmsPermanently', [switch], $permRemoveAttributeCollection)            
            $paramDictionary.Add('RemoveSourceVmsPermanently', $permRemoveParam)
        }

        # If no -ReplicaNames parameter provided then enable use of -ReplicaSuffix parameter

        if(!$ReplicaNames){
            $suffixAttribute = New-Object System.Management.Automation.ParameterAttribute
            $suffixAttribute.Mandatory = $false
            $suffixAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $suffixAlias = New-Object System.Management.Automation.AliasAttribute 'Suffix'
            $suffixNotNullOrEmpty = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute
            $suffixAttributeCollection.Add($suffixAttribute)
            $suffixAttributeCollection.Add($suffixAlias)
            $suffixAttributeCollection.Add($suffixNotNullOrEmpty)
            $suffixParam = New-Object System.Management.Automation.RuntimeDefinedParameter('ReplicaSuffix', [string], $suffixAttributeCollection)            
            $paramDictionary.Add('ReplicaSuffix', $suffixParam)
        }

        # If VMs to be registered enable use of -DisconnectNetworkOnReplicaVms and -RemoveNetworkOnReplicaVms parameters

        if($ReplicaNames -or $PSBoundParameters.ReplicaSuffix -or $RegisterReplicaVms -or $StartReplicaVms -or $DestinationCluster -or $DestinationFolder){
            $disconnectAttribute = New-Object System.Management.Automation.ParameterAttribute
            $disconnectAttribute.Mandatory = $false
            $disconnectAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $disconnectAlias = New-Object System.Management.Automation.AliasAttribute 'Disconnect'
            $disconnectAttributeCollection.Add($disconnectAttribute)
            $disconnectAttributeCollection.Add($disconnectAlias)
            $disconnectParam = New-Object System.Management.Automation.RuntimeDefinedParameter('DisconnectNetworkOnReplicaVms', [switch], $disconnectAttributeCollection)            
            $paramDictionary.Add('DisconnectNetworkOnReplicaVms', $disconnectParam)

            $removeNetAttribute = New-Object System.Management.Automation.ParameterAttribute
            $removeNetAttribute.Mandatory = $false
            $removeNetAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $removeNetAlias = New-Object System.Management.Automation.AliasAttribute 'RemoveNetwork'
            $removeNetAttributeCollection.Add($removeNetAttribute)
            $removeNetAttributeCollection.Add($removeNetAlias)
            $removeNetParam = New-Object System.Management.Automation.RuntimeDefinedParameter('RemoveNetworkOnReplicaVms', [switch], $removeNetAttributeCollection)            
            $paramDictionary.Add('RemoveNetworkOnReplicaVms', $removeNetParam)
        }

        return $paramDictionary
    }

    Begin {                    
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
                        } else {
                            throw "`n$( (Get-Date).ToString() ) Install module $_ before using this function`n" }
                    }
                }
            }

            # Validate parameters

            "$( (Get-Date).ToString() ) Validating parameters ...`n" | Write-Verbose                    

            # Check a vCenter is connected

            if(!$global:DefaultVIServer){
                Confirm-Continue -Warning "$( (Get-Date).ToString() ) No connected VI servers" `
                -Prompt "`nAttempt to connect to vcenter? [y/n]`n" `
                -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                -ScriptIfYes {
                    "`n$( (Get-Date).ToString() ) Connecting to vcenter ...`n" | Write-Host
                    Connect-VIServer vcenter | Out-Null
                }                
                
                if($exit){ return }
            }
            
            $Groups = @()
            $vmsToProcess = @()            

        } catch {            
            $beginExit = $true
            $Error[0] | Write-Error
            "`n$( (Get-Date).ToString() ) A terminating error occurred in the Begin block`n" | Write-Error            
        } finally {
            
            # Set $beginExit if $script:exit set to true above to return from Process or End block and exit function. Required as $script:exit is removed if set to true in Begin block (finally block runs on return)

            if($exit){ $beginExit = $true }

            # Remove script scoped variables to prevent interference with repeat use of function in same shell context
                        
            Get-Variable -Name 'exit' -Scope Script -ErrorAction SilentlyContinue | Remove-Variable -Scope Script -ErrorAction SilentlyContinue   
        }
    }

    Process {            
        try {

            if($beginExit){ return }

            # Take VMs or replication groups from pipeline to be processed 

            if(!$SpbmReplicationGroups){
                $Groups += Get-SpbmReplicationGroup -VM $SourceVms
                $vmsToProcess += $SourceVms
            } else {
                $vmsToProcess += $SpbmReplicationGroups | Get-VM
                $Groups += $SpbmReplicationGroups
            }
            
        } catch {            
            $beginExit = $true
            $Error[0] | Write-Error
            "`n$( (Get-Date).ToString() ) A terminating error occurred in the Process block`n" | Write-Error
        } finally {}
    }

    End {
        try {

            if($beginExit){ return }

            if(!$Groups){
                throw "`n$( (Get-Date).ToString() ) Unable to get replication groups from source VMs. Check they are members of replication groups`n"  
            }

            if(!$vmsToProcess){
                throw "`n$( (Get-Date).ToString() ) Unable to get VMs from replication groups. Check replication groups have members`n"  
            }

            # Get source and target Protection Groups for each VM
            
            $vmsAndReplGroups = @()
            $noSrcGroup = @()
            $noTgtGroup = @()
            $failedOverTgtGroup = @()

            "$( (Get-Date).ToString() ) Getting source and target replication groups for:`n`n" + ($vmsToProcess -join "`n") + "`n" | Write-Verbose

            $Groups | select -Unique | % {
                $srcReplGroup = $_
                $vms = $srcReplGroup | Get-VM | ? {$_ -in $vmsToProcess}
                $tgtReplGroup = (Get-SpbmReplicationPair -Source $srcReplGroup).target
                $vms | % {
                    if(!$srcReplGroup){
                        $noSrcGroup += $_
                    } elseif(!$tgtReplGroup){
                        $noTgtGroup +=
                        [PSCustomObject]@{
                            VM = $_
                            SrcReplGroup = $srcReplGroup
                        }
                    } elseif($tgtReplGroup.State -eq 'FailedOver'){
                        $failedOverTgtGroup +=
                        [PSCustomObject]@{
                            VM = $_
                            SrcReplGroup = $srcReplGroup
                            TgtReplGroup = $tgtReplGroup
                        }
                    } else {
                        $vmsAndReplGroups += 
                        [PSCustomObject]@{
                            VM = $_
                            SrcReplGroup = $srcReplGroup
                            TgtReplGroup = $tgtReplGroup
                        }
                    }
                }
            }
            
            if($vmsAndReplGroups){
                $warning = @()
                if($noSrcGroup){
                    $warning += "Unable to retrieve source replication group(s) for $( $noSrcGroup.Name -join ', ')`n"
                }elseif($noTgtGroup){                    
                    $warning +=
                    "Unable to retrieve target replication group(s) for $( $noTgtGroup.VM.Name -join ', ') from source group(s) $( ($noTgtGroup.SrcReplGroup.Name | select -Unique) -join ', ')`n"
                }elseif($failedOverTgtGroup){
                    $warning +=
                    "Target replication group(s) $( ($failedOverTgtGroup.TgtReplGroup.Name | select -Unique) -join ', ') for $( $failedOverTgtGroup.VM.Name -join ', ') from source group(s) $( ($failedOverTgtGroup.SrcReplGroup.Name | select -Unique) -join ', ') are already in the FailedOver state`n"
                }

                if($warning){
                    $warning =+ "Excluding VM(s) from failover ...`n"
                    $warning | Write-Warning
                    Confirm-Continue -Prompt "`nContinue creating replicas of:`n`n" + ($vmsAndReplGroups.VM.Name -join "`n") + "[y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }
                    
                    if($exit){ return }
                }

                # Check for source VMs not in replication groups

                if(Compare $vmsAndReplGroups.VM $vmsToProcess | ? SideIndicator -eq '=>'){
                    $notInGroup = (Compare $vmsAndReplGroups.VM $vmsToProcess | ? SideIndicator -eq '=>').InputObject.Name
                    $warning = "The following VMs are not members of replication groups:`n`n" + ($notInGroup -join "`n")
                    $prompt = "`nContinue creating replicas of:`n`n" + ($vmsAndReplGroups.VM.Name -join "`n") + "`n[y/n]`n"
                    Confirm-Continue -Warning $warning -Prompt $prompt `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }
                    
                    if($exit){ return }                    
                }
            } else { throw "`nUnable target replication groups for any VMs`n" }

            # Pair VMs with replica names if provided

            if($ReplicaNames -or $PSBoundParameters.ReplicaSuffix){
                
                # Check same number of replica names as source VMs and that names don't exceed character limit

                if($ReplicaNames -and ($vmsAndReplGroups.count -ne $ReplicaNames.count)){
                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) Different number of replica names than source VMs in replication groups" `
                    -Prompt "`nSkip renaming of replica VMs? [y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }
                    
                    if($exit){ return }
                } else {
                    $script:vmsAndReplicaNames = @{}
                                        
                    #for ($i = 0; $i -lt $vmsAndReplGroups.Count; $i++){
                    $vmsAndReplGroups | % {                                                
                        if($ReplicaNames){
                            $indexInSourceVms = $vmsToProcess.IndexOf($_.VM)
                            $replName = $ReplicaNames[$indexInSourceVms]
                        } else { $replName = $_.VM.Name + $PSBoundParameters.ReplicaSuffix }

                        if($replName.Length -gt 80){
                            Confirm-Continue -Warning "$( (Get-Date).ToString() ) $replName exceeds the character limit of 80" `
                            -Prompt "`nSkip renaming of $( $_.VM.Name ) ? If no, function will exit [y/n]`n" `
                            -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }

                            if($exit){ return }
                        } else {
                            $script:vmsAndReplicaNames += @{ $_.VM.Name = $replName }
                        }
                    }
                }
            }

            $vmsAndReplGroups | Group SrcReplGroup | % {
                
                if($exit) { return }

                $pGroupName = $null

                $srcGroup = $_
                "`n$( (Get-Date).ToString() ) Creating replica vVols on $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ) from originals in Protection Group $( $srcGroup.Name ) ...`n" | Write-Host

                # Perform checks if VMs are to be registered
                                
                if($ReplicaNames -or $PSBoundParameters.ReplicaSuffix -or $RegisterReplicaVms -or $StartReplicaVms -or $DestinationCluster -or $DestinationFolder){                    
                    $skipReg = $false
                    $regVms = $false
                    while(!$skipReg -and !$regVms){
                        
                        # Get vVol datastore of target array

                        $tgtDatastore = Get-Datastore | ? Type -eq 'VVOL' | ? {$_.ExtensionData.Info.VvolDS.StorageArray.Name -eq $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name}
                        
                        if(!$tgtDatastore){
                            Confirm-Continue -Warning  "$( (Get-Date).ToString() ) Unable to find vVol datastore for target array" `
                            -Prompt "`nSkip registration of replica VMs from Protection Group $( $srcGroup.Name ) to inventory? If no, function will exit [y/n]`n" `
                            -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                            -ScriptIfYes { $script:skipReg = $true; }

                            if($exit){ return }
                        }
                        
                        # If -DestinationCluster provided then check it is connected to target array vVol datastore. Else select first returned cluster attached to datastore

                        if($DestinationCluster){
                            if(($DestinationCluster | Get-Datastore | select -ExpandProperty Name) -notcontains $tgtDatastore.Name){
                                Confirm-Continue -Warning  "$( (Get-Date).ToString() ) Provided destination cluster $( $DestinationCluster.Name ) does not have access to target datastore $( $tgtDatastore.Name )" `
                                -Prompt "`nSkip registration of replica VMs from Protection Group $( $srcGroup.Name ) to inventory? If no, function will exit [y/n]`n" `
                                -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                -ScriptIfYes { $script:skipReg = $true; }

                                if($exit){ return }
                            }
                        } else {
                            $DestinationCluster = ($tgtDatastore.Datacenter | Get-Cluster |
                            ? {($_ | Get-Datastore | select -ExpandProperty Name) -contains $tgtDatastore.Name})[0]
                            
                            if(!$DestinationCluster){
                                Confirm-Continue -Warning  "$( (Get-Date).ToString() ) Target datastore $( $tgtDatastore.Name ) is not accessible by clusters in target datacenter" `
                                -Prompt "`nSkip registration of replica VMs from Protection Group $( $srcGroup.Name ) to inventory? If no, function will exit [y/n]`n" `
                                -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                -ScriptIfYes { $script:skipReg = $true; }

                                if($exit){ return }
                            }
                        }
                        
                        # If no -DestinationFolder folder or provided one doesn't exist, confirm use of 'Discovered virtual machine' folder in datacenter of target datastore

                        if($DestinationFolder){
                            if(($tgtDatastore.Datacenter | Get-Folder | select -ExpandProperty Id) -notcontains $DestinationFolder.Id){
                                Confirm-Continue -Warning  "$( (Get-Date).ToString() ) $( $DestinationFolder.Name ) folder doesn't exist at target site" `
                                -Prompt "`nUse 'Discovered virtual machine' folder? If no, function will exit [y/n]`n" `
                                -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                -ScriptIfYes { $script:DestinationFolder = Get-Folder 'Discovered virtual machine' -Location $tgtDatastore.Datacenter }

                                if($exit){ return }
                            }
                        } else {
                            
                            # If no destination folder use 'Discovered virtual machine' folder

                            "$( (Get-Date).ToString() ) No destination folder provided. Using 'Discovered virtual machine' folder`n" | Write-Verbose
                            $DestinationFolder = Get-Folder 'Discovered virtual machine' -Location $tgtDatastore.Datacenter                      
                        }
                        
                        # If replica VMs are to be renamed, check for VMs with same names as provided names in target folder
                        
                        if($vmsAndReplicaNames){
                            $srcGroup.Group.VM.Name | %{
                                if($vmsAndReplicaNames[$_]){
                                    if(Get-VM -Name $vmsAndReplicaNames[$_] -Location $DestinationFolder -ErrorAction SilentlyContinue){
                                        Confirm-Continue -Warning "$( (Get-Date).ToString() ) VM with name $( $vmsAndReplicaNames[$_] ) already exists in target folder $( $DestinationFolder.Name )" `
                                        -Prompt "`nSkip renaming of $_ ? If no, function will exit [y/n]`n" `
                                        -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                        -ScriptIfYes { $script:vmsAndReplicaNames = $script:vmsAndReplicaNames.Remove($_) }

                                        if($exit){ return }
                                    }
                                }
                            }

                        # If replicas not to be renamed, check source VM names not in use in target folder

                        } else {
                            $srcGroup.Group.VM.Name | %{
                                if((Get-VM $_ -Location $DestinationFolder -ErrorAction SilentlyContinue)){
                                    Confirm-Continue -Warning  "VM with name $_ already exists in target folder $( $DestinationFolder.Name )" `
                                    -Prompt "`nSkip registration of replica VMs from Protection Group $( $srcGroup.Name ) to inventory? If no, function will exit [y/n]`n" `
                                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                    -ScriptIfYes { $script:skipReg = $true; }

                                    if($exit){ return }                                    
                                }
                            }
                        }

                        $regVms = $true
                    }
                }

                # Test FlashArray credential on source
                            
                "$( (Get-Date).ToString() ) Connecting to $( $srcGroup.Group.SrcReplGroup[0].FaultDomain.Name ) ...`n" | Write-Verbose
                $sourceFlashArray = New-PfaArray -EndPoint $srcGroup.Group.SrcReplGroup[0].FaultDomain.Name -Credentials $FlashArrayCredential -IgnoreCertificateError
    
                if(!$sourceFlashArray){ throw "`n$( (Get-Date).ToString() ) Couldn't connect to $( $srcGroup.Group.SrcReplGroup[0].FaultDomain.Name )`n" }

                # Test FlashArray credential on target
                            
                "$( (Get-Date).ToString() ) Connecting to $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ) ...`n" | Write-Verbose
                $targetFlashArray = New-PfaArray -EndPoint $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name -Credentials $FlashArrayCredential -IgnoreCertificateError
    
                if(!$targetFlashArray){ throw "`n$( (Get-Date).ToString() ) Couldn't connect to $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name )`n" }
    
                # Check replica vVols don't already exist on target array

                $srcGroup.Group.SrcReplGroup[0] | Get-VM | % {
                    $vm = $_
                    $vm.ExtensionData.LayoutEx.File | ? {($_.type -eq 'config') -or ($_.type -eq 'diskDescriptor')} | % {
                        
                        # Try block required to ignore error because Get-PfaVolumeNameFromVvolUuid creates a terminating error if no vVols found,
                        # even when setting ErrorAction to SilentlyContinue
                        
                        try{
                            if(Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray -VvolUUID $_.BackingObjectId){
                                "`n$( (Get-Date).ToString() ) $( $vm.Name ) vVol $( $_.Name ) already exists on $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name )`n" |
                                Write-Error                        
                                $exit = $true
                            }
                        } catch {}
                    }
                }
                if($exit){ return }

                # Take a new storage snapshot and replicate to the target array before failover if -SyncProtectionGroup switch specified
                
                if($SyncProtectionGroups){
                    "`n$( (Get-Date).ToString() ) Synchronising Protection Group $( $srcGroup.Name ) ...`n" | Write-Host                                                
                    "$( (Get-Date).ToString() ) Creating new snapshot for Protection Group $( $srcGroup.Name ) to be replicated to $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ) ...`n" |
                    Write-Verbose

                    # Take snapshot for source Protection Group and replicate. Apply retention policy if number of snapshots exceeds retention setting

                    $newSnap = New-PfaProtectionGroupSnapshot -Array $sourceFlashArray -ProtectionGroups ($srcGroup.Name -split ':')[1] `
                    -ReplicateNow -ApplyRetention
                    
                    if($newSnap){
                                        
                        # Wait for the snapshot to be replicated
                        
                        $newSnapOnTgt = Get-PfaProtectionGroupSnapshots -Array $targetFlashArray -Name $srcGroup.Name |
                        ? Name -eq "$( $srcGroup.Group.SrcReplGroup[0].FaultDomain.Name ):$( $newSnap.name )"

                        do {
                            "`n$( (Get-Date).ToString() ) Waiting on new snapshot to be replicated to target array ...`n" | Write-Host
                            sleep 5
                        } until((Get-PfaProtectionGroupSnapshotReplicationStatus -Array $targetFlashArray -Name $newSnapOnTgt.name).progress -eq 1.0)
                    } else {
                        Confirm-Continue -Warning "$( (Get-Date).ToString() ) Unable to create new snapshot" `
                        -Prompt "`nContinue? [y/n]`n" -ScriptIfNo {"`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }

                        if($exit){ return }
                    }
                    
                    # Get storage snapshots replicated to the target array (including new snapshot)

                    $script:replSnapshots = $srcGroup.Group.TgtReplGroup[0] | Get-SpbmPointInTimeReplica
                } else {
                    
                    # Get storage snapshots replicated to the target array 

                    $script:replSnapshots = $srcGroup.Group.TgtReplGroup[0] | Get-SpbmPointInTimeReplica
                }

                # If snapshots exist on the array, proceed to snapshot selection

                if($replSnapshots){
                    $script:replSnapshot = $null

                    # If -MostRecentSnapshot switch not provided, proceed to snapshot selection

                    if(!$MostRecentSnapshot){
                        
                        # If only one snapshot exists, confirm selection of it

                        if ($replSnapshots.Count -eq 1){
                            $prompt =
                            "`nThere is only one snapshot. Do you want replicas to be created from $( get-date ($replSnapshots).CreationTime -Format 'dd/MM/yyyy - HH:mm:ss' ) snapshot? If no, function will exit[y/n]`n"
                            Confirm-Continue -Prompt $prompt `
                            -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                            -ScriptIfYes { $script:replSnapshot = $replSnapshots }

                            if($exit){ return }

                        } else {

                            # Set snapshot selection number

                            $n = 1

                            # Output snapshot selection menu to console host

                            "`n$( $srcGroup.Name ) snapshots:`n" | Write-Host
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

                            "Replicas will be created from $( get-date ($replSnapshots | sort CreationTime -Descending)[$replSnapshot-1].CreationTime -Format 'dd/MM/yyyy - HH:mm:ss' ) snapshot`n" |
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

                        Confirm-Continue -Prompt "`nDo you want replicas to be created from the most recent snapshot: $snapTime ? If no, function will exit [y/n]`n" `
                        -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                        -ScriptIfYes { $script:replSnapshot = $snap }

                        if($exit){ return }
                    }

                # Throw error and exit if no snapshots have been replicated to target array
                
                } else { throw "`n$( (Get-Date).ToString() ) Unable to retrieve snapshots on target array`n" }

                # Shut down source VMs if -ShutdownSourceVmsFirst specified

                if($ShutdownSourceVmsFirst){
                    "`n$( (Get-Date).ToString() ) Shutting down source VMs:`n`n" + ($srcGroup.Group.VM.Name -join "`n") + "`n" | Write-Host
                    
                    # Attempt guest OS shutdown process for all source VMs
                    
                    $srcGroup.Group.VM | ? PowerState -ne 'PoweredOff' | Stop-VMGuest | Out-Null
                    if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
                    
                    # Create stopwatch to wait 60 seconds for guest OS shutdowns down to finish                    
    
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
                    # While waiting for shutdown, check time on stopwatch
    
                    while((((Get-VM -Id $srcGroup.Group.VM.Id).PowerState | select -Unique) -ne 'PoweredOff') -and $stopwatch.IsRunning){
                        "`n$( (Get-Date).ToString() ) Waiting on guest OS shutdowns to finish ...`n" | Write-Host
                        
                        # If all VMs not in powered off state after 60 seconds then confirm force power off
                        
                        if($stopwatch.Elapsed.TotalSeconds -ge 60){
                            "`n$( (Get-Date).ToString() ) It has been at least 60 seconds and not all source VMs have shut down. Confirm if you want to power off VMs ...`n" | Write-Host
                            Get-VM -Id $srcGroup.Group.VM.Id | ? PowerState -ne 'PoweredOff' | Stop-VM | Out-Null
                            if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
    
                            # Stop stopwatch once VM force powered off or not
                            
                            $stopwatch.Stop()
                        }
                        sleep 5
                    }
    
                    if(((Get-VM -Id $srcGroup.Group.VM.Id).PowerState | select -Unique) -ne 'PoweredOff'){
                        Confirm-Continue -Warning "$( (Get-Date).ToString() ) Failed to shut down/power off $( (Get-VM -Id $srcGroup.Group.VM.Id | sort Name | ? PowerState -ne 'PoweredOff').Name -join ', ' )" `
                        -Prompt "`nContinue? [y/n]`n" `
                        -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }
    
                        if($exit){ return }
                    } 
                }

                # Store VMs and disks in source Protection Group to re-apply storage policy to once source Protection Group has been recreated

                $srcGroupDisks = $srcGroup.Group.SrcReplGroup[0] | Get-HardDisk
                $srcGroupVms = $srcGroup.Group.SrcReplGroup[0] | Get-VM

                "`n$( (Get-Date).ToString() ) Starting failover of Protection Group $( $srcGroup.Name ) with VMs:`n`n" + ($srcGroup.Group.VM -join "`n") + "`n" | Write-Host
                
                # Set state of target replication group to "FailedOver" and create vVols on target array. Store VM datastore paths in $replicaVms for later registration 
                # Automatically create Protection Group on target array for replicating failed over vVols back to source array
                
                $replicaVmPaths = Start-SpbmReplicationFailover -ReplicationGroup $srcGroup.Group.TgtReplGroup[0] -PointInTimeReplica $replSnapshot -Confirm:1
                if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

                # Get vmx file names of source and replica VMs

                $vmx = @()
                $srcGroup.Group.VM | % { $vmx += (($_.ExtensionData.LayoutEx.File | ? Type -eq 'config').Name -split '/')[-1] }

                # Use vmx to exclude other VMs in Protection Group that have also just been failed over but are not in source VM list

                $replicaVmPaths = $replicaVmPaths | ? { ($_ -split '/')[-1] -in $vmx }
                
                # Throw error and exit if no path for replica VMs or unable to retrieve target array vVol datastore 
                
                if(!$replicaVmPaths){
                    throw "`n$( (Get-Date).ToString() ) Unable to failover source VMs or find their replicated config vVols. Check status of VASA providers and target vVol datastore`n"
                } else {
                    
                    # If replica VMs are to be registered in inventory, continue to placement
                    
                    if($regVms){

                        # Using previously stored datastore paths $replicaVmPaths, register the replica VMs in the destination cluster and folder with names in $ReplicaNames or $ReplicaSuffix if provided
                        $replicaVms = @()

                        $replicaVmPaths | % {
                            $regParams = @{
                                ResourcePool = $DestinationCluster
                                Location = $DestinationFolder                            
                            }
                            $path = $_
                            $regParams += @{VMFilePath = $path}
                            $srcVm = $srcGroup.Group.VM | ? {(($_.ExtensionData.LayoutEx.File | ? Type -eq 'config').Name -split '/')[-1] -eq ($path -split '/')[-1]}
                            
                            if($vmsAndReplicaNames){
                                if($vmsAndReplicaNames[$srcVm.Name]){
                                    $regParams += @{ Name = $vmsAndReplicaNames[$srcVm.Name] }
                                    "`n$( (Get-Date).ToString() ) Registering $( $vmsAndReplicaNames[$srcVm.Name] ) to $( $DestinationFolder.Name ) folder in $( $DestinationCluster.Name ) ...`n" |
                                    Write-Host
                                } else {
                                    $regParams += @{ Name = $srcVm.Name }
                                    "`n$( (Get-Date).ToString() ) Registering $( $srcVm.Name ) to $( $DestinationFolder.Name ) in $( $DestinationCluster.Name ) ...`n" | Write-Host    
                                }
                            } else {
                                $regParams += @{ Name = $srcVm.Name }
                                "`n$( (Get-Date).ToString() ) Registering $( $srcVm.Name ) to $( $DestinationFolder.Name ) in $( $DestinationCluster.Name ) ...`n" | Write-Host
                            }
                            
                            $replicaVm = New-VM @regParams -Confirm:1
                            if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

                            # If registration successful, proceed to starting VM if necessary parameter provided
                            
                            if(!(Get-VM -Id $replicaVm.Id)){ "$( (Get-Date).ToString() ) Unable to register $( $regParams['Name'] ). Check datastore path: $path`n" | Write-Warning } else {
                                $replicaVms += $replicaVm
                            }
                        }
                        
                        if($PSBoundParameters.DisconnectNetworkOnReplicaVms){
                            "`n$( (Get-Date).ToString() ) Disconnecting network adapters on replica VMs:`n`n" + ($replicaVms.Name -join "`n") + "`n" | Write-Host
                            $replicaVms | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected $false -Confirm:0 | Out-Null                               
                        }

                        if($PSBoundParameters.RemoveNetworkOnReplicaVms){
                            "`n$( (Get-Date).ToString() ) Removing network adapters on replica VMs:`n`n" + ($replicaVms.Name -join "`n") + "`n" | Write-Host
                            $replicaVms | Get-NetworkAdapter | Remove-NetworkAdapter -Confirm:0 | Out-Null
                        }

                        if($StartReplicaVms -and $replicaVms){
                            "`n$( (Get-Date).ToString() ) Starting replica VMs:`n`n" + ($replicaVms.Name -join "`n") + "`n" | Write-Host
                            $replicaVms | Start-VM | Out-Null

                            # Answer 'I copied it' if asked if VM was moved or copied

                            if(Get-VMQuestion -VM $replicaVms){
                                "`n$( (Get-Date).ToString() ) Answering VM question(s) with 'I Copied It' ...`n" | Write-Host
                                Get-VMQuestion -VM $replicaVms | Set-VMQuestion -Option 'button.uuid.copiedTheVM' -Confirm:0 | Out-Null
                            }                                      
                        }
                    }
                }

                # If -RemoveSourceVms or -RemoveSourceVmsPermanently is provided, check VMs are powered off then remove them

                if($RemoveSourceVms -or $PSBoundParameters.RemoveSourceVmsPermanently){
                    "$( (Get-Date).ToString() ) Shutting down source VMs ...`n" | Write-Verbose

                    # Same procedure for shutdown as before
                    
                    if(((Get-VM -Id $srcGroup.Group.VM.Id).PowerState | select -Unique) -ne 'PoweredOff'){                
                        Get-VM -Id $srcGroup.Group.VM.Id | ? PowerState -ne 'PoweredOff' | Stop-VMGuest -ErrorAction SilentlyContinue | Out-Null
                        
                        # Create stopwatch to wait 60 seconds for guest OS shutdowns down to finish                    

                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()                    

                        # While waiting for shutdown, check time on stopwatch

                        while((((Get-VM -Id $srcGroup.Group.VM.Id).PowerState | select -Unique) -ne 'PoweredOff') -and $stopwatch.IsRunning){
                            "$( (Get-Date).ToString() ) Waiting on guest OS shutdowns to finish ...`n" | Write-Verbose
                            
                            # If all VMs not in powered off state after 60 seconds then confirm force power off
                            
                            if($stopwatch.Elapsed.TotalSeconds -ge 60){
                                "`n$( (Get-Date).ToString() ) It has been at least 60 seconds and not all source VMs have shut down. Confirm if you want to power off VMs ...`n" | Write-Host
                                Get-VM -Id $srcGroup.Group.VM.Id | ? PowerState -ne 'PoweredOff' | Stop-VM | Out-Null
                                if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

                                # Stop stopwatch once VM force powered off or not
                                
                                $stopwatch.Stop()
                            }
                            sleep 5
                        }

                        if(((Get-VM -Id $srcGroup.Group.VM.Id).PowerState | select -Unique) -ne 'PoweredOff'){
                            Confirm-Continue -Warning "$( (Get-Date).ToString() ) Failed to shut down/power off $( (Get-VM -Id $srcGroup.Group.VM.Id | sort Name | ? PowerState -ne 'PoweredOff').Name -join ', ' )" `
                            -Prompt "`nSkip removal of them and continue? [y/n]`n" `
                            -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }
        
                            if($exit){ return }
                        }
                    } else { "$( (Get-Date).ToString() ) Source VMs are already powered off`n" | Write-Verbose }
                    
                    # If VMs are powered off, proceed to removal. Else, leave as is
                    
                    $offVMs = Get-VM -Id $srcGroup.Group.VM.Id | ? PowerState -eq 'PoweredOff'
                    if($offVMs){
                        if($PSBoundParameters.RemoveSourceVmsPermanently){
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

                        $triedRemoveVms = Get-VM -Id $offVMs.Id -ErrorAction SilentlyContinue
                        if($triedRemoveVms){
                            "$( (Get-Date).ToString() ) Failed to remove source VMs:`n`n" + ($triedRemoveVms.name -join "`n") + "`n" | Write-Warning
                        }
                    }
                }   
                
                "`n$( (Get-Date).ToString() ) Reversing replication ...`n" | Write-Host

                # Change state of target replication group from "FailedOver" to "Source"
                # Enable replication on automatically created reverse replication Protection Group

                Start-SpbmReplicationReverse -ReplicationGroup $srcGroup.Group.TgtReplGroup[0] | Out-Null
                
                "$( (Get-Date).ToString() ) Creating new source Protection Group on $( $srcGroup.Group.SrcReplGroup[0].FaultDomain.Name ) (original used for failover can no longer be referenced by SPBM) ...`n" |
                Write-Verbose

                # Get original source Protection Group
                
                $sourcePgName = $srcGroup.Name -replace "$( $srcGroup.Group.SrcReplGroup[0].FaultDomain.Name ):"
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
                    
                    "$( (Get-Date).ToString() ) Renaming $sourcePgName to $newName before creating new Protection Group ...`n" |
                    Write-Verbose

                    Rename-PfaProtectionGroup -Array $sourceFlashArray -Name $sourcePgName -NewName $newName | Out-Null

                    if(!(Get-PfaProtectionGroup -Array $sourceFlashArray -Name $newName -ErrorAction SilentlyContinue)){
                        "$( (Get-Date).ToString() ) Failed to rename original source Protection Group`n" | Write-Warning 
                    } else {

                        # Create new source Protection Group

                        "$( (Get-Date).ToString() ) Creating new $sourcePgName on source array...`n" | Write-Verbose

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
                                ? {($_.AnyOfRuleSets.AllOfRules |
                                    ? {$_.Capability.Name -eq 'com.purestorage.storage.replication.ReplicationConsistencyGroup'}).Value -eq $sourcePgName}

                                # Get SPBM Replication Group (VASA reference to new source Protection Group)

                                $newSrcReplGroup = Get-SpbmReplicationGroup -Name "$( $srcGroup.Group.SrcReplGroup[0].FaultDomain.Name ):$sourcePgName"

                                if($sourceSp){
                                    if($newSrcReplGroup){
                                        if($srcGroupDisks -or $srcGroupVms){
                                            "$( (Get-Date).ToString() ) Re-applying storage policy to $sourcePgName members to refresh compliance ...`n" | Write-Verbose    
                                            
                                            # If there are any, re-apply policy to VMDKs then VMs in original Protection Group. Fails if VMs are done first
                                            
                                            $disksToRefresh = @()

                                            if($srcGroupDisks){
                                                $srcGroupDisks | % {
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
        
                                            if($srcGroupVms){
                                                $srcGroupVms | % {
                                                    if($_.Id){
                                                        if(Get-VM -Id $_.Id -ErrorAction SilentlyContinue){
                                                            $vmsToRefresh += Get-VM -Id $_.Id
                                                        }
                                                    }
                                                }
                                            }

                                            if($disksToRefresh){

                                                # Re-apply to disks in source Protection Group
                                                 
                                                $disksToRefresh | Group { $_.Parent.Name } | % {
                                                    #$confs = @()
                                                    #$confs += $_.Group.Parent[0] | Get-SpbmEntityConfiguration
                                                    #$_.Group | Get-SpbmEntityConfiguration | % { $confs += $_ }
                                                    Set-SpbmEntityConfiguration -Configuration ($_.Group | Get-SpbmEntityConfiguration) -StoragePolicy $sourceSp -ReplicationGroup $newSrcReplGroup |
                                                    Out-Null
                                                }
                                                                                                                                                
                                                $newDisksConf = $disksToRefresh | Get-SpbmEntityConfiguration
                                                
                                                if(($newDisksConf.ComplianceStatus | select -Unique) -ne 'compliant'){
                                                    "$( (Get-Date).ToString() ) Failed to re-apply $( $sourceSp.Name ) to disks in $sourcePgName`n" | Write-Warning
                                                } elseif(($newDisksConf.ReplicationGroup.Name | select -Unique) -ne $newSrcReplGroup.Name){
                                                    "$( (Get-Date).ToString() ) Failed to add disks to $sourcePgName. Retrying ...`n" | Write-Warning
                                                    $newDisksConf | ? {$_.ReplicationGroup.Name -ne $newSrcReplGroup.Name } | Group {$_.Entity.Parent.Name } | % {
                                                        #$confs = @()
                                                        #$confs += $_.Group.Entity.Parent[0] | Get-SpbmEntityConfiguration
                                                        #$_.Group | % { $confs+= $_ }
                                                        Set-SpbmEntityConfiguration -Configuration $_.Group -ReplicationGroup $newSrcReplGroup | Out-Null
                                                    }
                                                }
                                                
                                                if($vmsToRefresh){
                                                    $vmsToRefresh | Get-SpbmEntityConfiguration | % {
                                                        Set-SpbmEntityConfiguration -Configuration $_ -StoragePolicy $sourceSp -ReplicationGroup $newSrcReplGroup |
                                                        Out-Null
                                                    }

                                                    $newVmConf = $vmsToRefresh | Get-SpbmEntityConfiguration

                                                    if(($newVmConf.ComplianceStatus | select -Unique) -ne 'compliant'){
                                                        "$( (Get-Date).ToString() ) Failed to re-apply $( $sourceSp.Name ) to VMs in $sourcePgName`n" | Write-Warning
                                                    } elseif(($newVmConf.ReplicationGroup.Name | select -Unique) -ne $newSrcReplGroup.Name){
                                                        "$( (Get-Date).ToString() ) Failed to add VMs to $sourcePgName. Retrying ...`n" | Write-Warning
                                                        $newVmConf | ? {$_.ReplicationGroup.Name -ne $newSrcReplGroup.Name } | % {
                                                            Set-SpbmEntityConfiguration -Configuration $_ -ReplicationGroup $newSrcReplGroup | Out-Null
                                                        }
                                                    }
                                                }                                        

                                                <#
                                                # If disks compliant, re-apply to VMs if there are any

                                                if((($disksToRefresh | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant'){
                                                    
                                                    # Re-apply to VMs in source Protection Group
                                                    
                                                    if($vmsToRefresh){                                                        
                                                        $vmsToRefresh | Get-SpbmEntityConfiguration |
                                                        Set-SpbmEntityConfiguration -StoragePolicy $sourceSp -ReplicationGroup $newSrcReplGroup | Out-Null

                                                        # Check VMs under policy now compliant

                                                        if((($vmsToRefresh | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -ne 'compliant'){
                                                            "$( (Get-Date).ToString() ) Failed to re-apply $( $sourceSp.Name ) to VMs in $sourcePgName`n" | Write-Warning
                                                        }
                                                    }
                                                } else { "$( (Get-Date).ToString() ) Failed to re-apply $( $sourceSp.Name ) to disks in $sourcePgName`n" | Write-Warning }
                                                #>
                                            } elseif($vmsToRefresh){
                                                
                                                # Re-apply to VMs in source Protection Group
                                                                                            
                                                $vmsToRefresh | Get-SpbmEntityConfiguration |
                                                Set-SpbmEntityConfiguration -StoragePolicy $sourceSp -ReplicationGroup $newSrcReplGroup | Out-Null

                                                # Check VMs under policy now compliant

                                                if((($vmsToRefresh | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant'){
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
                                    "$( (Get-Date).ToString() ) Removing $newName ...`n" | Write-Verbose

                                    # Remove renamed original source Protection Group

                                    Remove-PfaProtectionGroupOrSnapshot -Array $sourceFlashArray -Name $newName | Out-Null

                                    # Check original source Protection group removed

                                    if($newName -in (Get-PfaProtectionGroups -Array $sourceFlashArray | select -ExpandProperty Name)){
                                        "$( (Get-Date).ToString() ) Unable to remove $newName`n" | Write-Warning
                                    }
                                } else {
                                    "$( (Get-Date).ToString() ) Moving remaining vVols from $newName to $sourcePgName`n" | Write-Verbose
                                
                                    $sourceVols = (Get-PfaProtectionGroup -Array $sourceFlashArray -Name $newName).volumes

                                    # Remove source vVols from old source Protection Group

                                    Remove-PfaVolumesFromProtectionGroup -Array $sourceFlashArray -Name $newName -VolumesToRemove $sourceVols | Out-Null

                                    # Check vVols have been removed

                                    if(!($sourceVols | % { Get-PfaVolumeProtectionGroups -Array $sourceFlashArray -VolumeName $_ -ErrorAction SilentlyContinue })){

                                        # Add vVols to new Protection Group with same settings

                                        Add-PfaVolumesToProtectionGroup -Array $sourceFlashArray -Name $sourcePgName -VolumesToAdd $sourceVols | Out-Null

                                        if(($sourceVols | % { Get-PfaVolumeProtectionGroups -Array $sourceFlashArray -VolumeName $_ -ErrorAction SilentlyContinue } |
                                        select -ExpandProperty protection_group -Unique) -eq $sourcePgName){
                                            "$( (Get-Date).ToString() ) Remaining source vVols successfully moved to new $sourcePgName`n" | Write-Verbose
                                            "$( (Get-Date).ToString() ) Removing $newName ...`n" | Write-Verbose

                                            # Remove renamed original source Protection Group

                                            Remove-PfaProtectionGroupOrSnapshot -Array $sourceFlashArray -Name $newName | Out-Null

                                            # Check original source Protection group removed

                                            if($newName -in (Get-PfaProtectionGroups -Array $sourceFlashArray | select -ExpandProperty Name)){
                                                "$( (Get-Date).ToString() ) Unable to remove $newName`n" | Write-Warning
                                            }
                                        } else { "$( (Get-Date).ToString() ) Unable to confirm move of remaining source vVols to $sourcePgName. Not removing $newName ...`n" | Write-Warning }
                                    } else {
                                        "$( (Get-Date).ToString() ) Unable to confirm removal of remaining source vVols from $newName. Skipping move to $sourcePgName. Not removing $newName ...`n" |
                                        Write-Warning
                                    }
                                }
                                
                                # Synchronise new source Protection Group if not empty

                                if((Get-PfaProtectionGroup -Array $sourceFlashArray -Name $sourcePgName).volumes){                                
                                    "$( (Get-Date).ToString() ) Creating new snapshot for new $sourcePgName to be replicated to $( $tgtReplGroup.FaultDomain.Name ) ...`n" |
                                    Write-Verbose

                                    # Take snapshot for source Protection Group and replicate. Apply retention policy if number of snapshots exceeds retention setting

                                    New-PfaProtectionGroupSnapshot -Array $sourceFlashArray -ProtectionGroups $sourcePgName -ReplicateNow -ApplyRetention | Out-Null
                                }
                            } else {
                                $warning = "$( (Get-Date).ToString() ) New $sourcePgName is not an exact copy of $newName."
                                $warning += " Manually check its settings then re-apply storage policy that references $sourcePgName to VMs and disks`n"
                                $warning | Write-Warning
                            }
                        } else {
                            "$( (Get-Date).ToString() ) Failed to create new source Protection Group. Manually recreate $newName or it cannot be referenced by SPBM`n" |
                            Write-Warning
                        }
                    }
                } else {
                    "$( (Get-Date).ToString() ) Unable to retrieve original source Protection Group $sourcePgName. Manually recreate it or it cannot be referenced by SPBM`n" |
                    Write-Warning
                }

                "$( (Get-Date).ToString() ) Removing unregistered vVols on target array that were also in $( $srcGroup.Name )" | Write-Verbose
                        
                # Get vVol for replica VM home (vmx file, logs etc.) - known as config vVol

                # If VM registered, use VM object property to find config vVol

                if(Get-VM -Id $replicaVms[0].Id -ErrorAction SilentlyContinue){
                    $configVvol = Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray `
                    -VvolUuid $replicaVms[0].ExtensionData.Config.VmStorageObjectId
                } else {
                    
                    # If VM not registered, use vmx path (in $replicaVmPaths) to find config vVol                

                    $configVvol = Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray `
                    -VvolUuid (($replicaVmPaths[0] -split ' ')[1] -split '/')[0]
                }                

                if($configVvol){
                    
                    # Use config vVol to get automatically created reverse replication Protection Group
                    
                    $pGroup = Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $configVvol
                    
                    if($pGroup){                    

                        # Get vVols in the Protection Group not belonging to replica VM. Such vVols are ones belonging to VMs that were in the same Protection Group
                        # as the source VM at the time of failover. Failover operation is Protection Group scoped meaning unwanted vVols may be created on the target
                        # array that have to be removed  
                        
                        $excludeVols = @()
                        $replicaVmPaths | % {
                            
                            # Use vmx path (in $replicaVmPaths) to find config vVol then volume group for each replica VM
        
                            $configVvol = Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray -VvolUuid (($_ -split ' ')[1] -split '/')[0]                                                
                            $excludeVols += (Get-PfaVolumeGroup -Array $targetFlashArray -Name ($configVvol -split '/')[0]).volumes
                        }

                        $unregisteredVols = (Get-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group).volumes | ? {$_ -notin $excludeVols}

                        if($unregisteredVols){
                            
                            # Remove host connections from unwanted vVols
                            
                            if($volHostCons = $unregisteredVols | % { Get-PfaVolumeHostConnections -Array $targetFlashArray -VolumeName $_ }){
                                $volHostCons |
                                % { Remove-PfaHostVolumeConnection -Array $targetFlashArray -HostName $_.host -VolumeName $_.name | Out-Null }
                            }
                            
                            # Remove unwanted vVols from Protection Group

                            Remove-PfaVolumesFromProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group -VolumesToRemove $unregisteredVols | Out-Null
                            
                            # Check host connections successfully removed
                            
                            if(!($unregisteredVols | % { Get-PfaVolumeHostConnections -Array $targetFlashArray -VolumeName $_ })){                            
                                
                                # Check unwanted vVols successfully removed from Protection Group
                                
                                if(!($unregisteredVols | % { Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $_ -ErrorAction SilentlyContinue })){
                                    
                                    # Remove unwanted vVols

                                    $unregisteredVols | % {
                                        Remove-PfaVolumeOrSnapshot -Array $targetFlashArray -Name $_ | Out-Null
                                        Remove-PfaVolumeOrSnapshot -Array $targetFlashArray -Name $_ -Eradicate | Out-Null                                
                                    }
                                    
                                    # Check unwanted vVols have been successfully removed. (Get-PfaVolume not used as it outputs recycle bin vVols (non-eradicated))
                                    
                                    if(!(Compare (Get-PfaVolumes -Array $targetFlashArray).name $unregisteredVols -IncludeEqual | ? SideIndicator -eq '==')){
                                        
                                        # Remove unwanted vVols volume groups
                                        
                                        $unregisteredVols | % { ($_ -split '/')[0] } | select -Unique | % {
                                            Remove-PfaVolumeGroup -Name $_ -Array $targetFlashArray | Out-Null
                                            Remove-PfaVolumeGroup -Name $_ -Array $targetFlashArray -Eradicate | Out-Null
                                        }
                                        
                                        # Check volume groups successfully removed
                                        
                                        if($unregisteredVols | % { ($_ -split '/')[0] } | select -Unique | % {
                                            Get-PfaVolumeGroup -Array $targetFlashArray -Name $_ -ErrorAction SilentlyContinue
                                        }){
                                            "$( (Get-Date).ToString() ) Unable to remove unregistered vVol groups:`n`n" | Write-Warning
                                            $unregisteredVols | % { ($_ -split '/')[0] } | select -Unique | Write-Host -ForegroundColor Yellow
                                            "" | Write-Host
                                        }
                                    } else {
                                        "$( (Get-Date).ToString() ) Unable to remove unregistered vVols. Check volume groups:`n`n" | Write-Warning
                                        $unregisteredVols | % { ($_ -split '/')[0] } | select -Unique | Write-Host -ForegroundColor Yellow
                                        "" | Write-Host  
                                    }                                                               
                                } else {
                                    "$( (Get-Date).ToString() ) Unable to remove unregistered vVols from Protection Group. Skipping removal of unregistered vVols:`n`n" | Write-Warning
                                    $unregisteredVols | Write-Host -ForegroundColor Yellow
                                    "" | Write-Host
                                }
                            } else {
                                "$( (Get-Date).ToString() ) Unable to disconnect hosts completely from unregistered vVols. Skipping removal of unregistered vVols:`n`n" | Write-Warning
                                $unregisteredVols | Write-Host -ForegroundColor Yellow
                                "" | Write-Host
                            }
                        }

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
                                
                                # If match found, remove auto-created Protection Group once members have been moved
                                
                                $moveVols = $true

                                $pGroupName = $sourcePgName
                            } else {
                                
                                # Match found but settings are different
                                # Check if replica VM should be moved to name matching group. If not, rename matching group 
                                
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
                                $prompt = "`nMove replica VM to that group? If no, it will be renamed `"$newDuplicateTargetGroupName`" and the automatically created"
                                $prompt += " reverse replication Protection Group (where the replica VM is currently) with the same settings as the source Protection"
                                $prompt += " Group will be renamed to `"$sourcePgName`" (same as source) [y/n]`n"
                                
                                Confirm-Continue -Warning $warning -Prompt $prompt `
                                -ScriptIfNo {                                
                                    
                                    # Get VMs currently in target array Protection Group with same name but different settings as source

                                    $matchingGroupRepGroup = Get-SpbmReplicationGroup | ? name -eq "$( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$sourcePgName"

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
                                                "$( (Get-Date).ToString() ) Creating storage policy for target Protection Group $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName ...`n" |
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

                                            $renamedRepGroup = Get-SpbmReplicationGroup | ? name -eq "$( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName"

                                            if($renamedGroupSp -and $renamedRepGroup){
                                                if($matchingGroupDisks){
                                                
                                                    # Re-apply to disks in renamed, duplicate Protection Group                                            
                                                    
                                                    "$( (Get-Date).ToString() ) Assigning storage policy to $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName disks...`n" | Write-Verbose
                                                    $matchingGroupDisks | Get-SpbmEntityConfiguration |
                                                    Set-SpbmEntityConfiguration -StoragePolicy $renamedGroupSp -ReplicationGroup $renamedRepGroup | Out-Null
                                                    
                                                    # If disks compliant, re-apply to VMs if there are any
        
                                                    if((($matchingGroupDisks | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant'){
                                                        
                                                        # Re-apply to VMs in renamed, duplicate Protection Group
                                                        
                                                        if($matchingGroupVms){
                                                            "$( (Get-Date).ToString() ) Assigning storage policy to $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName VMs...`n" | Write-Verbose
                                                            $matchingGroupVms | Get-SpbmEntityConfiguration |
                                                            Set-SpbmEntityConfiguration -StoragePolicy $renamedGroupSp -ReplicationGroup $renamedRepGroup | Out-Null
        
                                                            # Check VMs under policy now compliant
        
                                                            if(!((($matchingGroupVms | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant')){
                                                                "$( (Get-Date).ToString() ) Failed to re-apply $( $renamedGroupSp.Name ) to VMs in $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName`n" | Write-Warning
                                                            }
                                                        }
                                                    } else { "$( (Get-Date).ToString() ) Failed to re-apply $( $renamedGroupSp.Name ) to disks in $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName`n" | Write-Warning }
                                                } else {
                                                    
                                                    # Re-apply to VMs in renamed, duplicate Protection Group

                                                    "$( (Get-Date).ToString() ) Assigning storage policy to $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName VMs...`n" | Write-Verbose
                                                    $matchingGroupVms | Get-SpbmEntityConfiguration |
                                                    Set-SpbmEntityConfiguration -StoragePolicy $renamedGroupSp -ReplicationGroup $renamedRepGroup | Out-Null
        
                                                    # Check VMs under policy now compliant
        
                                                    if(!((($matchingGroupVms | Get-SpbmEntityConfiguration).ComplianceStatus | select -Unique) -eq 'compliant')){
                                                        "$( (Get-Date).ToString() ) Failed to re-apply $( $renamedGroupSp.Name ) to VMs in $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName`n" | Write-Warning
                                                    }
                                                }                            
                                            } else {
                                                $warning = "$( (Get-Date).ToString() ) Unable to get storage policy and/or SPBM object for $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName."
                                                $warning += " Skipping application of storage policy to its VMs and/or disks ...`n"
                                                $warning | Write-Warning
                                            }
                                        } else {
                                            $warning = "$( (Get-Date).ToString() ) Unable to get VMs and/or disks, or there are none, for $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$newDuplicateTargetGroupName."
                                            $warning += " Skipping application of storage policy to them ..."
                                            $warning | Write-Warning
                                        }
                                    }
                                } `
                                -ScriptIfYes { $script:moveVols = $true; $script:pGroupName = $sourcePgName }
                            }
        
                        # Rename auto-created Protection Group to same as source if no existing target group with same name
        
                        } else { $newAutoGroupName = $sourcePgName }                    
                        
                        if(!$pGroupName){
                            if($newAutoGroupName){
                                                    
                                # Rename auto-created reverse Protection Group to same name as source if no Protection Group on target already has that name or has been renamed successfully 
            
                                "$( (Get-Date).ToString() ) Renaming auto-created target Protection Group $( $pGroup.protection_group ) to $newAutoGroupName ...`n" | Write-Verbose
                                Rename-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group -NewName $newAutoGroupName |Out-Null
                                
                                if(!(Get-PfaProtectionGroup -Array $targetFlashArray -Name $newAutoGroupName -ErrorAction SilentlyContinue)){
                                    "$( (Get-Date).ToString() ) Failed to rename $( $pGroup.protection_group )`n" | Write-Warning
                                    $pGroupName = $pGroup.protection_group
                                } else { $pGroupName = $newAutoGroupName }
                            
                            # Keep replica VM in auto-created Protection Group if target group with same name as source but different settings to auto-created group is unable to be renamed
                            
                            } else { $pGroupName = $pGroup.protection_group }
                        }
                                
                        # Create storage policy for replica VM Protection Group if policy with same Protection Group requirement doesn't already exist            

                        $sp = Get-SpbmStoragePolicy |
                        ? {($_.AnyOfRuleSets.AllOfRules |? {$_.Capability.Name -eq 'com.purestorage.storage.replication.ReplicationConsistencyGroup'}).Value -eq $pGroupName}
                        
                        if(!$sp){
                            "$( (Get-Date).ToString() ) Creating storage policy for $pGroupName on $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ) ...`n" | Write-Verbose
                            
                            $spName = "[vVol]$pGroupName"

                            # Create rule that adds VM to which policy is applied to target Protection Group
                            
                            $rule1 = New-SpbmRule -Capability 'com.purestorage.storage.replication.ReplicationConsistencyGroup' -Value $pGroupName
                            
                            # Create rule requiring VM to be stored on Pure Storage FlashArray
                            
                            $rule2 = New-SpbmRule -Capability 'com.purestorage.storage.policy.PureFlashArray' -Value $true
                            
                            # Add rules to ruleset and create storage policy

                            $ruleset = New-SpbmRuleSet -AllOfRules $rule1,$rule2
                            $sp = New-SpbmStoragePolicy -Name $spName -AnyOfRuleSets $ruleset
                        }                                        
                        
                        if(Get-VM -Id $replicaVms.Id -ErrorAction SilentlyContinue){

                            # Get SPBM object for replica VMs Protection Group and policy
                        
                            $replGroup = Get-SpbmReplicationGroup | ? name -eq "$( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$pGroupName"

                            if($sp -and $replGroup){
                                "$( (Get-Date).ToString() ) Assigning storage policy to replica VM disks ...`n" | Write-Verbose

                                # Apply policy and Protection Group to replica VM disks
                                
                                $replicaVms | Get-HardDisk | % {
                                    $_ | Get-SpbmEntityConfiguration |
                                    Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $replGroup | Out-Null                                

                                    if(($_ | Get-SpbmEntityConfiguration).StoragePolicy -ne $sp){
                                        "$( (Get-Date).ToString() ) Failed to assign storage policy $( $sp.Name ) to all $( $_.Parent.Name ) $( $_.Name )`n" | Write-Warning 
                                    }
                                }

                                "$( (Get-Date).ToString() ) Assigning storage policy to replica VM home ...`n" | Write-Verbose

                                # Apply policy and Protection Group to replica VMs
                                
                                $replicaVms | %{
                                    $_ | Get-SpbmEntityConfiguration |
                                    Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $replGroup | Out-Null                
                                    
                                    # Confirm storage policy has been applied
                                    
                                    if(($_ | Get-SpbmEntityConfiguration).StoragePolicy -ne $sp){
                                        "$( (Get-Date).ToString() ) Failed to assign storage policy $( $sp.Name ) to all $( $_.Name )`n" | Write-Warning 
                                    }
                                }
                            } else {
                                $warning = "$( (Get-Date).ToString() ) Unable to get storage policy and/or SPBM object for $( $srcGroup.Group.TgtReplGroup[0].FaultDomain.Name ):$pGroupName."
                                $warning += " Skipping application of storage policy to replica VM ...`n"
                                $warning | Write-Warning
                            }
                        
                        # Move replica VM vVols to existing Protection Group with same settings as auto-created one if it exists

                        } elseif($moveVols){

                            "$( (Get-Date).ToString() ) Moving replica vVols to $pGroupName`n" | Write-Verbose
                        
                            $excludeVols = ($excludeVols | ? {$_ -notmatch 'Swap'})
                            
                            # Remove replica VM vVols from auto-created Protection Group

                            Remove-PfaVolumesFromProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group -VolumesToRemove $excludeVols | Out-Null

                            # Check vVols have been removed

                            if(!($excludeVols | % { Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $_ -ErrorAction SilentlyContinue })){

                                # Add vVols to existing Protection Group with same settings

                                Add-PfaVolumesToProtectionGroup -Array $targetFlashArray -Name $pGroupName -VolumesToAdd $excludeVols | Out-Null

                                if(($excludeVols | % { Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $_ -ErrorAction SilentlyContinue } |
                                select -ExpandProperty protection_group -Unique) -eq $pGroupName){
                                    "$( (Get-Date).ToString() ) Replica vVols successfully moved to $pGroupName`n" | Write-Verbose
                                } else { "$( (Get-Date).ToString() ) Unable to confirm move of replica VM vVols to $pGroupName`n" | Write-Warning }
                            } else { "$( (Get-Date).ToString() ) Unable to confirm removal of replica VM vVols from $( $pGroup.protection_group ). Skipping move to $pGroupName ...`n" | Write-Warning }                        
                        }

                        if($moveVols){
                            if(!(Get-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group).volumes){
                                "$( (Get-Date).ToString() ) Replica vVols have been moved to existing Protection Group with same settings as $( $pGroup.protection_group ). Removing it ...`n" |
                                Write-Verbose

                                # Remove memberless auto-created target Protection Group

                                Remove-PfaProtectionGroupOrSnapshot -Array $targetFlashArray -Name $pGroup.protection_group | Out-Null
                                Remove-PfaProtectionGroupOrSnapshot -Array $targetFlashArray -Name $pGroup.protection_group -Eradicate | Out-Null
                                
                                if($pGroup.protection_group -in (Get-PfaProtectionGroups -Array $targetFlashArray | select -ExpandProperty Name)){
                                    "$( (Get-Date).ToString() ) Unable to remove empty $( $pGroup.protection_group )`n" | Write-Warning
                                }
                            } else { "$( (Get-Date).ToString() ) Unable to remove $( $pGroup.protection_group ) as it still contains vVols`n" | Write-Warning }
                        }

                        # Synchronise target Protection Group
                        
                        if((Get-PfaProtectionGroup -Array $targetFlashArray -Name $pGroupName).volumes){
                            "$( (Get-Date).ToString() ) Creating new snapshot for target group $pGroupName to be replicated to $( $srcGroup.Group.SrcReplGroup[0].FaultDomain.Name ) ...`n" | Write-Verbose

                            # Take snapshot for target Protection Group and replicate. Apply retention policy if number of snapshots exceeds retention setting

                            New-PfaProtectionGroupSnapshot -Array $targetFlashArray -ProtectionGroups $pGroupName -ReplicateNow -ApplyRetention | Out-Null
                        }
                    } else {
                        $warning = "$( (Get-Date).ToString() ) Unable to retrieve automatically created reverse replication Protection Group of replica."
                        $warning += " Skipping removal of unregistered vVols, Protection Group clean up and storage policy management ...`n"
                        $warning | Write-Warning
                    }
                } else {
                    "`n$( (Get-Date).ToString() ) Unable to retrieve replica config vVol. Skipping removal of unregistered vVols, Protection Group clean up and storage policy management ...`n" |
                    Write-Warning
                }
                
                # Return VM object or vmx path

                if(Get-VM -Id $replicaVms.Id -ErrorAction SilentlyContinue){ Get-VM -Id $replicaVms.Id } else { $replicaVmPaths }                
            }
        } catch {            
            $Error[0] | Write-Error
            "`n$( (Get-Date).ToString() ) A terminating error occurred in the End block`n" | Write-Error
        } finally {
            
            # Remove script scoped variables to prevent interference with repeat use of function in same shell context
            
            $scriptVars = 'exit', 'vmsAndReplicaNames', 'skipReg', 'DestinationFolder', 'replSnapshots', 'replSnapshot', 'snap', 'newAutoGroupName', 'moveVols', 'pGroupName'
            
            Get-Variable -Name $scriptVars -Scope Script -ErrorAction SilentlyContinue | Remove-Variable -Scope Script -ErrorAction SilentlyContinue                
        }
    }
}