function Set-HAClusterHostMonitoring ($Enabled,$Cluster) {
 
    try{
        if(!$cluster){$cluster = Get-Cluster}

        $spec = New-Object VMware.Vim.ClusterConfigSpec

        $spec.DasConfig = New-Object VMware.Vim.ClusterDasConfigInfo

        $spec.DasConfig.Enabled = $true

        if($Enabled){
            $spec.DasConfig.HostMonitoring = [VMware.Vim.ClusterDasConfigInfoServiceState]::enabled
            $cluster.ExtensionData.ReconfigureCluster($spec,$true)
        }elseif(!$Enabled){
            $spec.DasConfig.HostMonitoring = [VMware.Vim.ClusterDasConfigInfoServiceState]::disabled
            $cluster.ExtensionData.ReconfigureCluster($spec,$true)
        }else{Write-Warning 'Please specify true or false for Enabled parameter'}
    }
    catch{throw}
}


    