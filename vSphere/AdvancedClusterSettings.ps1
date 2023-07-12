# balance on memory consumed

$ZLABcl | New-AdvancedSetting -Name PercentIdleMBInMemDemand -Value 100 -Type ClusterDRS

# config APD and PDL HA responses

$ClusterView = Get-View (Get-Cluster)

$ClusterConfigSpec = new-object VMware.Vim.ClusterConfigSpec
$ClusterDasConfigInfo = New-Object VMware.Vim.ClusterDasConfigInfo
$ClusterDasVmSettings = New-Object VMware.Vim.ClusterDasVmSettings
$ClusterVmComponentProtectionSettings = New-Object VMware.Vim.ClusterVmComponentProtectionSettings

$ClusterVmComponentProtectionSettings.VmStorageProtectionForAPD = 'warning'
$ClusterVmComponentProtectionSettings.VmStorageProtectionForPDL = 'warning'
$ClusterDasVmSettings.VmComponentProtectionSettings = $ClusterVmComponentProtectionSettings
$ClusterDasConfigInfo.DefaultVmSettings = $ClusterDasVmSettings
$ClusterConfigSpec.DasConfig = $ClusterDasConfigInfo

$ClusterView.ReconfigureCluster($ClusterConfigSpec,$true)

#set hb datastores to auto

$ClusterConfigSpec = New-Object VMware.Vim.ClusterConfigSpec
$ClusterDasConfigInfo = New-Object VMware.Vim.ClusterDasConfigInfo

$ClusterDasConfigInfo.HBDatastoreCandidatePolicy = "allFeasibleDs"
$ClusterConfigSpec.DasConfig = $ClusterDasConfigInfo
$ClusterView.ReconfigureCluster($ClusterConfigSpec,$true)

#set admission control to percent based
$ClusterConfigSpec = New-Object VMware.Vim.ClusterConfigSpec
$ClusterDasConfigInfo = New-Object VMware.Vim.ClusterDasConfigInfo

$ClusterDasConfigInfo.AdmissionControlEnabled = $false
$ClusterConfigSpec.DasConfig = $ClusterDasConfigInfo
$ClusterView.ReconfigureCluster($ClusterConfigSpec,$true)
