function Update-ESXiFirmware ($RacadmPath, $iDRACIP,$iDRACUser,$iDRACPassword,[switch]$Reboot)
{
    try
    {
        $racadm = Get-Item $RacadmPath
        $prdctname = $racadm.VersionInfo.ProductName
        
        if((!$prdctname)-or($prdctname-ne'Remote Access Controller (RAC)')){
            
            ""
            Write-Warning -Message "racadm.exe not found"
            ""
        }
    }
    catch
    {
        ""
        Write-Warning -Message "racadm.exe not found"
        ""
        $Error[0]
    }
    
    $racadm_args = @()
    
    $racadm_args += "-r $iDRACIP -u $iDRACUser -p $iDRACPassword update -t http -e downloads.dell.com"

    if($Reboot){
        
        $racadm_args += "-a TRUE"
    }else{
        
        $racadm_args += "-a FALSE"
    }

    Start-Process -FilePath $racadm -ArgumentList $racadm_args -NoNewWindow -Wait
}
