$vmhost = gvh 'enter host'

# get current psp

$vmhost | % {
    $esxcli = Get-EsxCli -VMHost $_ -V2
    $limittypes = @()
    gds dca-ssd-pure* | % {
        $dname = $_.ExtensionData.info.vmfs.extent.diskname
        $limittypes+=($esxcli.storage.nmp.psp.roundrobin.deviceconfig.get.Invoke(@{device =$dname })).limittype
    } 
    $_|sel name,@{n='PSPtypes';e={($limittypes | sel -Unique) -join ', '}}
}


# add and set satp rule

$esxcli_args = @{
 satp = "VMW_SATP_ALUA";
 vendor = "PURE";
 model = "FlashArray";
 psp = "VMW_PSP_RR";
 pspoption = "policy=latency";
 description = "FlashArray SATP Rule"
}

$vmhost | % {

 $esxcli = Get-EsxCli -VMHost $_ -V2 

 $esxcli.storage.nmp.satp.rule.add.Invoke($esxcli_args)

 $_ | Get-Datastore *ssd-pure* | % {

  $diskname = $_.extensiondata.info.vmfs.extent.diskname
  $esxcli.storage.nmp.psp.roundrobin.deviceconfig.set.Invoke(@{type = 'latency'; device = $diskname})
 }
}
