<#
.Synopsis
   Find VM with non-default CPU and Memory resource configuration
.DESCRIPTION
   Find VM with non-default CPU and Memory resource configuration and set to default if desired
.EXAMPLE
   Set all limits to default:

   Find-VMCustomResourceConfiguration -SetToDefault
.EXAMPLE
   Set limits for specific VMs

   Find-VMCustomResourceConfiguration -SetToDefault
#>
function Find-VMCustomSpec
{
    [CmdletBinding(DefaultParameterSetName='byVM')]
    [Alias()]
    Param
    (
        [Parameter(ParameterSetName='byCluster')]
        $Cluster,

        [Parameter(ParameterSetName='byVMHost')]
        $VMHost,

        [Parameter(ParameterSetName='byVM')]
        $VM,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]
        $ExcludeVM,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $SetToDefault,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $CpuSharesLevel,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $CpuReservationMhz,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $CpuLimitMhz,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $MemSharesLevel,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $MemReservationMB,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $MemLimitMB,
        
        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $DiskSharesLevel,
        

        [Parameter(ParameterSetName='byCluster')]
        [Parameter(ParameterSetName='byVMHost')]        
        [Parameter(ParameterSetName='byVM')]        
        [switch]
        $DiskLimitIOPerSecond
    )

    
    try{
        #Created normal shares object for comparison
        $NormalShares = New-Object VMware.VimAutomation.ViCore.Types.V1.SharesLevel
        $NormalShares.value__ = 3

        #Get VMs by passed in cluster, VMHost, or VM. If all absent, get all VMs.
        if($Cluster) {$VMs = Get-Cluster $Cluster | Get-VM}
        elseif ($VMHost) {$VMs = Get-VMHost $VMHost | Get-VM}
        elseif ($VM) {$VMs = Get-VM $VM}
        else {$VMs = Get-VM}
           
        #Filter out -ExcludeVM VMs
        if($ExcludeVM){
            foreach ($exVM in $ExcludeVM){
                $VMs = $VMs |? name -ne $exVM.name
            }
        }
        
        if ($CpuSharesLevel-or$CpuReservationMhz-or$CpuLimitMhz-or$MemSharesLevel-or
        $MemReservationMB-or$MemLimitMB-or$DiskSharesLevel-or$DiskLimitIOPerSecond){
            $NotSelected = $False
        }else{$NotSelected = $true}
        
        function Set-VMResConfDefault
        {
            [Alias()]
            Param
            (
                $ResConf,
                $VmResConf,
                $SelectedConf,
                $SetToDefault,
                    
                [AllowNull()]
                $DefaultVal
            )
            
            try{
                $newline = "`n"
                $ResConfState = "$($ResConf)State"
                $SB = "
                    Write-Host `$newline
                    Write-Host `"Setting $($VmResConf.name) $ResConf to default.`" -ForegroundColor Green
                    Write-Host `$newline
                        
                    if(`$ResConf -match 'DiskShares'){
                         
                        `$hds = Get-VM -Name $(($VmResConf).Name) | Get-HardDisk |
                        ? {(`$_.ExtensionData.Shares.level -ne 'normal') -or (`$_.ExtensionData.Shares.shares -ne '1000')}

                        Get-VM -Name $(($VmResConf).Name)| Get-VMResourceConfiguration |
                        Set-VMResourceConfiguration -Disk `$hds -$ResConf `$DefaultVal |
                        Out-Null

                        `$VmResConf.NumDiskShares = 1000
                    }elseif(`$ResConf -match 'DiskLimit'){
                         
                        `$hds = Get-VM -Name $(($VmResConf).Name) | Get-HardDisk |
                        ? {(`$_.ExtensionData.StorageIOAllocation.Limit -ne '-1')}

                        Get-VM -Name $(($VmResConf).Name)|Get-VMResourceConfiguration |
                        Set-VMResourceConfiguration -Disk `$hds -$ResConf `$DefaultVal |
                        Out-Null
                    }else {

                        Get-VM -Name $(($VmResConf).Name) | Get-VMResourceConfiguration | Set-VMResourceConfiguration -$ResConf `$DefaultVal |
                        Out-Null
                    }

                    if(`$DefaultVal-eq`$null){

                            `$DefaultVal = 'Unlimited'
                    }
                        
                    Add-Member -InputObject `$VmResConf -MemberType NoteProperty -Name $ResConfState -Value `"Was `$([string](`$VmResConf.$ResConf));Now `$DefaultVal`"

                    `$VmResConf.$ResConf = `$DefaultVal
                "
                $SB = [scriptblock]::Create($SB)
                
                if($SetToDefault-and($SelectedConf-or$NotSelected)){
                    Invoke-Command -ScriptBlock $SB
                }else{
                    if(!$VmResConf.HasCustom) {
                        Add-Member -InputObject $VmResConf -MemberType NoteProperty -Name 'HasCustom' -Value $true
                    }
                    Add-Member -InputObject $VmResConf -MemberType NoteProperty -Name $ResConfState -Value 'IsCustom'
                }
            }
            catch{throw}
        }
        
        $VMs | 
        % {
            $_ = $_ | select name,numcpu,memorymb,powerstate,vmhost,
            @{n='NumCpuShares';e={($_|Get-VMResourceConfiguration).NumCpuShares}},
            @{n='CpuReservationMhz';e={($_|Get-VMResourceConfiguration).CpuReservationMhz}},
            @{n='CpuLimitMhz';e={ #Convert -1 to unlimited
                $cpulim = ($_|Get-VMResourceConfiguration).CpuLimitMhz
                if($cpulim -eq -1){'Unlimited'}else{$cpulim}
            }},
            @{n='CpuSharesLevel';e={($_|Get-VMResourceConfiguration).CpuSharesLevel}},
            @{n='NumMemShares';e={($_|Get-VMResourceConfiguration).NumMemShares}},
            @{n='MemReservationMB';e={($_|Get-VMResourceConfiguration).MemReservationMB}},
            @{n='MemLimitMB';e={ #Convert -1 to unlimited
                $memlim = ($_|Get-VMResourceConfiguration).MemLimitMB
                if($memlim -eq -1){'Unlimited'}else{$memlim}
            }},
            @{n='MemSharesLevel';e={($_|Get-VMResourceConfiguration).MemSharesLevel}},
            @{n='NumDiskShares';e={($_| Get-VMResourceConfiguration).DiskResourceConfiguration.NumDiskShares}},
            @{n='DiskSharesLevel';e={($_| Get-VMResourceConfiguration).DiskResourceConfiguration.DiskSharesLevel}},
            @{n='DiskLimitIOPerSecond';
                e={ #Convert -1 to unlimited
                    $disklim = ($_| Get-VMResourceConfiguration).DiskResourceConfiguration.DiskLimitIOPerSecond
                    $disklimits = @()
                    $disklim | % {
                        if($_ -eq -1){
                            $_ = 'Unlimited'
                        }
                        $disklimits += $_
                    }
                    $disklimits
                }
            }

            switch ($_)
            {
        
                {($CpuSharesLevel-or$NotSelected)-and(($_.NumCpuShares -ne $_.NumCpu*1000)-or($_.CpuSharesLevel -ne $NormalShares))} {
                        
                    Set-VMResConfDefault -ResConf 'CpuSharesLevel' -VmResConf $_ -SelectedConf $CpuSharesLevel -SetToDefault $SetToDefault -DefaultVal 'Normal'
                }

                {($CpuReservationMhz-or$NotSelected)-and($_.CpuReservationMhz -ne 0)} {

                    Set-VMResConfDefault -ResConf 'CpuReservationMhz' -VmResConf $_ -SelectedConf $CpuReservationMhz -SetToDefault $SetToDefault -DefaultVal 0
                }

                {($CpuLimitMhz-or$NotSelected)-and($_.CpuLimitMhz -ne 'Unlimited')} {
            
                    Set-VMResConfDefault -ResConf 'CpuLimitMhz' -VmResConf $_ -SelectedConf $CpuLimitMhz -SetToDefault $SetToDefault -DefaultVal $null
                }

                {($MemSharesLevel-or$NotSelected)-and(($_.NumMemShares -ne $_.MemoryMB*10)-or($_.MemSharesLevel -ne $NormalShares))}  {
            
                    Set-VMResConfDefault -ResConf 'MemSharesLevel' -VmResConf $_ -SelectedConf $MemSharesLevel -SetToDefault $SetToDefault -DefaultVal 'Normal'
                }

                {($MemReservationMB-or$NotSelected)-and($_.MemReservationMB -ne 0)}  {
            
                    Set-VMResConfDefault -ResConf 'MemReservationMB' -VmResConf $_ -SelectedConf $MemReservationMB -SetToDefault $SetToDefault -DefaultVal 0
                }

                {($MemLimitMB-or$NotSelected)-and($_.MemLimitMB -ne 'Unlimited')}  {
            
                    Set-VMResConfDefault -ResConf 'MemLimitMB' -VmResConf $_ -SelectedConf $MemLimitMB -SetToDefault $SetToDefault -DefaultVal $null
                }

                {($DiskSharesLevel-or$NotSelected)-and(($_.NumDiskShares -notmatch 1000)-or($_.DiskSharesLevel -notmatch $NormalShares))}  {

                    Set-VMResConfDefault -ResConf 'DiskSharesLevel' -VmResConf $_ -SelectedConf $DiskSharesLevel -SetToDefault $SetToDefault -DefaultVal 'Normal'
                }

                {($DiskLimitIOPerSecond-or$NotSelected)-and($_.DiskLimitIOPerSecond -notmatch 'Unlimited')}  {
            
                    Set-VMResConfDefault -ResConf 'DiskLimitIOPerSecond' -VmResConf $_ -SelectedConf $DiskLimitIOPerSecond -SetToDefault $SetToDefault -DefaultVal -1
                }
    
                Default {Add-Member -InputObject $_ -MemberType NoteProperty -Name 'HasCustom' -Value $false}
            }
            $_
        }
    }
    catch {throw}
}
