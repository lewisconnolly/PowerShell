$storMgr = Get-View StorageResourceManager

$saasVms = get-folder -Location DCA SaaS| gvm
$bigAztecSqls = get-folder -Location DCA Aztec | gvm |? name -match SQL
$VMsOver150 = get-folder -Location DCA | gvm | ? ProvisionedSpaceGB -ge 150
$coreSvcs = get-folder Veeam,Graylog,Mail,SteelApp,RabbitMQ,Network,F5,Domain,Monitoring -Location DCA | gvm
$hap = gvm -Location DCA *HAP*
$vcenter = gvm vcenter* -location DCA
$disableAutoSdrs = gvm ($saasVms+$bigAztecSqls+$VMsOver150+$coreSvcs+$hap+$vcenter) | select -Unique
$sdrsVmConfig = @()

$disableAutoSdrs | sort name | % {
    $curVm = $_
    #$pod = $_ | Get-DatastoreCluster
    #$sdrsSpec = New-Object VMware.Vim.StorageDrsConfigSpec 
    $sdrsVmConfig += $pod.ExtensionData.PodStorageDrsEntry.StorageDrsConfig.VmConfig |
                    ? {(get-view $_.VM | sel -ExpandProperty name) -eq $curVm.Name}
    <#
    if(($sdrsVmConfig.Enabled -ne 0) -or ($sdrsVmConfig.Enabled -eq $null))
    {
        #$curVM.name | out-file -Append .\disableSdrs.txt 
        
        $sdrsVmSpec = New-Object VMware.Vim.StorageDrsVmConfigSpec
        $sdrsVmSpec.Operation = "edit"
        $sdrsVmSpec.Info = New-Object VMware.Vim.StorageDrsVmConfigInfo
        $sdrsVmSpec.Info.Vm = $curVm.Id
        $sdrsVmSpec.Info.Enabled = $false
        $sdrsSpec.vmConfigSpec += $sdrsVmSpec

        $storMgr.ConfigureStorageDrsForPod($pod.ExtensionData.MoRef,$sdrsSpec,$true)
    }
    #>
}