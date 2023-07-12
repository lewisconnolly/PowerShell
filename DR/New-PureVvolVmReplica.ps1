<#
.SYNOPSIS
    Create a replica of a Pure Storage vVol VM that is a member of a Protection Group with a replication target that is a Pure Storage FlashArray with a connected vVol datastore.  
.DESCRIPTION
    This function takes a VM whose vVols have been replicated from one Pure Storage FlashArray to another via Protection Group membership and creates VM files that can be registered to an ESXi cluster connected to the target Pure Storage FlashArray's vVol datastore.
    It then reverses replication in preparation for creating replicas from the newly created VMs (i.e. failback).
    A storage policy is created if it does not already exist and then applied to the replica VM if it is registered in the VM inventory in order to maintain the storage policy management framework.
    Optional parameters are included to shut down and/or remove source VM; change replica VM portgroup(s), hostname, IP(s), Default Gateway and DNS servers; and to synchronise Protection Group before creation of replica VM files.  
.PARAMETER SourceVm
    The object of a Pure Storage vVol VM in a replication enabled Protection Group. Must be a single VM.
.PARAMETER ReplicaName
    The name to use for the replica VM to be created.
.PARAMETER RegisterReplicaVm
    Include if replica VM is to be registered in destination cluster. If used without -DestinationCluster and/or -DestinationFolder they will be automatically chosen.
.PARAMETER StartReplicaVm
    Include if replica VM is to be registered and powered on. If used without -DestinationCluster and/or -DestinationFolder they will be automatically chosen.
.PARAMETER DestinationCluster
    The destination cluster where the replica VM is to be registered. Must be connected to target array's vVol datastore.
.PARAMETER DestinationFolder
    The destination folder where the replica VM is to be registered. Must be available in the same datacenter as the target array's vVol datastore.
.PARAMETER SourceFlashArrayCredential
    The credential object for the array of the source VM. Used when synchronising Protection Group before creation of replica VM and to recreate source Protection Group after failover. Username should not contain domain name prefix, e.g "ZONALCONNECT\lewisc".
.PARAMETER TargetFlashArrayCredential
    The credential object for the array of the replica VM. Used to retrieve details of failback Protection Group on target array and to remove unwanted vVols created during failover. Username should not contain domain name prefix, e.g "ZONALCONNECT\lewisc".
.PARAMETER SyncProtectionGroup
    Create and replicate an on-demand snapshot from the source VM Protection Group before creating the replica VM.
.PARAMETER MostRecentSnapshot
    Use the most recently replicated source VM Protection Group snapshot to create the replica VM from.
.PARAMETER ShutdownSourceVmFirst
    Shut down the source VM before creating the replica.
.PARAMETER RemoveSourceVm
    Shut down the source VM if it is still powered on and remove from inventory after the replica VM has been created. 
.PARAMETER RemoveSourceVmPermanently
    Shut down the source VM if it is still powered on and delete from disk after the replica VM has been created. 
.EXAMPLE    
    #
    # Create replica VM dcautlprdvbs01_replica of dcautlprdvbs01 from newly created Protection Group snapshot
    # Shut down the source VM beforehand and delete it from disk afterward
    # Change portgroup, IP, Default Gateway, DNS servers and hostname of replica VM
    # $domainCred, $vbs01Cred and $faCred have previously been assigned to appropriate credentials 
    # Output verbose logging messages

    New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01) `
        -StartReplicaVm `
        -ReplicaVmPortgroups (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:2') `
        -ReplicaVmIpDetails '172.30.2.152,255.255.255.0,172.30.2.254' `
        -ReplicaVmDnsServers '172.30.6.136', '172.30.6.137' `
        -ReplicaVmHostname 'dcautlprdvbs01r' `
        -DomainJoinCredential $domainCred `
        -DestinationCluster (Get-Cluster DCB-Cluster) `
        -DestinationFolder (Get-Folder Veeam -Location DCB) `
        -LocalAdminCredential $vbs01Cred `
        -SyncProtectionGroup `
        -SourceFlashArrayCredential $faCred `
        -TargetFlashArrayCredential $faCred `
        -MostRecentSnapshot `
        -RemoveSourceVmPermanently `
        -Verbose
.EXAMPLE     
    #
    # Create replica VM dcb-utl-sep of dca-utl-sep, which has two network adapters, from newly created Protection Group snapshot
    # Shut down the source VM beforehand and delete it from disk afterward
    # Change portgroup, IP, Default Gateway, DNS servers and hostname of replica VM
    # $domainCred, $sepCred and $faCred have previously been assigned to appropriate credentials
    # Using paramater aliases

    New-PureVvolVmReplica -VM (Get-VM dca-utl-sep) `
        -Name 'dcb-utl-sep' `
        -PowerOn `
        -Portgroups (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:39'), (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:Untagged') `
        -IPs '172.30.6.135,255.255.255.128,172.30.6.129', '172.30.1.15,255.255.255.0' `
        -DNS '172.30.6.136', '172.30.6.137' `
        -Hostname 'dcb-utl-sep' `
        -DomainCred $domainCred `
        -Cluster (Get-Cluster DCB-Cluster) `
        -Folder (Get-Folder Utility -Location DCB) `
        -AdminCred $sepCred `
        -Sync `
        -SourceFaCred $faCred `
        -TargetFaCred $faCred `
        -MostRecentSnapshot `
        -DeleteSource
.EXAMPLE
    #
    # Create replica VM dcautlprdvbs01 of dcautlprdvbs01r. Take new snapshot before failover and choose snapshot manually
    # Shut down the source VM beforehand and delete it from disk afterward
    # Change portgroup, IP, Default Gateway, DNS servers and hostname of replica VM
    # $domainCred, $vbs01Cred and $faCred have previously been assigned to appropriate credentials
    # -DestinationCluster and -DestinationFolder omitted and so are chosen automatically

    New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01r) `
        -ReplicaName 'dcautlprdvbs01' `
        -ShutdownSourceVmFirst `
        -StartReplicaVm `
        -ReplicaVmHostname 'dcautlprdvbs01' `
        -DomainJoinCredential $domainCred `
        -ReplicaVmPortgroups (Get-VDPortgroup 'DCA-DSw0LAG-DPG-VLAN:2') `
        -ReplicaVmIpDetails '172.31.2.152,255.255.255.0,172.31.2.1' `
        -ReplicaVmDnsServers '172.31.6.136', '172.31.6.137' `
        -LocalAdminCredential $vbs01Cred `
        -SyncProtectionGroup `
        -SourceFlashArrayCredential $faCred `
        -TargetFlashArrayCredential $faCred `
        -RemoveSourceVmPermanently
.EXAMPLE
    #
    # Create replica vVols of dcautlprdvbs01 on target array
    # Output vmx file path that can be used to register VM
    # $faCred has previously been assigned to appropriate credential

    New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01) -SourceFlashArrayCredential $faCred -TargetFlashArrayCredential $faCred
.EXAMPLE
    #
    # Create replica VM dcautlprdvbs01_replica of dcautlprdvbs01
    # Register replica VM and change portgroup
    # $faCred has previously been assigned to appropriate credentials
    # -DestinationCluster and -DestinationFolder omitted and so are chosen automatically
    # Source VM left as is
    
    New-PureVvolVmReplica -SourceVm (Get-VM dcautlprdvbs01) `
        -RegisterReplicaVm `
        -ReplicaVmPortgroups (Get-VDPortgroup 'DCB-DSw0-DPG-VLAN:2') `
        -SourceFlashArrayCredential $faCred `
        -TargetFlashArrayCredential $faCred
.OUTPUTS
    $null or one UniversalVirtualMachineImpl object or one vmx file path string.
.NOTES
    Dynamic parameters:
    
    -ReplicaVmPortgroups <Object[]>
    Include if replica VM network adapter portgroup(s) are to be changed. Requires -RegisterReplicaVm or -StartReplicaVm to be included.
    
    Required?                    false
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

    -ReplicaVmHostname <String>
    Include if replica VM hostname is to be changed. Guest OS must be Windows. Requires -StartReplicaVm and -LocalAdminCredential to be included.
    
    > Hostname can be between 1 and 15 characters long
    > Can contain only alphanumeric, '_', '-' and '.' characters
    > Must start with an alphanumeric character
    > Cannot end with '-' or '.' characters
    > Cannot contain only numerals
    
    Required?                    false
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

    -DomainJoinCredential <PSCredential>
    The credential object for a user with permission to log on to the replica VM and to re-add it to its current domain. Replica VM hostname is changed when the replica VM may not have network access. As such, it is removed from its domain before changing hostname and re-added afterward. Required if using -ReplicaVmHostname and replica VM is a member of a domain.

    Required?                    false (true if -ReplicaVmHostname and replica VM is a member of a domain)
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

    -ReplicaVmIpDetails <String[]>
    Include if replica VM IPs and/or Default Gateway is to be changed. IPv4 only. Guest OS must be Windows. One item per VM network adapter. Each item must be in format:
    
    '<IP>,<SubnetMask>,<DefaultGateway>' or '<IP>,<SubnetMask>'
    e.g. '172.31.1.10,255.255.255.0,172.31.1.1' or '172.31.1.10,255.255.255.0'

    Requires -StartReplicaVm and -LocalAdminCredential to be included.

    Required?                    false
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

     -ReplicaVmDnsServers <String[]>
    Include if replica VM DNS servers are to be changed. Maximum of two items. IPv4 only. Guest OS must be Windows. Changes DNS servers on first network adapter. Requires -StartReplicaVm and -LocalAdminCredential to be included.
    
    Required?                    false
    Position?                    named
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

    -LocalAdminCredential <PSCredential>
    The credential object for local administrator on the source VM. Used to change guest network settings of replica VM. Required if using any of -ReplicaVmHostname, -ReplicaVmIpDetails, and -ReplicaVmDnsServers.

    Required?                    false (true if -ReplicaVmHostname/-ReplicaVmIpDetails/-ReplicaVmDnsServers included)
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
function New-PureVvolVmReplica {
    [CmdletBinding(DefaultParameterSetName='Remove source VM',
                   PositionalBinding=$false)]
    [Alias()]
    [OutputType([VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl])]
    [OutputType([String])]
    Param (        
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Alias("VM")]
        [ValidateScript({ $_.PSObject.TypeNames[0] -eq 'VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl' })]
        $SourceVm,

        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [String]
        $ReplicaName = $SourceVm.Name + "_replica",
        
        [Alias("Register")]
        [Switch]
        $RegisterReplicaVm,

        [Alias("PowerOn")]
        [Switch]
        $StartReplicaVm,                        

        [Alias("Cluster")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.PSObject.TypeNames[0] -eq 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl' })]
        $DestinationCluster,

        [Alias("Folder")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.PSObject.TypeNames[0] -eq 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl' })]
        $DestinationFolder,

        [Alias("SourceFaCred")]
        [Parameter(Mandatory=$true)]
        [PSCredential]
        $SourceFlashArrayCredential,

        [Alias("TargetFaCred")]
        [Parameter(Mandatory=$true)]
        [PSCredential]
        $TargetFlashArrayCredential,

        [Alias("Sync")]
        [Switch]
        $SyncProtectionGroup,

        [Switch]
        $MostRecentSnapshot,

        [Alias("ShutdownSource")]
        [Switch]
        $ShutdownSourceVmFirst,

        [Alias("RemoveSource")]
        [Parameter(ParameterSetName='Remove source VM')]
        [Switch]
        $RemoveSourceVm,

        [Alias("DeleteSource")]
        [Parameter(ParameterSetName='Remove source VM permanently')]
        [Switch]
        $RemoveSourceVmPermanently
    )
    
    DynamicParam
    {                      
        if ($RegisterReplicaVm -or $StartReplicaVm){
            
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary  
            
            # If -RegisterReplicaVm or -StartReplicaVm then enable use of -ReplicaVmPortgroups parameter

            if($RegisterReplicaVm -or $StartReplicaVm){
            
                # Create -ReplicaVmPortgroups parameter

                $pgAttribute = New-Object System.Management.Automation.ParameterAttribute
                $pgAttribute.Mandatory = $false
                $pgAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $pgAlias = New-Object System.Management.Automation.AliasAttribute 'Portgroups'
                $pgAttributeCollection.Add($pgAttribute)
                $pgAttributeCollection.Add($pgAlias)
                $pgParam = New-Object System.Management.Automation.RuntimeDefinedParameter('ReplicaVmPortgroups', [Object[]], $pgAttributeCollection)            
                $paramDictionary.Add('ReplicaVmPortgroups', $pgParam)
            }
            
            # If -StartReplicaVm then enable use of guest OS network changes parameters
            
            if($StartReplicaVm){
                
                # Create -ReplicaVmHostname parameter
                
                $hostnameAttribute = New-Object System.Management.Automation.ParameterAttribute
                $hostnameAttribute.Mandatory = $false
                $hostnameAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $hostnameAlias = New-Object System.Management.Automation.AliasAttribute 'Hostname'
                $hostnameAttributeCollection.Add($hostnameAttribute)
                $hostnameAttributeCollection.Add($hostnameAlias)
                $hostnameParam = New-Object System.Management.Automation.RuntimeDefinedParameter('ReplicaVmHostname', [String], $hostnameAttributeCollection)
                $paramDictionary.Add('ReplicaVmHostname', $hostnameParam)

                # Create -DomainJoinCredential parameter
                
                $domainAttribute = New-Object System.Management.Automation.ParameterAttribute
                $domainAttribute.Mandatory = $false
                $domainAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $domainAlias = New-Object System.Management.Automation.AliasAttribute 'DomainCred'
                $domainAttributeCollection.Add($domainAttribute)
                $domainAttributeCollection.Add($domainAlias)
                $domainParam = New-Object System.Management.Automation.RuntimeDefinedParameter('DomainJoinCredential', [PSCredential], $domainAttributeCollection)
                $paramDictionary.Add('DomainJoinCredential', $domainParam)
                
                # Create -ReplicaVmIpDetails parameter
                
                $ipAttribute = New-Object System.Management.Automation.ParameterAttribute
                $ipAttribute.Mandatory = $false
                $ipAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $ipAlias = New-Object System.Management.Automation.AliasAttribute 'IPs'
                $ipAttributeCollection.Add($ipAttribute)
                $ipAttributeCollection.Add($ipAlias)
                $ipParam = New-Object System.Management.Automation.RuntimeDefinedParameter('ReplicaVmIpDetails', [String[]], $ipAttributeCollection)
                $paramDictionary.Add('ReplicaVmIpDetails', $ipParam)

                # Create -ReplicaVmDnsServers parameter
                
                $dnsAttribute = New-Object System.Management.Automation.ParameterAttribute
                $dnsAttribute.Mandatory = $false
                $dnsAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $dnsAlias = New-Object System.Management.Automation.AliasAttribute 'DNS'
                $dnsAttributeCollection.Add($dnsAttribute)
                $dnsAttributeCollection.Add($dnsAlias)
                $dnsParam = New-Object System.Management.Automation.RuntimeDefinedParameter('ReplicaVmDnsServers', [String[]], $dnsAttributeCollection)
                $paramDictionary.Add('ReplicaVmDnsServers', $dnsParam)                

                # Create -LocalAdminCredential parameter
                
                $adminAttribute = New-Object System.Management.Automation.ParameterAttribute
                $adminAttribute.Mandatory = $false
                $adminAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $adminAlias = New-Object System.Management.Automation.AliasAttribute 'AdminCred'
                $adminAttributeCollection.Add($adminAttribute)
                $adminAttributeCollection.Add($adminAlias)
                $adminParam = New-Object System.Management.Automation.RuntimeDefinedParameter('LocalAdminCredential', [PSCredential], $adminAttributeCollection)
                $paramDictionary.Add('LocalAdminCredential', $adminParam)
            }            

            return $paramDictionary
        }
    }

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
            
            # Get Protection Group of source VM

            $srcReplGroup = Get-SpbmReplicationGroup -VM $SourceVm

            if(!$srcReplGroup){ throw "`n$( (Get-Date).ToString() ) $( $SourceVm.Name ) not in a Protection Group`n" }
            
            # Get corresponding Protection Group on target array

            $tgtReplGroup = Get-SpbmReplicationPair -Source $srcReplGroup | select -ExpandProperty target

            if(!$tgtReplGroup){ throw "`n$( (Get-Date).ToString() ) Unable to retrieve corresponding Protection Group for $( $srcReplGroup.name ) on target array`n" }
            
            # Exit if the Protection Group is already in a failed over state
            
            if($tgtReplGroup.State -eq 'FailedOver'){
                throw "`n$( (Get-Date).ToString() ) Target replication group $( ($tgtReplGroup.Description -split ' ')[0] ) on $( $tgtReplGroup.FaultDomain.Name ) is already in the FailedOver state`n"
            }

            # Get vVol datastore of target array

            $tgtDatastore = Get-Datastore | ? Type -eq 'VVOL' | ? {$_.ExtensionData.Info.VvolDS.StorageArray.Name -eq $tgtReplGroup.FaultDomain.Name}
            
            # Throw error and exit if no vVol datastore for target array

            if(!$tgtDatastore){ throw "`n$( (Get-Date).ToString() ) Unable to find vVol datastore for target array`n" }            

            # Test source FlashArray credential (mandatory)
                        
            "$( (Get-Date).ToString() ) Connecting to $( $srcReplGroup.FaultDomain.Name ) ...`n" | Write-Verbose
            $sourceFlashArray = New-PfaArray -EndPoint $srcReplGroup.FaultDomain.Name -Credentials $SourceFlashArrayCredential -IgnoreCertificateError
 
            if(!$sourceFlashArray){ throw "`n$( (Get-Date).ToString() ) Couldn't connect to $( $srcReplGroup.FaultDomain.Name )`n" }            
 
            # Test target FlashArray credential (mandatory)
 
            "$( (Get-Date).ToString() ) Connecting to $( $tgtReplGroup.FaultDomain.Name ) ...`n" | Write-Verbose
            $targetFlashArray = New-PfaArray -EndPoint $tgtReplGroup.FaultDomain.Name -Credentials $TargetFlashArrayCredential -IgnoreCertificateError
 
            if(!$targetFlashArray){ throw "$( (Get-Date).ToString() ) `nCouldn't connect to $( $tgtReplGroup.FaultDomain.Name )`n" }
            
            # Check replica vVols don't already exist on target array

            $SourceVm.ExtensionData.LayoutEx.File | ? {($_.type -eq 'config') -or ($_.type -eq 'diskDescriptor')} | % {
                
                # Try block required to ignore error because Get-PfaVolumeNameFromVvolUuid creates a terminating error if no vVols found,
                # even when setting ErrorAction to SilentlyContinue
                
                try{
                    if(Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray -VvolUUID $_.BackingObjectId){
                        "`n$( (Get-Date).ToString() ) $( $SourceVm.Name ) vVol $( $_.Name ) already exists on $( $tgtReplGroup.FaultDomain.Name )`n" | Write-Error                        
                        $exit = $true
                    }
                } catch {}
            }
            
            if($exit){ return }

            # If replica VM is to be registered, check for VM with same name as specified name for replica and throw error then exit if it exists
            
            if($RegisterReplicaVm -or $StartReplicaVm -or $DestinationCluster -or $DestinationFolder){
                if((Get-VM $ReplicaName -ErrorAction SilentlyContinue)){
                    throw "`n$( (Get-Date).ToString() ) VM with name $ReplicaName already exists in connected vcenter(s): $( $global:DefaultVIServers.Name -join '/')`n"
                }
            }

            # Validate guest network changes parameters

            if($PSBoundParameters.ReplicaVmIpDetails -or $PSBoundParameters.ReplicaVmDnsServers -or $PSBoundParameters.ReplicaVmHostname){
                if($SourceVm.Guest.ConfiguredGuestId -match 'windows'){
                    if($PSBoundParameters.LocalAdminCredential){
                        
                        # Check admin cred on source VM
                                
                        # Run 'hostname' command on source VM to test local admin credential
                        # If command output is empty credential might have failed. Confirm skip of replica VM network changes

                        if($SourceVm.PowerState -ne 'PoweredOn'){                                                        
                            
                            # If source VM isn't powered on, confirm skip of credential testing or power it on
                            
                            Confirm-Continue -Warning "$( (Get-Date).ToString() ) $( $SourceVm.Name ) is not powered on. Local admin credential cannot be tested" `
                            -Prompt "`nSkip testing credential? [y/n]`n" `
                            -ScriptIfNo {
                                $confirm = $null
                                Confirm-Continue -Prompt "`nDo you want to power on $( $SourceVm.Name )? [y/n]`n" `
                                -ScriptIfNo { "`n$( (Get-Date).ToString() ) Skipping credential test ...`n" | Write-Host; $script:skipCredTest = $true } `
                                -ScriptIfYes {
                                    $script:reshutdown = $true                                    
                                    Start-VM $SourceVm.Name | Out-Null
                                    
                                    "`n$( (Get-Date).ToString() ) Waiting 120 seconds for $( $SourceVm.Name ) to start ...`n" | Write-Host

                                    # Wait for replica VM to restart

                                    sleep 120
                                }
                            } `
                            -ScriptIfYes { $script:skipCredTest = $true }
                        }

                        if(!$skipCredTest){
                            if(!(Invoke-VMScript -ScriptText 'hostname' -VM (Get-VM $SourceVm) -GuestCredential $PSBoundParameters.LocalAdminCredential `
                            -ScriptType Powershell)){
                                Confirm-Continue -Warning "$( (Get-Date).ToString() ) Unable to invoke script on $( $SourceVm.Name ). Check local admin credential" `
                                -Prompt "`nSkip guest network changes? [y/n]`n" `
                                -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                -ScriptIfYes { $script:skipReIp = $true; $script:skipDns = $true; $script:skipHostname = $true }                           
                                
                                if($exit){ return }

                            # Check VMTools is installed

                            } elseif(!($SourceVm.ExtensionData.Config.Tools.ToolsVersion)){
                                Confirm-Continue -Warning "$( (Get-Date).ToString() ) $( $SourceVm.name ) does not have VMTools installed" `
                                -Prompt "`nSkip guest network changes? [y/n]`n" `
                                -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                -ScriptIfYes { $script:skipReIp = $true;  $script:skipDns = $true; $script:skipHostname = $true }
                                
                                if($exit){ return }
                            }
                        }
                        
                        if($PSBoundParameters.ReplicaVmHostname -and !$skipHostname){                                                        
                            if($PSBoundParameters.DomainJoinCredential){
                                if(!$skipCredTest){
                                    if(!(Invoke-VMScript -ScriptText 'hostname' -VM (Get-VM $SourceVm) `
                                    -GuestCredential $PSBoundParameters.DomainJoinCredential -ScriptType Powershell)){
                                        Confirm-Continue -Warning "$( (Get-Date).ToString() ) Unable to invoke script on $( $SourceVm.Name ) using domain join credential. Check credential" `
                                        -Prompt "`nSkip hostname change? [y/n]`n" `
                                        -ScriptIfNo {
                                            $confirm = $null
                                            Confirm-Continue -Prompt "`nTry to change hostname of replica anyway? If no, function will exit [y/n]`n" `
                                            -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } 
                                        } `
                                        -ScriptIfYes { $script:skipHostname = $true }
                                        
                                        if($exit){ return }
                                    }
                                } else { "$( (Get-Date).ToString() ) Skipping domain join credential test ...`n" | Write-Warning }
                            }

                            if(!$skipHostname){
                                if($PSBoundParameters.ReplicaVmHostname -notmatch '(?=.*[A-za-z\.\-]+.*)(^[A-Za-z0-9][\w\.\-]{0,13}[\w]{0,1}$)'){
                                    $warning = "Hostname not in correct format`n"
                                    $warning += "`nHostname can be 1-15 characters long`n"
                                    $warning += "Can contain alphanumeric, '_', '-', '.' characters`n"
                                    $warning += "Must start with a letter or number`n"
                                    $warning += "Cannot end with  '-' or '.'`n"
                                    $warning += "Cannot contain only numbers"
                                    
                                    Confirm-Continue -Warning $warning `
                                    -Prompt "`nSkip change of hostname? [y/n]`n" `
                                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                    -ScriptIfYes { $script:skipHostname = $true }
                                    
                                    if($exit){ return }
                                }
                            }                            
                        }
                        
                        # Shut down source VM if powered on to test credential

                        if($reshutdown){
                            "`n$( (Get-Date).ToString() ) Shutting down $( $SourceVm.name ) ...`n" | Write-Host
                
                            # If VM isn't powered off already, power it off
                            
                            if((Get-VM $SourceVm).PowerState -ne 'PoweredOff'){
                                
                                # Attempt guest OS shutdown process

                                Get-VM $SourceVm | Stop-VMGuest | Out-Null
                                if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
                                
                                # Create stopwatch to wait 60 seconds for guest OS shutdown                    

                                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()                    

                                # While waiting for shutdown, check time on stopwatch

                                while(((Get-VM $SourceVm).PowerState -ne 'PoweredOff') -and $stopwatch.IsRunning){
                                    "`n$( (Get-Date).ToString() ) Waiting on guest OS shutdown process to finish ...`n" | Write-Host
                                    
                                    # If VM not in powered off state after 60 seconds then confirm force power off
                                    
                                    if($stopwatch.Elapsed.TotalSeconds -ge 60){
                                        "`n$( (Get-Date).ToString() ) It has been at least 60 seconds and $( $SourceVm.Name ) has not shut down. Confirm if you want to power off VM ...`n" | Write-Host
                                        (Get-VM $SourceVm) | Stop-VM | Out-Null
                                        if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

                                        # Stop stopwatch once VM force powered off or not
                                        
                                        $stopwatch.Stop()
                                    }
                                    sleep 5
                                }

                                if((Get-VM $SourceVm).PowerState -ne 'PoweredOff'){
                                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) Failed to shut down/power off $( $SourceVm.name ) after local admin credential test" `
                                    -Prompt "`nContinue? [y/n]`n" `
                                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }

                                    if($exit){ return }
                                }
                            } else { "`n$( (Get-Date).ToString() ) $( $SourceVm.Name ) is already powered off`n" | Write-Host }
                        }

                        if($PSBoundParameters.ReplicaVmDnsServers -and !$skipDns){
                            while(!$skipDns -and !$changeDns){                        
                                
                                # Check no more than 2 DNS servers specified
                                
                                if($PSBoundParameters.ReplicaVmDnsServers.count -gt 2){
                                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) More than two DNS servers specified" `
                                    -Prompt "`nSkip change of DNS servers? [y/n]`n" `
                                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                    -ScriptIfYes { $script:skipDns = $true }

                                    if($exit){ return }
                                }
                                
                                while(!$badFormat -and !$formatOk){
                                    
                                    # Check each DNS server for correct format
                                    
                                    $PSBoundParameters.ReplicaVmDnsServers | % {
                                        
                                        # Check each item is a valid IP

                                        if($_ -notmatch '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'){
                                            "$( (Get-Date).ToString() ) $_ is not a valid IP`n" | Write-Warning
                                            $badFormat = $true
                                        }
                                    }                                
                                    $formatOK = $true
                                }

                                if($badFormat){
                                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) Not all DNS servers are valid IPs" `
                                    -Prompt "`nSkip change of DNS servers? [y/n]`n" `
                                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                    -ScriptIfYes { $script:skipDns = $true }

                                    if($exit){ return }
                                }

                                $changeDns = $true                            
                            }
                        }
                        
                        if($PSBoundParameters.ReplicaVmIpDetails -and !$skipReIp){
                            while (!$skipReIp -and !$reIpOk) {                                                                                                            
                                
                                # Confirm skip of re-IPing if more settings groups than network adapters are provided
                                
                                if(($SourceVm | Get-NetworkAdapter).Count -ne $PSBoundParameters.ReplicaVmIpDetails.Count){
                                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) More IP settings groups than $( $SourceVm.name ) network adapters were provided" `
                                    -Prompt "`nSkip re-IPing? [y/n]`n" `
                                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                    -ScriptIfYes { $script:skipReIp = $true }
                                    
                                    if($exit){ return }                                    
                                }

                                # Check format of IP settings groups
                                
                                $badFormat = $false
                                $formatOk = $false

                                while(!$badFormat -and !$formatOk){
                                    
                                    # Check each IP group setting for correct format
                                    
                                    $PSBoundParameters.ReplicaVmIpDetails | % {
                                        
                                        # Split up settings group into IP, Subnet Mask and Default Gateway
                                        
                                        $ipDetailsArray = $_ -split ',' | % { $_.Trim() }
                                        
                                        # Check if each item is a valid IP
                                        
                                        $ipDetailsArray | % {
                                            if($_ -notmatch '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'){
                                                "$( (Get-Date).ToString() ) $_ is not a valid IP/subnet mask`n" | Write-Warning
                                                $badFormat = $true
                                            }
                                        }

                                        # Check there is a maximum of three items in each item of $PSBoundParameters.ReplicaVmIpDetails

                                        if($ipDetailsArray.Count -gt 3){
                                            "$( (Get-Date).ToString() ) Too many values (there should only be one of each: IP, Subnet Mask, and Default Gateway) in $_`n" |
                                            Write-Warning
                                            $badFormat = $true
                                        }
                                    }
                                    
                                    $formatOK = $true
                                }

                                if($badFormat){
                                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) Not all IP settings groups are in format `"<IPv4Address>,<SubnetMask>,<DefaultGateway>`" or `"<IPv4Address>,<SubnetMask>`"" `
                                    -Prompt "`nSkip re-IPing? [y/n]`n" `
                                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                                    -ScriptIfYes { $script:skipReIp = $true }

                                    if($exit){ return }
                                }

                                $reIpOk = $true
                            }
                        }
                    } else { throw "`n$( (Get-Date).ToString() ) -LocalAdminCredential required if using any one of -ReplicaVmHostname, -ReplicaVmIpDetails, and -ReplicaVmDnsServers`n" }
                } else {
                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) Unable to make guest network changes on non-Windows VMs" `
                    -Prompt "`nSkip guest network changes? [y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                    -ScriptIfYes { $script:skipReIp = $true; $script:skipDns = $true; $script:skipHostname = $true }

                    if($exit){ return }
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
                    -Prompt "`nUse 'Discovered virtual machine' folder? If no, function will exit [y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                    -ScriptIfYes { $script:DestinationFolder = Get-Folder 'Discovered virtual machine' -Location $tgtDatastore.Datacenter }

                    if($exit){ return }
                }
            }
            
            if($PSBoundParameters.ReplicaVmPortgroups){
                
                # If more portgroups provided than source VM network adapters, confirm use of temporary portgroups

                if(($SourceVm | Get-NetworkAdapter).Count -ne $PSBoundParameters.ReplicaVmPortgroups.Count){                    
                    Confirm-Continue -Warning  "$( (Get-Date).ToString() ) More portgroups than $( $SourceVm.name ) network adapters were provided" `
                    -Prompt "`nPut network adapters in temporary, untagged portgroups? If no, function will exit [y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                    -ScriptIfYes { $script:useTempPgs = $true }

                    if($exit){ return }
                }
                
                if(!$useTempPgs){

                     # Check portgroups are available in -DestinationCluster cluster or destination datacenter if -DestinationCluster not specified

                    if($DestinationCluster){                
                        
                        # Warn if any portgroup in $PSBoundParameters.ReplicaVmPortgroups is not connected to hosts in destination cluster

                        $PSBoundParameters.ReplicaVmPortgroups | % {
                            $pg = $_
                            if(!($DestinationCluster | Get-VMHost |
                            Get-VDSwitch -WarningAction SilentlyContinue |
                            Get-VDPortgroup -Name $pg.Name -WarningAction SilentlyContinue -ErrorAction SilentlyContinue)){
                                "$( (Get-Date).ToString() ) $( $pg.Name ) is not connected to hosts in destination cluster`n" | Write-Warning
                                $pgUnavailable = $true
                            }
                        }
                    } else {

                        # If no -DestinationCluster provided then get all clusters in target datacenter
                        
                        $DestinationClusters = $tgtDatastore.Datacenter | Get-Cluster |
                        ? {($_ | Get-Datastore | select -ExpandProperty Name) -contains $tgtDatastore.Name}
                        
                        # Check each cluster in destination datacenter for portgroups availability

                        $DestinationClusters | % {
                            if(!$DestinationCluster){
                                $pgUnavailable = $false
                                $cluster = $_

                                $PSBoundParameters.ReplicaVmPortgroups | % {
                                    $pg = $_.Name

                                    # If portgroup not available then $pgUnavailable = $true                                                               

                                    if(!($cluster | Get-VMHost |
                                    Get-VDSwitch -WarningAction SilentlyContinue |
                                    Get-VDPortgroup -Name $pg -WarningAction SilentlyContinue -ErrorAction SilentlyContinue)){
                                        $pgUnavailable = $true
                                    }
                                }

                                # If, after checking all portgroups are available in current cluster, $pgUnavailable is still false, set $DestinationCluster and stop checking clusters 

                                if(!$pgUnavailable) {
                                    $DestinationCluster = $cluster
                                }
                            }
                        }
                    }

                    # If no clusters in target datacenter are connected to all portgroups, confirm use of temporary portgroups
                    
                    if(!$DestinationCluster){
                        Confirm-Continue -Warning  "$( (Get-Date).ToString() ) No clusters in target datacenter are connected to all portgroups" `
                        -Prompt "`nPut network adapters in temporary, untagged portgroups? If no, function will exit [y/n]`n" `
                        -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                        -ScriptIfYes { $script:useTempPgs = $true }
                        
                        if($exit){ return }
                    }
                }
            }

            # Take a new storage snapshot and replicate to the target array before failover if -SyncProtectionGroup switch specified
            
            if($SyncProtectionGroup){
                "`n$( (Get-Date).ToString() ) Synchronising Protection Group $( $srcReplGroup.name ) ...`n" | Write-Host                                                
                "$( (Get-Date).ToString() ) Creating new snapshot for Protection Group $($srcReplGroup.name) to be replicated to $( $tgtReplGroup.FaultDomain.Name ) ...`n" |
                Write-Verbose

                # Take snapshot for source Protection Group and replicate. Apply retention policy if number of snapshots exceeds retention setting

                $newSnap = New-PfaProtectionGroupSnapshot -Array $sourceFlashArray -ProtectionGroups ($srcReplGroup.name -split ':')[1] `
                -ReplicateNow -ApplyRetention
                
                if($newSnap){
                                    
                    # Wait for the snapshot to be replicated

                    while((($tgtReplGroup | Get-SpbmPointInTimeReplica).id -join ', ') -eq ($replSnapshots.id -join ', ')){
                        "$( (Get-Date).ToString() ) Waiting on new snapshot to be replicated to target array ...`n" | Write-Verbose
                        sleep 5
                    }                
                } else {
                    Confirm-Continue -Warning "$( (Get-Date).ToString() ) Unable to create new snapshot" `
                    -Prompt "`nContinue? [y/n]`n" -ScriptIfNo {"`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }

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
                        "`nThere is only one snapshot. Do you want replica to be created from $( get-date ($replSnapshots).CreationTime -Format 'dd/MM/yyyy - HH:mm:ss' ) snapshot? If no, function will exit[y/n]`n"
                        Confirm-Continue -Prompt $prompt `
                        -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                        -ScriptIfYes { $script:replSnapshot = $replSnapshots }

                        if($exit){ return }

                    } else {

                        # Set snapshot selection number

                        $n = 1

                        # Output snapshot selection menu to console host

                        "`n$( $SourceVm.Name ) snapshots:`n" | Write-Host
                        $replSnapshots | sort CreationTime -Descending | % {
                            "$n) $( get-date $_.CreationTime -Format 'dd/MM/yyyy - HH:mm:ss' )" | Write-Host
                            $n++
                        }

                        # Prompt for user selection of snapshot. Discard invalid input

                        while($replSnapshot -notin (1..($n-1))){
                            $replSnapshot = Read-Host -Prompt "`nEnter snapshot number (1-$( $n-1 )) to create replica from`n"
                            "" | Write-Host

                            # Warn on invalid input

                            if(!$replSnapshot -or ($replSnapshot -notin (1..($n-1)))){
                                "Invalid input, enter a number between 1 and $( $n-1 )" | Write-Warning
                            }
                        }

                        # Output confirmation of chosen snapshot

                        "Replica will be created from $( get-date ($replSnapshots | sort CreationTime -Descending)[$replSnapshot-1].CreationTime -Format 'dd/MM/yyyy - HH:mm:ss' ) snapshot`n" |
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

                    Confirm-Continue -Prompt "`nDo you want replica to be created from the most recent snapshot: $snapTime ? If no, function will exit [y/n]`n" `
                    -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true } `
                    -ScriptIfYes { $script:replSnapshot = $snap }

                    if($exit){ return }
                }

            # Throw error and exit if no snapshots have been replicated to target array
            
            } else { throw "`n$( (Get-Date).ToString() ) Unable to retrieve snapshots on target array`n" }

            # Shut down source VM if -ShutdownSourceVmFirst specified

            if($ShutdownSourceVmFirst){
                "`n$( (Get-Date).ToString() ) Shutting down $( $SourceVm.name ) ...`n" | Write-Host
                
                # If VM isn't powered off already, power it off
                
                if((Get-VM $SourceVm).PowerState -ne 'PoweredOff'){
                    
                    # Attempt guest OS shutdown process

                    Get-VM $SourceVm | Stop-VMGuest | Out-Null
                    if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
                    
                    # Create stopwatch to wait 60 seconds for guest OS shutdown                    

                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()                    

                    # While waiting for shutdown, check time on stopwatch

                    while(((Get-VM $SourceVm).PowerState -ne 'PoweredOff') -and $stopwatch.IsRunning){
                        "`n$( (Get-Date).ToString() ) Waiting on guest OS shutdown process to finish ...`n" | Write-Host
                        
                        # If VM not in powered off state after 60 seconds then confirm force power off
                        
                        if($stopwatch.Elapsed.TotalSeconds -ge 60){
                            "`n$( (Get-Date).ToString() ) It has been at least 60 seconds and $( $SourceVm.Name ) has not shut down. Confirm if you want to power off VM ...`n" | Write-Host
                            (Get-VM $SourceVm) | Stop-VM | Out-Null
                            if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

                            # Stop stopwatch once VM force powered off or not
                            
                            $stopwatch.Stop()
                        }
                        sleep 5
                    }

                    if((Get-VM $SourceVm).PowerState -ne 'PoweredOff'){
                        Confirm-Continue -Warning "$( (Get-Date).ToString() ) Failed to shut down/power off $( $SourceVm.name )" `
                        -Prompt "`nContinue? [y/n]`n" `
                        -ScriptIfNo { "`n$( (Get-Date).ToString() ) Exiting ...`n" | Write-Host; $script:exit = $true }

                        if($exit){ return }
                    }
                } else { "`n$( (Get-Date).ToString() ) $( $SourceVm.Name ) is already powered off`n" | Write-Host }
            }

            # Store VMs and disks in source Protection Group to re-apply storage policy to once source Protection Group has been recreated

            $sourceDisks = $srcReplGroup | Get-HardDisk
            $sourceVms = $srcReplGroup | Get-VM
            "`n$( (Get-Date).ToString() ) Starting failover ...`n" | Write-Host
            
            # Set state of target replication group to "FailedOver" and create vVols on target array. Store VM datastore path in $replicaVm for later registration 
            # Automatically create Protection Group on target array for replicating failed over vVols back to source array
            
            $replicaVm = Start-SpbmReplicationFailover -ReplicationGroup $tgtReplGroup -PointInTimeReplica $replSnapshot -Confirm:1
            if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

            # Get vmx file name of source and replica VM

            $vmx = (($SourceVm.ExtensionData.LayoutEx.File | ? Type -eq 'config').Name -split '/')[-1]
            
            # Use vmx to exclude other VMs in Protection Group that have also just been failed over

            $replicaVm = $replicaVM | ? { $_ -match $vmx }
            
            # Throw error and exit if no path for replica VM or unable to retrieve target array vVol datastore 
            
            if(!$replicaVm){
                throw "`n$( (Get-Date).ToString() ) Unable to failover $( $SourceVm.Name ) or find replicated config vVol. Check status of VASA providers and target vVol datastore`n"
            } else {                        
                
                # If replica VM is to be registered in inventory, continue to placement
                
                if($RegisterReplicaVm -or $StartReplicaVm -or $DestinationCluster -or $DestinationFolder){                                                                                     
                    if(!$DestinationCluster){
                        "$( (Get-Date).ToString() ) No destination cluster provided. Selecting first returned cluster that can access target datastore ...`n" | Write-Verbose
                        
                        # If no destination cluster then no portgroups specified and their availability does not need to be checked
                        # Select first returned cluster connected to target array vVol datastore
                        
                        $DestinationCluster = $tgtDatastore.Datacenter | Get-Cluster |
                        ? {($_ | Get-Datastore | select -ExpandProperty Name) -contains $tgtDatastore.Name} | select -First 1                                                
                    }
                    
                    # Skip VM registration if no clusters in destination datacenter connected to target vVol datastore

                    if(!$DestinationCluster){
                        "$( (Get-Date).ToString() ) Target datastore is not accessible by clusters in target datacenter. Skipping registration of $ReplicaName at path `"$replicaVm`" ...`n" |
                        Write-Warning
                    } else {
                        "`n$( (Get-Date).ToString() ) Destination cluster is $( $DestinationCluster.Name )`n" | Write-Host
                        
                        if(!$DestinationFolder){

                            # If no destination folder provided, try to use folder with same name as source VM folder but in destination datacenter

                            "$( (Get-Date).ToString() ) No destination folder provided. Selecting folder in target datacenter with same name as source folder ...`n" | Write-Verbose
                            $DestinationFolder = Get-Folder $SourceVm.folder.Name -Location $tgtDatastore.Datacenter
                            
                            # If same name folder as source VM doesn't exist, use 'Discovered virtual machine folder'
                            
                            if(!$DestinationFolder){
                                "$( (Get-Date).ToString() ) $( $SourceVm.folder.Name ) folder does not exist at target site. Using 'Discovered virtual machine' folder`n" | Write-Warning
                                $DestinationFolder = Get-Folder 'Discovered virtual machine' -Location $tgtDatastore.Datacenter
                            }                                        
                        }

                        "`n$( (Get-Date).ToString() ) Destination folder is $( $DestinationFolder.Name )`n" | Write-Host
                        
                        # Using previously stored datastore path $replicaVm, register the replica VM in the destination cluster and folder with name in $ReplicaName

                        "`n$( (Get-Date).ToString() ) Registering $ReplicaName ...`n" | Write-Host
                        $replicaVm = New-VM -Name $ReplicaName -VMFilePath $replicaVm -ResourcePool $DestinationCluster -Location $DestinationFolder -Confirm:1
                        if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }

                        # If registration successful, proceed to changing portgroups and guest network settings if necessary parameters provided
                        
                        if(Get-VM $replicaVm){
                            if($PSBoundParameters.ReplicaVmPortgroups){
                                "`n$( (Get-Date).ToString() ) Changing $ReplicaName portgroup(s) ...`n" | Write-Host 
                                
                                # If more portgroups were provided than network adapters on replica VM, set all network adapters to temporary portgroups  
                                
                                if($useTempPgs){
                                    $tempPg = $replicaVm | select -ExpandProperty VMHost | Get-VDSwitch -WarningAction SilentlyContinue |
                                    Get-VDPortgroup -Name *Temp* -WarningAction SilentlyContinue | select -First 1
                                    $replicaVm | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $tempPg -Confirm:0 | Out-Null

                                    if(((Get-VM $replicaVm | Get-NetworkAdapter).NetworkName | select -Unique) -ne $tempPg.Name){
                                        "$( (Get-Date).ToString() ) Unable to change network adapter portgroups to $( $tempPg.Name )`n" | Write-Warning
                                    }
                                } else {                                    
                                    $netAdapters = $replicaVm | Get-NetworkAdapter | sort Name
                                    
                                    # In name order, set each network adapter to provided portgroup based on index in -ReplicaVmPortgroups
                                    # E.g. 'Network adapter 1' -> index 0.
                                    
                                    for ($i = 0; $i -lt $netAdapters.count; $i++){
                                        
                                        # Check portgroup is accessible from automatically selected host of replica VM

                                        if(!($replicaVm | select -ExpandProperty VMHost | Get-VDSwitch -WarningAction SilentlyContinue |
                                        Get-VDPortgroup -Name $PSBoundParameters.ReplicaVmPortgroups[$i].Name -WarningAction SilentlyContinue -ErrorAction SilentlyContinue)){                                            
                                            "$( (Get-Date).ToString() ) $( $PSBoundParameters.ReplicaVmPortgroups[$i].Name ) is not accesible from host $( $replicaVm.VMHost.Name ) of $ReplicaName.`n" |
                                            Write-Warning
                                            $prompt += "Use temporary, untagged portgroup for $( $netAdapters[$i].Name )? [y/n]`n"
                                            $prompt += "(If 'n' then replica creation will continue without changing $( $netAdapters[$i].Name ) portgroup)`n"
                                            $confirm = Read-Host -Prompt $prompt
                                            
                                            while($confirm -notin @('y','n')){                                
                                            
                                                # Warn on invalid input
                    
                                                if(!$confirm -or ($confirm -notin @('y','n'))){
                                                    "Invalid input, enter y or n" | Write-Warning
                                                }
                                            }
                                            
                                            # Continue without changing portgroup if user enters 'n' to using temporary portgroup, else continue
                    
                                            if($confirm -eq 'y'){
                                                
                                                # If provided portgroup not available, use temporary portgroup

                                                $tempPg = $replicaVm | select -ExpandProperty VMHost | Get-VDSwitch -WarningAction SilentlyContinue |
                                                Get-VDPortgroup -Name *Temp* -WarningAction SilentlyContinue | select -First 1
                                                $netAdapters[$i] | Set-NetworkAdapter -Portgroup $tempPg -Confirm:0 | Out-Null

                                                if((Get-NetworkAdapter -Id $netAdapters[$i].Id).NetworkName -ne $tempPg.Name){
                                                    "$( (Get-Date).ToString() ) Unable to change $( $netAdapters[$i].Name ) portgroup to $( $tempPg.Name )`n" | Write-Warning
                                                }
                                            }
                                        } else {
                                            "`n$( (Get-Date).ToString() ) Changing portgroup of $( $netAdapters[$i].Name ) to $( $PSBoundParameters.ReplicaVmPortgroups[$i].Name ) ...`n" | Write-Host
                                            
                                            # Set network adapter to provided portgroup

                                            $netAdapters[$i] | Set-NetworkAdapter -Portgroup $PSBoundParameters.ReplicaVmPortgroups[$i] -Confirm:0 | Out-Null

                                            if((Get-NetworkAdapter -Id $netAdapters[$i].Id).NetworkName -ne $PSBoundParameters.ReplicaVmPortgroups[$i].Name){
                                                "$( (Get-Date).ToString() ) Failed to change $( $netAdapters[$i].Name ) portgroup to $( $PSBoundParameters.ReplicaVmPortgroups[$i].Name )`n" |
                                                Write-Warning
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if($StartReplicaVm){
                                "`n$( (Get-Date).ToString() ) Starting $ReplicaName ...`n" | Write-Host
                                $replicaVm | Start-VM | Out-Null
                                "`n$( (Get-Date).ToString() ) Waiting 120 seconds for $ReplicaName guest OS boot process to complete ...`n" | Write-Host
                                
                                # Answer 'I copied it' if asked if VM was moved or copied

                                if(Get-VMQuestion -VM $replicaVm){
                                    "`n$( (Get-Date).ToString() ) Answering VM question with 'I Copied It' ...`n" | Write-Host
                                    Get-VMQuestion -VM $replicaVm | Set-VMQuestion -Option 'button.uuid.copiedTheVM' -Confirm:0 | Out-Null
                                }
                                
                                # Wait 120 seconds for guest OS to boot
                                
                                sleep 120
                                
                                if($replicaVm.ExtensionData.Config.Tools.ToolsVersion){
                                    if($PSBoundParameters.ReplicaVmHostname){
        
                                        # Skip hostname change if local admin credential failed, or hostname is in wrong format
                                    
                                        if(!$skipHostname){
                                        
                                            # Check VMTools is installed/booted on replica VM as it's required for changing hostname

                                            "`n$( (Get-Date).ToString() ) Changing $ReplicaName hostname ...`n" | Write-Host        
                                                                                        
                                            if($PSBoundParameters.DomainJoinCredential){
                                            
                                                # Remove from domain if on domain

                                                $domain = (Invoke-VMScript -ScriptText 'Get-ComputerInfo | select -ExpandProperty CsDomain' -VM (Get-VM $replicaVm) `
                                                -GuestCredential $PSBoundParameters.LocalAdminCredential -ScriptType Powershell).ScriptOutput.Trim()

                                                $workgroup = (Invoke-VMScript -ScriptText 'Get-ComputerInfo | select -ExpandProperty CsWorkgroup' -VM (Get-VM $replicaVm) `
                                                -GuestCredential $PSBoundParameters.LocalAdminCredential -ScriptType Powershell).ScriptOutput.Trim()

                                                if($domain -and !$workgroup){

                                                    # Remove replica VM from domain

                                                    $st = "
                                                        `$pw = `"$( $PSBoundParameters.LocalAdminCredential.GetNetworkCredential().Password )`" | ConvertTo-SecureString -AsPlainText -Force
                                                        `$cred = [PSCredential]::new(`"$( $PSBoundParameters.LocalAdminCredential.Username )`", `$pw)
                                                        Remove-Computer -Credential `$cred -Restart -WorkgroupName 'WORKGROUP' -Force                                                        
                                                    "

                                                    $verbose = "$( (Get-Date).ToString() ) $ReplicaName is joined to a domain. Removing from domain to change hostname. It will be rejoined after"
                                                    $verbose += " remaining (if any) guest network changes have been completed ...`n"
                                                    $verbose | Write-Verbose

                                                    Invoke-VMScript -ScriptText $st -VM (Get-VM $replicaVm) -GuestCredential $PSBoundParameters.LocalAdminCredential -ScriptType Powershell `
                                                    -RunAsync | Out-Null

                                                    "$( (Get-Date).ToString() ) Waiting 120 seconds for $ReplicaName restart to finish ...`n" | Write-Verbose

                                                    # Wait for replica VM to restart

                                                    sleep 120

                                                    # Confirm removal from domain
                                                    
                                                    $output = Invoke-VMScript -ScriptText 'Get-ComputerInfo | select -ExpandProperty CsDomain' -VM (Get-VM $replicaVm) `
                                                    -GuestCredential $PSBoundParameters.LocalAdminCredential -ScriptType Powershell
                                                    
                                                    if((Get-VM $replicaVm).PowerState -eq 'PoweredOn'){
                                                        if($output){
                                                            if($output.ScriptOutput.Trim() -eq 'WORKGROUP'){
                                                                $rejoinDomain = $true
                                                                $changeHostname = $true
                                                            } else {
                                                                "$( (Get-Date).ToString() ) Unable to confirm $ReplicaName removal from domain. Skipping hostname change ...`n" | Write-Warning
                                                                "`n$( (Get-Date).ToString() ) VM script output:`n" | Write-Host -ForegroundColor Yellow
                                                                $output.ScriptOutput | Write-Host -ForegroundColor Yellow
                                                            }
                                                        } else {
                                                            "$( (Get-Date).ToString() ) Unable to invoke script via VMTools on $ReplicaName and so cannot confirm removal from domain. Skipping hostname change ...`n" |
                                                            Write-Warning
                                                        }
                                                    } else { "$( (Get-Date).ToString() ) $ReplicaName is not powered on. Unable to confirm removal from domain. Skipping hostname change ...`n" | Write-Warning }
                                                } elseif(!$domain){
                                                    $warning = "$( (Get-Date).ToString() ) Failed to get domain for $ReplicaName. If replica VM is not a member of a domain and hostname is to be changed"
                                                    $warning += " omit -DomainJoinCredential. Skipping hostname change ...`n"
                                                    $warning | Write-Warning
                                                } elseif($workgroup){
                                                    "$( (Get-Date).ToString() ) $ReplicaName is not a member of a domain. Omit -DomainJoinCredential to change hostname. Skipping hostname change ..." | Write-Warning
                                                }
                                            } else { $changeHostname = $true }
                                
                                            if($changeHostname){

                                                # Change hostname and reboot

                                                $st = "
                                                    Rename-Computer -NewName `"$( $PSBoundParameters.ReplicaVmHostname )`" -Restart -Confirm:0
                                                "
                                                
                                                "$( (Get-Date).ToString() ) Changing $ReplicaVm VM hostname to $( $PSBoundParameters.ReplicaVmHostname ) and restarting ...`n" | Write-Verbose

                                                Invoke-VMScript -ScriptText $st -VM (Get-VM $replicaVm) -GuestCredential $PSBoundParameters.LocalAdminCredential -ScriptType Powershell `
                                                -RunAsync | Out-Null

                                                "$( (Get-Date).ToString() ) Waiting 120 seconds for $ReplicaName restart to finish ...`n" | Write-Verbose

                                                sleep 120
                                                
                                                if((Get-VM $replicaVm).PowerState -eq 'PoweredOn'){
                                                    
                                                    # Run script on VM to check hostname
                                        
                                                    $output = Invoke-VMScript -ScriptText 'hostname' -VM (Get-VM $replicaVm) -GuestCredential $PSBoundParameters.LocalAdminCredential `
                                                    -ScriptType Powershell
                                                    
                                                    if($output){
                                                        if($output.ScriptOutput.Trim() -ne $PSBoundParameters.ReplicaVmHostname){
                                                            "$( (Get-Date).ToString() ) Unable to confirm hostname change`n" | Write-Warning
                                                            "`n$( (Get-Date).ToString() ) VM script output:`n" | Write-Host -ForegroundColor Yellow
                                                            $output.ScriptOutput | Write-Host -ForegroundColor Yellow
                                                        } else { "`n$( (Get-Date).ToString() ) Hostname changed successfully`n" | Write-Host }
                                                    } else { "$( (Get-Date).ToString() ) Unable to invoke script via VMTools on $ReplicaName and so cannot confirm hostname change`n" | Write-Warning }
                                                } else { "$( (Get-Date).ToString() ) $ReplicaName is not powered on. Unable to confirm hostname change`n" | Write-Warning }
                                            }
                                        } else { "$( (Get-Date).ToString() ) Skipping hostname change ...`n" | Write-Warning }
                                    }

                                    if($PSBoundParameters.ReplicaVmIpDetails){
        
                                        # Skip re-IPing if local admin credential failed, more settings groups than network adapters were provided or not all IP settings groups in correct format

                                        if(!$skipReIp){
                                        
                                            # Check VMTools is installed/booted on replica VM as it's required for re-IPing

                                            "`n$( (Get-Date).ToString() ) Changing $ReplicaName IP(s) ...`n" | Write-Host                                            
                                            $netAdapters = $replicaVm | Get-NetworkAdapter
                                            
                                            # For each network adapter and corresponding IP settings group: parse IP, Subnet Mask, and Default Gateway (if included) then apply to VM via PS script
                                            
                                            if($netAdapters){
                                                for ($i = 0; $i -lt $netAdapters.count; $i++){
                                                    
                                                    # $ipDetailsArray stores IP, Subnet Mask, and Default Gateway (if included) as items

                                                    $ipDetailsArray = $PSBoundParameters.ReplicaVmIpDetails[$i] -split ',' | % { $_.Trim() }                                                
                                                    
                                                    # MAC address segments separated by '-' in Windows and ':' in vCenter. Replace ':' to find corresponding interfaces in guest 
                                                    
                                                    $mac = $netAdapters[$i].MacAddress -replace ':','-'
                                                    
                                                    # Convert Subnet Mask to prefix length

                                                    $prefixLength = 0

                                                    $ipDetailsArray[1] -split '\.' | % {
                                                        while(0 -ne $_){
                                                            $_ = ($_ -shl 1) -band [byte]::MaxValue
                                                            $prefixLength++
                                                        }
                                                    }
                                                    
                                                    # If 3rd item is included, set it as new Default Gateway in guest and change IP of current interface. Else, only change IP of current interface
                                                    
                                                    if($ipDetailsArray.count -eq 3){   
                                                        "`n$( (Get-Date).ToString() ) Changing default gateway to $( $ipDetailsArray[2] ) ...`n" | Write-Host
                                                        $st = "
                                                            Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Remove-NetRoute -Confirm:0 | Out-Null
                                                            Get-NetAdapter | ? MacAddress -eq '$mac' | Get-NetIPAddress -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:0 | Out-Null
                                                            Get-NetAdapter | ? MacAddress -eq '$mac' | 
                                                            New-NetIPAddress -AddressFamily IPv4 -IPAddress '$( $ipDetailsArray[0] )' -PrefixLength '$( $prefixLength )' -DefaultGateway '$( $ipDetailsArray[2] )'
                                                            Get-NetRoute -DestinationPrefix 0.0.0.0/0 
                                                        "
                                                    } else {                                                                                        
                                                        $st = "
                                                            Get-NetAdapter | ? MacAddress -eq '$mac' | Get-NetIPAddress -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:0 | Out-Null
                                                            Get-NetAdapter | ? MacAddress -eq '$mac' | 
                                                            New-NetIPAddress -AddressFamily IPv4 -IPAddress '$( $ipDetailsArray[0] )' -PrefixLength '$( $prefixLength )'
                                                        "
                                                    }                                                              
                                                    
                                                    "`n$( (Get-Date).ToString() ) Changing IP of $( $netAdapters[$i].Name ) ($mac) to $( $ipDetailsArray[0] )/$prefixLength ...`n" | Write-Host
                                                    
                                                    # Run script on VM to change IP and Default Gateway (if included)

                                                    $output = Invoke-VMScript -ScriptText $st -VM (Get-VM $replicaVm) -GuestCredential $PSBoundParameters.LocalAdminCredential -ScriptType Powershell                                                                                        
                                                    
                                                    # Check output to confirm Default Gateway change

                                                    if($output){
                                                        if($ipDetailsArray.count -eq 3){
                                                            if((($output.ScriptOutput -split "`n") | ? {$_ -like "*NextHop*:*"} | select -first 1) -notmatch $ipDetailsArray[2]){
                                                                "$( (Get-Date).ToString() ) Unable to confirm change of default gateway to $( $ipDetailsArray[2] )`n" | Write-Warning
                                                                "`n$( (Get-Date).ToString() ) VM script output:`n" | Write-Host -ForegroundColor Yellow
                                                                $output.ScriptOutput | Write-Host -ForegroundColor Yellow                                                            
                                                            } else {
                                                                "`n$( (Get-Date).ToString() ) New default gateway - $( $ipDetailsArray[2] ) - applied successfully`n" | Write-Host
                                                            }
                                                        }
                                                        
                                                        # Check output to confirm IP change
                                                        
                                                        if((($output.ScriptOutput -split "`n") | ? {$_ -like "*IPAddress*:*"} | select -first 1) -notmatch $ipDetailsArray[0]){
                                                            "$( (Get-Date).ToString() ) Unable to confirm change of IP - $( $ipDetailsArray[0] ) - for $( $netAdapters[$i].Name )`n" | Write-Warning
                                                            "`n$( (Get-Date).ToString() ) VM script output:`n" | Write-Host -ForegroundColor Yellow
                                                            $output.ScriptOutput | Write-Host -ForegroundColor Yellow                                                        
                                                        } else {
                                                            "`n$( (Get-Date).ToString() ) New IP - $( $ipDetailsArray[0] ) - applied successfully to $( $netAdapters[$i].Name )`n" | Write-Host
                                                        }
                                                    } else { "$( (Get-Date).ToString() ) Unable to invoke script via VMTools on $ReplicaName and so cannot confirm IP or default gateway changes`n" | Write-Warning }
                                                }
                                            } else { "$( (Get-Date).ToString() ) Unable to retrieve $ReplicaName network adapters. Skipping re-IPing ...`n" | Write-Warning }
                                        } else { "$( (Get-Date).ToString() ) Skipping re-IPing ...`n" | Write-Warning }
                                    }

                                    if($PSBoundParameters.ReplicaVmDnsServers){
        
                                        # Skip DNS server change if local admin credential failed, more than two servers provided or IPs are not in correct format
                                    
                                        if(!$skipDns){
                                        
                                            # Check VMTools is installed/booted on replica VM as it's required for changing DNS
                                    
                                            "`n$( (Get-Date).ToString() ) Changing $ReplicaName DNS servers ...`n" | Write-Host
                                            $netAdapters = $replicaVm | Get-NetworkAdapter | sort Name
                                
                                            if($netAdapters){
                                
                                                # MAC address segments separated by '-' in Windows and ':' in vCenter. Replace ':' to find corresponding interfaces in guest 
                                
                                                $mac = $netAdapters[0].MacAddress -replace ':','-'            
                                                
                                                $st = "
                                                    Get-NetAdapter | ? MacAddress -eq '$mac' | Get-DnsClientServerAddress -AddressFamily IPv4 |
                                                    Set-DnsClientServerAddress -ServerAddresses $( $PSBoundParameters.ReplicaVmDnsServers -join ',' )
                                                    (Get-NetAdapter | ? MacAddress -eq '$mac' | Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses -join ','
                                                "
                                                
                                                # Run script on VM to change DNS servers
                                
                                                $output = Invoke-VMScript -ScriptText $st -VM (Get-VM $replicaVm) -GuestCredential $PSBoundParameters.LocalAdminCredential `
                                                -ScriptType Powershell                                                                                        
                                                
                                                # Check output to confirm change
                                                
                                                if($output){
                                                    if($output.ScriptOutput.Trim() -ne ($PSBoundParameters.ReplicaVmDnsServers -join ',')){
                                                        "$( (Get-Date).ToString() ) Unable to confirm change of DNS servers to $( $PSBoundParameters.ReplicaVmDnsServers -join ', ' )`n" | Write-Warning
                                                        "`n$( (Get-Date).ToString() ) VM script output:`n" | Write-Host -ForegroundColor Yellow
                                                        $output.ScriptOutput | Write-Host -ForegroundColor Yellow
                                                    } else {
                                                        "`n$( (Get-Date).ToString() ) New DNS servers - $( $PSBoundParameters.ReplicaVmDnsServers -join ', ' ) - applied successfully`n" | Write-Host
                                                    }
                                                } else { "$( (Get-Date).ToString() ) Unable to invoke script via VMTools on $ReplicaName and so cannot confirm DNS server(s) change`n" | Write-Warning }                                                
                                            } else { "$( (Get-Date).ToString() ) Unable to retrieve $ReplicaName network adapters. Skipping DNS server change ...`n" | Write-Warning }        
                                        } else { "$( (Get-Date).ToString() ) Skipping DNS server change ...`n" | Write-Warning }
                                    }

                                    if($rejoinDomain){
                                    
                                        # Add replica VM to domain it was previously a member of

                                        $st = "
                                            `$pw = `"$( $PSBoundParameters.DomainJoinCredential.GetNetworkCredential().Password )`" | ConvertTo-SecureString -AsPlainText -Force
                                            `$cred = [PSCredential]::new(`"$( $PSBoundParameters.DomainJoinCredential.Username )`", `$pw)
                                            Add-Computer -Credential `$cred -DomainName `"$domain`" -Restart -Force                                                        
                                        "

                                        "$( (Get-Date).ToString() ) Re-adding $ReplicaName to $domain ...`n" | Write-Verbose

                                        Invoke-VMScript -ScriptText $st -VM (Get-VM $replicaVm) -GuestCredential $PSBoundParameters.LocalAdminCredential `
                                        -ScriptType Powershell -RunAsync | Out-Null

                                        "$( (Get-Date).ToString() ) Waiting 120 seconds for $ReplicaName restart to finish ...`n" | Write-Verbose

                                        # Wait for replica VM to restart

                                        sleep 120

                                        $output = Invoke-VMScript -ScriptText 'Get-ComputerInfo | select -ExpandProperty CsDomain' -VM (Get-VM $replicaVm) `
                                        -GuestCredential $PSBoundParameters.LocalAdminCredential -ScriptType Powershell
                                    
                                        if((Get-VM $replicaVm).PowerState -eq 'PoweredOn'){
                                            if($output){
                                                if($output.ScriptOutput.Trim() -eq $domain){
                                                    "$( (Get-Date).ToString() ) $ReplicaName successfully joined to domain`n" | Write-Verbose
                                                } else {
                                                    "$( (Get-Date).ToString() ) Unable to confirm domain join for $ReplicaName (removed and re-added to change hostname)`n" | Write-Warning
                                                    "$( (Get-Date).ToString() ) VM script output:`n" | Write-Verbose
                                                    $output.ScriptOutput | Write-Verbose
                                                }
                                            } else {
                                                "$( (Get-Date).ToString() ) Unable to invoke script via VMTools on $ReplicaName and so cannot confirm domain join (removed and re-added to change hostname)`n" |
                                                Write-Warning
                                            }                                            
                                        } else { "$( (Get-Date).ToString() ) $ReplicaName is not powered on. Unable to confirm domain join (removed and re-added to change hostname)`n" | Write-Warning }

                                    }
                                } else { "$( (Get-Date).ToString() ) $ReplicaName does not have VMTools installed or running. Skipping guest network changes ...`n" | Write-Warning } 
                            }                     
                        } else { "$( (Get-Date).ToString() ) Unable to register $ReplicaName. Check datastore path: $replicaVm`n" | Write-Warning }
                    }
                }
            }
            
            # If -RemoveSourceVm or -RemoveSourceVmPermanently are provided, check VM is powered off then remove it

            if($RemoveSourceVm -or $RemoveSourceVmPermanently){
                "$( (Get-Date).ToString() ) Shutting down $( $SourceVm.name ) ...`n" | Write-Verbose

                # Same procedure for shutdown as before

                if((Get-VM $SourceVm).PowerState -ne 'PoweredOff'){
                    Get-VM $SourceVm | Stop-VMGuest | Out-Null
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                    while((Get-VM $SourceVm).PowerState -ne 'PoweredOff'){
                        "$( (Get-Date).ToString() ) Waiting on guest OS shutdown process to finish ...`n" | Write-Verbose
                        if($stopwatch.Elapsed.Seconds -ge 60){
                            "`n$( (Get-Date).ToString() ) It has been at least 60 seconds and $( $SourceVm.Name ) has not shut down. Confirm if you want to power off VM ...`n" | Write-Host
                            Get-VM $SourceVm | Stop-VM | Out-Null
                            if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }                            
                            $stopwatch.Stop()
                        }
                        sleep 5
                    }

                    if((Get-VM $SourceVm).PowerState -ne 'PoweredOff'){
                        "$( (Get-Date).ToString() ) Failed to shut down/power off $( $SourceVm.name )`n" | Write-Warning
                    }
                } else { "$( (Get-Date).ToString() ) $( $SourceVm.Name ) is already powered off`n" | Write-Verbose }
                
                # If VM is powered off, proceed to removal. Else, leave VM as is
                
                if((Get-VM $SourceVm).PowerState -eq 'PoweredOff'){
                    if($RemoveSourceVmPermanently){
                        "`n$( (Get-Date).ToString() ) Deleting $( $SourceVm.name ) from disk ...`n" | Write-Host
                        
                        # Delete VM from disk. Prompt for confirmation
                        
                        Get-VM $SourceVm | Remove-VM -DeletePermanently
                        if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
                    } else {
                        "`n$( (Get-Date).ToString() ) Removing $( $SourceVm.name ) from inventory ...`n" | Write-Host
                        
                        # Remove VM from inventory. Prompt for confirmation

                        Get-VM $SourceVm | Remove-VM
                        if($VerbosePreference -eq 'SilentlyContinue'){ "" | Write-Host }
                    }

                    if(Get-VM $SourceVm -ErrorAction SilentlyContinue){
                        "$( (Get-Date).ToString() ) Failed to remove $( $SourceVm.name ).`n" | Write-Warning   
                    }
                } else { "$( (Get-Date).ToString() ) Failed to shut down/power off $( $SourceVm.name ). Skipping removal ...`n" | Write-Warning }
            }   
            
            "`n$( (Get-Date).ToString() ) Reversing replication ...`n" | Write-Host

            # Change state of target replication group from "FailedOver" to "Source"
            # Enable replication on automatically created reverse replication Protection Group

            Start-SpbmReplicationReverse -ReplicationGroup $tgtReplGroup | Out-Null
            
            "$( (Get-Date).ToString() ) Creating new source Protection Group on $( $srcReplGroup.FaultDomain.Name ) (original used for failover can no longer be referenced by SPBM) ...`n" |
            Write-Verbose

            # Get original source Protection Group
            
            $sourcePgName = $srcReplGroup.Name -replace "$( $srcReplGroup.FaultDomain.Name ):"
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

                    "$( (Get-Date).ToString() ) Creating new source Protection Group $sourcePgName ...`n" | Write-Verbose

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

                            $newSrcReplGroup = Get-SpbmReplicationGroup -Name "$( $srcReplGroup.FaultDomain.Name ):$sourcePgName"

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
                                $warning = "$( (Get-Date).ToString() ) Unable to remove renamed original source Protection Group $newName as it still has volumes."
                                $warning += " Manually move its volumes to the new source Protection Group by re-applying the corresponding storage policy to parent VMs`n"
                                $warning | Write-Warning
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

            "$( (Get-Date).ToString() ) Removing unregistered vVols on target array that were in the same Protection Group - $( $srcReplGroup.Name ) - as $( $SourceVm.Name ) ...`n" | Write-Verbose
                    
            # Get vVol for replica VM home (vmx file, logs etc.) - known as config vVol

            # If VM registered, use VM object property to find config vVol

            if(Get-VM $replicaVm -ErrorAction SilentlyContinue){
                $configVvol = Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray `
                -VvolUuid $replicaVm.ExtensionData.Config.VmStorageObjectId
            } else {
                
                # If VM not registered, use vmx path (in $replicaVm) to find config vVol                

                $configVvol = Get-PfaVolumeNameFromVvolUuid -FlashArray $targetFlashArray `
                -VvolUuid (($replicaVm -split ' ')[1] -split '/')[0]
            }

            if($configVvol){
                
                # Use config vVol to get automatically created reverse replication Protection Group
                
                $pGroup = Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $configVvol
                
                if($pGroup){                    

                    # Get vVols in the Protection Group not belonging to replica VM. Such vVols are ones belonging to VMs that were in the same Protection Group
                    # as the source VM at the time of failover. Failover operation is Protection Group scoped meaning unwanted vVols may be created on the target
                    # array that have to be removed  
                    
                    $unregisteredVols = (Get-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group).volumes | ? {$_ -ne $configVvol}                    

                    $replicaVmVolGroupVols = (Get-PfaVolumeGroup -Array $targetFlashArray -Name ($configVvol -split '/')[0]).volumes

                    $unregisteredVols = $unregisteredVols | ? {$_ -notin $replicaVmVolGroupVols}

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
                                
                                if(!(Compare (Get-PfaVolumes -Array $TargetFlashArray).name $unregisteredVols -IncludeEqual | ? SideIndicator -eq '==')){
                                    
                                    # Remove unwanted vVols volume groups
                                    
                                    $unregisteredVols | % { ($_ -split '/')[0] } | select -Unique | % {
                                        Remove-PfaVolumeGroup -Name $_ -Array $targetFlashArray | Out-Null
                                        Remove-PfaVolumeGroup -Name $_ -Array $targetFlashArray -Eradicate | Out-Null
                                    }
                                    
                                    # Check volume groups successfully removed
                                    
                                    if($unregisteredVols | % { ($_ -split '/')[0] } | select -Unique | % {
                                        Get-PfaVolumeGroup -Array $TargetFlashArray -Name $_ -ErrorAction SilentlyContinue
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
                            
                    # Create storage policy for replica VM Protection Group if policy with same Protection Group requirement doesn't already exist            

                    $sp = Get-SpbmStoragePolicy |
                    ? {($_.AnyOfRuleSets.AllOfRules |? {$_.Capability.Name -eq 'com.purestorage.storage.replication.ReplicationConsistencyGroup'}).Value -eq $pGroupName}
                    
                    if(!$sp){
                        "$( (Get-Date).ToString() ) Creating storage policy for Protection Group $pGroupName on $( $tgtReplGroup.FaultDomain.Name ) ...`n" | Write-Verbose
                        
                        $spName = "[vVol]$pGroupName"

                        # Create rule that adds VM to which policy is applied to target Protection Group
                        
                        $rule1 = New-SpbmRule -Capability 'com.purestorage.storage.replication.ReplicationConsistencyGroup' -Value $pGroupName
                        
                        # Create rule requiring VM to be stored on Pure Storage FlashArray
                        
                        $rule2 = New-SpbmRule -Capability 'com.purestorage.storage.policy.PureFlashArray' -Value $true
                        
                        # Add rules to ruleset and create storage policy

                        $ruleset = New-SpbmRuleSet -AllOfRules $rule1,$rule2
                        $sp = New-SpbmStoragePolicy -Name $spName -AnyOfRuleSets $ruleset
                    }                                        
                    
                    if(Get-VM $replicaVm -ErrorAction SilentlyContinue){

                        # Get SPBM object for replica VM Protection Group and policy
                    
                        $replGroup = Get-SpbmReplicationGroup | ? name -eq "$( $tgtReplGroup.FaultDomain.Name ):$pGroupName"

                        if($sp -and $replGroup){
                            
                            "$( (Get-Date).ToString() ) Assigning storage policy to $ReplicaName VM home ...`n" | Write-Verbose

                            # Apply policy and Protection Group to replica VM
                            
                            $replicaVm | Get-SpbmEntityConfiguration |
                            Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $replGroup | Out-Null                
                            
                            # Confirm storage policy has been applied
                            
                            if(($replicaVm | Get-SpbmEntityConfiguration).StoragePolicy -ne $sp){
                                "$( (Get-Date).ToString() ) Failed to assign storage policy $( $sp.Name ) to $ReplicaName`n" | Write-Warning 
                            }

                            "$( (Get-Date).ToString() ) Assigning storage policy to $ReplicaName disks ...`n" | Write-Verbose

                            # Apply policy and Protection Group to replica VM disks
                            
                            $replicaVm | Get-HardDisk | Get-SpbmEntityConfiguration |
                            Set-SpbmEntityConfiguration -StoragePolicy $sp -ReplicationGroup $replGroup | Out-Null                                

                            if((($replicaVm | Get-HardDisk | Get-SpbmEntityConfiguration).StoragePolicy | select -Unique) -ne $sp){
                                "$( (Get-Date).ToString() ) Failed to assign storage policy $( $sp.Name ) to $ReplicaName disks`n" | Write-Warning 
                            }                            
                        } else {
                            $warning = "$( (Get-Date).ToString() ) Unable to get storage policy and/or SPBM object for Protection Group $( $tgtReplGroup.FaultDomain.Name ):$pGroupName."
                            $warning += " Skipping application of storage policy to replica VM ...`n"
                            $warning | Write-Warning
                        }
                    
                    # Move replica VM vVols to existing Protection Group with same settings as auto-created one if it exists

                    } elseif($moveVols){

                        "$( (Get-Date).ToString() ) Moving replica vVols to $pGroupName`n" | Write-Verbose
                    
                        $replicaVmVolGroupVols = ($replicaVmVolGroupVols | ? {$_ -notmatch 'Swap'})
                        
                        # Remove replica VM vVols from auto-created Protection Group

                        Remove-PfaVolumesFromProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group -VolumesToRemove $replicaVmVolGroupVols | Out-Null

                        # Check vVols have been removed

                        if(!($replicaVmVolGroupVols | % { Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $_ -ErrorAction SilentlyContinue })){

                            # Add vVols to existing Protection Group with same settings

                            Add-PfaVolumesToProtectionGroup -Array $targetFlashArray -Name $pGroupName -VolumesToAdd $replicaVmVolGroupVols | Out-Null

                            if(($replicaVmVolGroupVols | % { Get-PfaVolumeProtectionGroups -Array $targetFlashArray -VolumeName $_ -ErrorAction SilentlyContinue } |
                            select -ExpandProperty protection_group -Unique) -eq $pGroupName){
                                "$( (Get-Date).ToString() ) Replica vVols successfully moved to $pGroupName`n" | Write-Verbose
                            } else { "$( (Get-Date).ToString() ) Unable to confirm move of replica VM vVols to $pGroupName`n" | Write-Warning }
                        } else { "$( (Get-Date).ToString() ) Unable to confirm removal of replica VM vVols from $( $pGroup.protection_group ). Skipping move to $pGroupName ...`n" | Write-Warning }                        
                    }

                    if($moveVols){
                        if(!(Get-PfaProtectionGroup -Array $targetFlashArray -Name $pGroup.protection_group).volumes){
                            $verbose = "$( (Get-Date).ToString() ) Replica vVols have been moved to existing Protection Group with same name as"
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

                    "$( (Get-Date).ToString() ) Creating new snapshot for target Protection Group $pGroupName to be replicated to $( $srcReplGroup.FaultDomain.Name ) ...`n" | Write-Verbose

                    # Take snapshot for target Protection Group and replicate. Apply retention policy if number of snapshots exceeds retention setting

                    New-PfaProtectionGroupSnapshot -Array $targetFlashArray -ProtectionGroups $pGroupName -ReplicateNow -ApplyRetention | Out-Null
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

            if(Get-VM $replicaVm -ErrorAction SilentlyContinue){ Get-VM $replicaVm } else { $replicaVm }
        } catch {            
            $Error[0] | Write-Error
            "`n$( (Get-Date).ToString() ) A terminating error occurred`n" | Write-Error
        } finally {
            
            # Remove script scoped variables to prevent interference with repeat use of function in same shell context
            
            $scriptVars = 'exit', 'reshutdown', 'skipCredTest', 'skipReIp', 'skipDns', 'skipHostname', 'DestinationFolder', 'useTempPgs', 'replSnapshots',
            'replSnapshot', 'snap', 'newAutoGroupName', 'moveVols', 'pGroupName'
            
            Get-Variable -Name $scriptVars -Scope Script -ErrorAction SilentlyContinue | Remove-Variable -Scope Script -ErrorAction SilentlyContinue                
        }
    }
}