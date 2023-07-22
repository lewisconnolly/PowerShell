function New-ESXiKickstartISOInstall
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [ValidateSet("6.7","7")]
        $ESXiVersion,    
    
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ESXiHostname,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Password,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Datacenter,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiIP,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiNetmask,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiGateway,

        [ValidateNotNullOrEmpty()]
        $ESXiVLANID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiDNS,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ESXiMgmtNic,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACIP,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACUser,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACPassword,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $DomainCredential,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ISOPath,

        [ValidateNotNullOrEmpty()]
        $AlertSMTP,
        
        [ValidateNotNullOrEmpty()]
        $AlertDesination,

        [ValidateNotNullOrEmpty()]
        $FirstBootDevice = 'HDD'
    )
    
    Process
    {        
        try
        {
        
        ### Check for required utilities

            $racadm  = "C:\Program Files\Dell\SysMgt\rac5\racadm.exe"
            $openssl = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"
            $ultraiso = "C:\Program Files (x86)\UltraISO\UltraISO.exe"

            $racadm, $openssl, $ultraiso | % {

                if(!(Test-Path $_))
                {
                    "`nUnable to create custom ISO for $ESXiHostname`n" | Write-Host -ForegroundColor Magenta
                    "`nPlease install $_`n" | Write-Host -ForegroundColor Magenta
                    break
                }
            }

        ### Create custom install files
        
            # Create location for host install files
            
            $path = (new-item -ItemType Directory -Path "\\dca-utl-nas\e$\lewisc-stuff\ESXi_ks\$($Datacenter.Name)\$ESXiHostname" -Force).FullName
    
            # Create hash from ESXi password
            
            $hash = ."C:\Program Files\OpenSSL-Win64\bin\openssl.exe" passwd -1 $Password
    
            # Create contents of kickstarter config file
            
            if($ESXiVLANID){$KSVLAN = "--vlanid=$ESXiVLANID"}

            $ks =
        "# Accept the VMware End User License Agreement
        vmaccepteula

        # Set the root password for the DCUI and Tech Support Mode
        rootpw --iscrypted $hash
        
        # Set to UK keyboard

        keyboard 'United Kingdom'

        # host network
        network --bootproto=static --addvmportgroup=1 --ip=$ESXiIP --netmask=$ESXiNetmask --gateway=$ESXiGateway --nameserver=$ESXiDNS --hostname=$ESXiHostname $KSVLAN

        # clear paritions and install on first eligible local disk
        clearpart --alldrives --overwritevmfs
        install --firstdisk=local

        reboot

        %firstboot --interpreter=busybox
 
        # enable & start SSH
        vim-cmd hostsvc/enable_ssh
        vim-cmd hostsvc/start_ssh
 
        # enable & start ESXi Shell
        vim-cmd hostsvc/enable_esx_shell
        vim-cmd hostsvc/start_esx_shell
 
        # Suppress ESXi Shell warning
        esxcli system settings advanced set -o /UserVars/SuppressShellWarning -i 1"
 
            # Make filename for kickstarter config file
            
            $ksfilename = "$($ESXiHostname -replace '\.zhost' ,'')ks.cfg"
            $ksfilename = $ksfilename.ToUpper()

            # Create content for custom BOOT.CFG for ISO
            
            [regex]$ptn = '([0-9]{8}\.)'
            $buildno = $ptn.Matches(($ISOPath -split '\\')[-1]).value -replace '\.',''

            if($ESXiVersion -eq '6.7'){
                $bootcfg =
        "bootstate=0
        title=Loading custom ESXi installer | Hostname = $ESXiHostname; IP = $ESXiIP; Build = $buildno
        timeout=5
        prefix=
        kernel=/b.b00
        kernelopt=netdevice=$ESXiMgmtNic bootproto=dhcp ks=cdrom:/KS/$ksfilename
        modules=/jumpstrt.gz --- /useropts.gz --- /features.gz --- /k.b00 --- /chardevs.b00 --- /user.b00 --- /procfs.b00 --- /uc_intel.b00 --- /uc_amd.b00 --- /uc_hygon.b00 --- /vmx.v00 --- /vim.v00 --- /sb.v00 --- /s.v00 --- /ata_liba.v00 --- /ata_pata.v00 --- /ata_pata.v01 --- /ata_pata.v02 --- /ata_pata.v03 --- /ata_pata.v04 --- /ata_pata.v05 --- /ata_pata.v06 --- /ata_pata.v07 --- /block_cc.v00 --- /bnxtnet.v00 --- /bnxtroce.v00 --- /brcmfcoe.v00 --- /char_ran.v00 --- /ehci_ehc.v00 --- /elxiscsi.v00 --- /elxnet.v00 --- /hid_hid.v00 --- /i40en.v00 --- /iavmd.v00 --- /igbn.v00 --- /ima_qla4.v00 --- /ipmi_ipm.v00 --- /ipmi_ipm.v01 --- /ipmi_ipm.v02 --- /iser.v00 --- /ixgben.v00 --- /lpfc.v00 --- /lpnic.v00 --- /lsi_mr3.v00 --- /lsi_msgp.v00 --- /lsi_msgp.v01 --- /lsi_msgp.v02 --- /misc_cni.v00 --- /misc_dri.v00 --- /mtip32xx.v00 --- /ne1000.v00 --- /nenic.v00 --- /net_bnx2.v00 --- /net_bnx2.v01 --- /net_cdc_.v00 --- /net_cnic.v00 --- /net_e100.v00 --- /net_e100.v01 --- /net_enic.v00 --- /net_fcoe.v00 --- /net_forc.v00 --- /net_igb.v00 --- /net_ixgb.v00 --- /net_libf.v00 --- /net_mlx4.v00 --- /net_mlx4.v01 --- /net_nx_n.v00 --- /net_tg3.v00 --- /net_usbn.v00 --- /net_vmxn.v00 --- /nfnic.v00 --- /nhpsa.v00 --- /nmlx4_co.v00 --- /nmlx4_en.v00 --- /nmlx4_rd.v00 --- /nmlx5_co.v00 --- /nmlx5_rd.v00 --- /ntg3.v00 --- /nvme.v00 --- /nvmxnet3.v00 --- /nvmxnet3.v01 --- /ohci_usb.v00 --- /pvscsi.v00 --- /qcnic.v00 --- /qedentv.v00 --- /qfle3.v00 --- /qfle3f.v00 --- /qfle3i.v00 --- /qflge.v00 --- /sata_ahc.v00 --- /sata_ata.v00 --- /sata_sat.v00 --- /sata_sat.v01 --- /sata_sat.v02 --- /sata_sat.v03 --- /sata_sat.v04 --- /scsi_aac.v00 --- /scsi_adp.v00 --- /scsi_aic.v00 --- /scsi_bnx.v00 --- /scsi_bnx.v01 --- /scsi_fni.v00 --- /scsi_hps.v00 --- /scsi_ips.v00 --- /scsi_isc.v00 --- /scsi_lib.v00 --- /scsi_meg.v00 --- /scsi_meg.v01 --- /scsi_meg.v02 --- /scsi_mpt.v00 --- /scsi_mpt.v01 --- /scsi_mpt.v02 --- /scsi_qla.v00 --- /sfvmk.v00 --- /shim_isc.v00 --- /shim_isc.v01 --- /shim_lib.v00 --- /shim_lib.v01 --- /shim_lib.v02 --- /shim_lib.v03 --- /shim_lib.v04 --- /shim_lib.v05 --- /shim_vmk.v00 --- /shim_vmk.v01 --- /shim_vmk.v02 --- /smartpqi.v00 --- /uhci_usb.v00 --- /usb_stor.v00 --- /usbcore_.v00 --- /vmkata.v00 --- /vmkfcoe.v00 --- /vmkplexe.v00 --- /vmkusb.v00 --- /vmw_ahci.v00 --- /xhci_xhc.v00 --- /elx_esx_.v00 --- /btldr.t00 --- /esx_dvfi.v00 --- /esx_ui.v00 --- /esxupdt.v00 --- /weaselin.t00 --- /lsu_hp_h.v00 --- /lsu_inte.v00 --- /lsu_lsi_.v00 --- /lsu_lsi_.v01 --- /lsu_lsi_.v02 --- /lsu_lsi_.v03 --- /lsu_lsi_.v04 --- /lsu_smar.v00 --- /native_m.v00 --- /qlnative.v00 --- /rste.v00 --- /vmware_e.v00 --- /vsan.v00 --- /vsanheal.v00 --- /vsanmgmt.v00 --- /tools.t00 --- /xorg.v00 --- /imgdb.tgz --- /imgpayld.tgz
        build=
        updated=0

        "
            }elseif($ESXiVersion -eq '7'){
                $bootcfg = 
        "bootstate=0
        title=Loading custom ESXi installer | Hostname = $ESXiHostname; IP = $ESXiIP; Build = $buildno
        timeout=5
        prefix=
        kernel=/b.b00
        kernelopt=netdevice=$ESXiMgmtNic bootproto=dhcp ks=cdrom:/KS/$ksfilename
        modules=/jumpstrt.gz --- /useropts.gz --- /features.gz --- /k.b00 --- /uc_intel.b00 --- /uc_amd.b00 --- /uc_hygon.b00 --- /procfs.b00 --- /vmx.v00 --- /vim.v00 --- /tpm.v00 --- /sb.v00 --- /s.v00 --- /atlantic.v00 --- /bnxtnet.v00 --- /bnxtroce.v00 --- /brcmfcoe.v00 --- /elxiscsi.v00 --- /elxnet.v00 --- /i40en.v00 --- /iavmd.v00 --- /icen.v00 --- /igbn.v00 --- /ionic_en.v00 --- /irdman.v00 --- /iser.v00 --- /ixgben.v00 --- /lpfc.v00 --- /lpnic.v00 --- /lsi_mr3.v00 --- /lsi_msgp.v00 --- /lsi_msgp.v01 --- /lsi_msgp.v02 --- /mtip32xx.v00 --- /ne1000.v00 --- /nenic.v00 --- /nfnic.v00 --- /nhpsa.v00 --- /nmlx4_co.v00 --- /nmlx4_en.v00 --- /nmlx4_rd.v00 --- /nmlx5_co.v00 --- /nmlx5_rd.v00 --- /ntg3.v00 --- /nvme_pci.v00 --- /nvmerdma.v00 --- /nvmetcp.v00 --- /nvmxnet3.v00 --- /nvmxnet3.v01 --- /pvscsi.v00 --- /qcnic.v00 --- /qedentv.v00 --- /qedrntv.v00 --- /qfle3.v00 --- /qfle3f.v00 --- /qfle3i.v00 --- /qflge.v00 --- /rste.v00 --- /sfvmk.v00 --- /smartpqi.v00 --- /vmkata.v00 --- /vmkfcoe.v00 --- /vmkusb.v00 --- /vmw_ahci.v00 --- /bmcal.v00 --- /crx.v00 --- /elx_esx_.v00 --- /btldr.v00 --- /esx_dvfi.v00 --- /esx_ui.v00 --- /esxupdt.v00 --- /tpmesxup.v00 --- /weaselin.v00 --- /esxio_co.v00 --- /loadesx.v00 --- /lsuv2_hp.v00 --- /lsuv2_in.v00 --- /lsuv2_ls.v00 --- /lsuv2_nv.v00 --- /lsuv2_oe.v00 --- /lsuv2_oe.v01 --- /lsuv2_oe.v02 --- /lsuv2_sm.v00 --- /native_m.v00 --- /qlnative.v00 --- /trx.v00 --- /vdfs.v00 --- /vmware_e.v00 --- /vsan.v00 --- /vsanheal.v00 --- /vsanmgmt.v00 --- /tools.t00 --- /xorg.v00 --- /gc.v00 --- /imgdb.tgz --- /basemisc.tgz --- /resvibs.tgz --- /imgpayld.tgz
        build=
        updated=0

        "
            }

            # Out files to host install files location created earlier

            $ks | Out-File "$path\$ksfilename" -Encoding ascii -Force
            $bootcfg | Out-File "$path\BOOT.CFG" -Encoding ascii -Force
            $bootcfgfile = Get-Item "$path\BOOT.CFG"
            $ksfile = Get-Item "$path\$ksfilename"

        ### Modify ESXi installer ISO
     
            # Create custom ISO
        
            $customisofilename = "$ESXiHostname-$((Get-Item $ISOPath).name)"
            
            copy $ISOPath "$path\$customisofilename" -Force

            $customisofile = get-item "$path\$customisofilename"

            # ultraiso arguments

            $args_ultraiso = "-in $($customisofile.Fullname)"  
            $args_bootcfg = "-f $($bootcfgfile.Fullname)"
            $args_efibootcfg = "-chdir `"/EFI/BOOT`" -f $($bootcfgfile.Fullname)"
            $args_ksdir = "-newdir `"/KS`""
            $args_kscfg = "-chdir `"/KS`" -f $($ksfile.Fullname)"
    
            # overwrite BOOT.CFG in ISO

            start-process $ultraiso -args @($args_ultraiso,$args_bootcfg) -wait -NoNewWindow
            
            # Overwrite BOOT.CFG in /EFI/BOOT/
            
            start-process $ultraiso -args @($args_ultraiso,$args_efibootcfg) -wait -NoNewWindow
            
            # Add KS folder
            
            start-process $ultraiso -args @($args_ultraiso,$args_ksdir) -wait -NoNewWindow
            
            # Add KS.CFG file to KS folder
            
            start-process $ultraiso -args @($args_ultraiso,$args_kscfg) -wait -NoNewWindow

        ### Attach ISO to host via iDRAC virtual console
           
            # iDRAC login arguments

            $args_racadm = "-r $iDRACIP -u $iDRACUser -p $iDRACPassword"
            
        ### Attach ISO to host via iDRAC virtual console        

            $shareu = $DomainCredential.GetNetworkCredential().username
            $sharepw = $DomainCredential.GetNetworkCredential().password

            # racadm arguments
            while((Test-NetConnection $iDRACIP).PingSucceeded -eq $false){

                "`nTesting connection to iDRAC on IP provided`n" | Write-Host -ForegroundColor Green
                sleep 15
            }

            "`nSetting $iDRACIP to boot from new ISO`n" | Write-Host -ForegroundColor Green

            $args_remoteimage = "remoteimage -c -u $shareu -p $sharepw -l $($customisofile.FullName -replace '\\','/')"
    
            # Disconnect virtual media
            
            start-process $racadm -args @($args_racadm,"remoteimage -d") -wait -NoNewWindow
            #. 'C:\Program Files\Dell\SysMgt\rac5\racadm.exe' -u $iDRACUser -p $iDRACPassword -r $iDRACIP remoteimage -d
            sleep 5
            
            # Attach custom ISO
            
            start-process $racadm -args @($args_racadm,$args_remoteimage) -wait -NoNewWindow            
            #$remoteimagePath = $($customisofile.FullName -replace '\\','/')
            #. 'C:\Program Files\Dell\SysMgt\rac5\racadm.exe' -u $iDRACUser -p $iDRACPassword -r $iDRACIP remoteimage -c -u $shareu -p $sharepw -l $remoteimagePath
            
            # Set iDRAC next boot to new ISO
            
            #start-process $racadm -args @($args_racadm,$args_config,"-o cfgServerBootOnce 1") -wait -NoNewWindow
            #start-process $racadm -args @($args_racadm,$args_config,"-o cfgServerfirstbootdevice VCD-DVD") -wait -NoNewWindow

            start-process $racadm -args @($args_racadm,"set iDRAC.ServerBoot.BootOnce Enabled") -wait -NoNewWindow
            #. 'C:\Program Files\Dell\SysMgt\rac5\racadm.exe' -u $iDRACUser -p $iDRACPassword -r $iDRACIP set iDRAC.ServerBoot.BootOnce Enabled
            
            start-process $racadm -args @($args_racadm,"set iDRAC.ServerBoot.FirstBootDevice VCD-DVD") -wait -NoNewWindow
            #. 'C:\Program Files\Dell\SysMgt\rac5\racadm.exe' -u $iDRACUser -p $iDRACPassword -r $iDRACIP set iDRAC.ServerBoot.FirstBootDevice VCD-DVD

        ### Cleanup, output and reboot host via idrac
            
            $iso = Get-Item $customisofile

            "`nInstaller ISO:`t$($iso.FullName)`n" | Write-Host -ForegroundColor Green
            
            Send-MailMessage -From ("$ENV:USERNAME@$ENV:COMPUTERNAME.$ENV:USERDNSDOMAIN").tolower() -Subject "$ESXiHostname ready to reboot"`
            -SmtpServer $AlertSMTP -To $AlertDesination
            
            "`nDo you want to reboot $ESXiHostname ?`n" | Write-Host -ForegroundColor Green
            
            $ans = Read-Host -Prompt '[y/n]'

            if($ans-eq'y'){
                start-process $racadm -args @($args_racadm,"serveraction powercycle") -wait -NoNewWindow
                #. 'C:\Program Files\Dell\SysMgt\rac5\racadm.exe' -u $iDRACUser -p $iDRACPassword -r $iDRACIP serveraction powercycle
                
                "`n$ESXiHostname rebooting`n" | Write-Host -ForegroundColor Green

            }else{
                
                "`nYou have chosen not to reboot`n" | Write-Host -ForegroundColor Green
            }

            sleep 900

            "`nRemoving media from $ESXiHostname`n"| Write-Host -ForegroundColor Green

            start-process $racadm -args @($args_racadm,'remoteimage -d') -wait -NoNewWindow
            #. 'C:\Program Files\Dell\SysMgt\rac5\racadm.exe' -u $iDRACUser -p $iDRACPassword -r $iDRACIP remoteimage -d

            start-process $racadm -args @($args_racadm,"set iDRAC.ServerBoot.BootOnce Disabled") -wait -NoNewWindow
            #. 'C:\Program Files\Dell\SysMgt\rac5\racadm.exe' -u $iDRACUser -p $iDRACPassword -r $iDRACIP set iDRAC.ServerBoot.BootOnce Disabled
                        
            start-process $racadm -args @($args_racadm,"set iDRAC.ServerBoot.FirstBootDevice $FirstBootDevice") -wait -NoNewWindow
            #. 'C:\Program Files\Dell\SysMgt\rac5\racadm.exe' -u $iDRACUser -p $iDRACPassword -r $iDRACIP set iDRAC.ServerBoot.FirstBootDevice SD

            Send-MailMessage -From ("$ENV:USERNAME@$ENV:COMPUTERNAME.$ENV:USERDNSDOMAIN").tolower() -Subject "Check on $ESXiHostname install"`
            -SmtpServer $AlertSMTP -To $AlertDesination

        }
        catch {throw}
    }
}