###################################
### Get-VMRackFaultDomainReport ###           
### lewis.connolly@zonal.co.uk  ###       
###################################

# Return report of VMs and server rack fault domain tags

function Get-VMRackFaultDomainReport {    
    
    param (
        [parameter()]
        [string]$Server = 'vcenter',
        [parameter()]
        [string]$Protocol = 'https',
        [parameter()]
        [string]$Datacenter = 'DCA'
    )

    Import-Module VMware.PowerCLI | Out-Null

    # Connect to server and get all VM's
    Connect-VIServer -Server $Server -Protocol $Protocol | Out-Null
     
    # Get fault domain tag assignments, compute clusters and VVOL datastores and datastore clusters up front for quicker processing of VMs later
    $fdTagAssignments = Get-TagAssignment -Category FaultDomain | select @{n='TagName';e={$_.Tag.Name}},@{n='EntityName';e={$_.Entity.Name}}
    $computeClusters = Get-Cluster -Location $Datacenter | % {
        $cluster = $_ 
        $cluster | Get-VMHost | select name,@{n='ClusterName';e={$cluster.Name}}
    }
    $dsInCluster = Get-DatastoreCluster -Location $Datacenter | % {
        $cluster = $_ 
        $cluster | Get-Datastore | select name,@{n='ClusterName';e={$cluster.Name}},Id
    }
    $ds = Get-Datastore -Location $Datacenter | select name,Id

    # For every VM in the chosen datacentre get the fault domain tags of their compute clusters and datastores/datastore clusters     
    Get-VM -Location $Datacenter | select Name,VMHost,
    @{n='Cluster';e={
        $vmhostName = $_.vmhost.name
        ($computeClusters | ? Name -eq $vmhostName).ClusterName
    }},
    @{n='ComputeFaultDomain';e={
        $vmhostName = $_.vmhost.name
        $hostTag = ($fdTagAssignments | ? EntityName -eq $vmhostName).TagName
        #$clusterTag = ($fdTagAssignments | ? EntityName -eq ($computeClusters | ? Name -eq $vmhostName).ClusterName).TagName
        if($hostTag){$hostTag}else{'No cluster fault domain tags found'}
    }},
    @{n='Datastore(s)';e={
        $dsIds = $_.DatastoreIdList
        (($ds | ? Id -in $dsIds).Name | sort) -join '<br>'
    }},
    @{n='DatastoreCluster(s)';e={
        $dsIds = $_.DatastoreIdList
        ($ds | ? Id -in $dsIds | sort Name | % {            
            if($_.Name -notin $dsInCluster.Name){            
                'N/A'
            } else {
                $dsName = $_.Name
                ($dsInCluster | ? Name -eq $dsName).ClusterName
            }
        }) -join '<br>'
    }},
    @{n='StorageFaultDomain';e={
        $dsIds = $_.DatastoreIdList
        $dsTags = $ds | ? Id -in $dsIds | sort Name | % {
            $dsName = $_.Name
            if($_.Name -notin $dsInCluster.Name){            
                ($fdTagAssignments | ? EntityName -eq ($ds | ? Name -eq $dsName).Name).TagName
            } else {
                ($fdTagAssignments | ? EntityName -eq ($dsInCluster | ? Name -eq $dsName).ClusterName).TagName 
            }
        } | Select -Unique
        if($dsTags){$dsTags -join '<br>'}else{'No datastore or datastore cluster fault domain tags found'}
    }} |
    # Set status to 'Warning' if VM is in different fault domains for compute and storage then sort by status
    select @{n='Status';e={
        if($_.ComputeFaultDomain -ne $_.StorageFaultDomain){'Warning'}else{'OK'}
    }}, * |
    sort @{e='Status';d='True'},Name,VMHost

    Disconnect-VIServer -Confirm:$false | Out-Null
}

Import-Module C:\zts\scripts\ReportFramework\ReportFramework.psm1

Get-VMRackFaultDomainReport | ConvertTo-HtmlReport `
    -ReportTitle "VM Rack Fault Domain - DCA" `
    -ReportDescription `
    "Warning = VM's compute and storage entities are in different server racks" `
    -FilePath "C:\inetpub\Html Reports\vmrackfaultdomaindca.html" `
    -VirtualPath "reports"

New-HtmlReportIndex `
    -ReportPath "C:\inetpub\Html Reports" |
ConvertTo-HtmlReport `
    -ReportTitle " Report Index" `
    -ReportDescription "Index of all Reports" `
    -FilePath "C:\inetpub\wwwroot\index.html" `
    -VirtualPath "/"