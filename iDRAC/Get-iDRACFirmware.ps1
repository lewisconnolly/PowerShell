#########################
### Get-iDracFirmware ###           
###  lewis.connolly   ###       
#########################

# Return VMHost firmware inventory

function Get-iDRACFirmware {

    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $iDRACName,

        $ptpwd
    )

    BEGIN {
        
        $WarningPreference = 'SilentlyContinue'
        $ErrorActionPreference = 'Stop'
    }

    PROCESS{
        $iDRACName | % {
            try{
                $iDrac = $_
                <#if(($iDrac -like "mkhost*")-or($iDrac -like "zhost*")){
                    $secpasswd = ConvertTo-SecureString -String (get-content $env:USERPROFILE\Documents\dc.txt)
                    $tempcred = New-Object System.Management.Automation.PSCredential ('temp', $secpasswd)
                    $ptpwd = $tempcred.GetNetworkCredential().Password
                }elseif($iDrac -like "zts*"){
                    $secpasswd = ConvertTo-SecureString -String (get-content $env:USERPROFILE\Documents\tf.txt)
                    $tempcred = New-Object System.Management.Automation.PSCredential ('temp', $secpasswd)
                    $ptpwd = $tempcred.GetNetworkCredential().Password
                }#>

                $iDrac | % {
                    $fwinvstr = (C:\Program` Files\Dell\SysMgt\rac5\racadm.exe -r $iDrac -u root -p $ptpwd swinventory)

                    $CT=@()
                    $EN=@()
                    $FQDD=@()
                    $ID=@()
                    $V=@()
                    $fwinvstr | % {
                        if($_ -like "ComponentType*") {
                            $CT+=($_ -split ' = ')[-1]
                        }

                        if($_ -like "ElementName*") {
                            $EN+=($_ -split ' = ')[-1]
                        }

                        if($_ -like "FQDD*"){
                            $FQDD+=($_ -split ' = ')[-1]
                        }

                        if($_ -like "InstallationDate*"){
                            $ID+=($_ -split ' = ')[-1]
                        }

                        if($_ -clike "* Version = *"){
                            $splstr = ($_ -split ' = ')
                            $V+="$($splstr[0]): $($splstr[1])"
                        }
                    }
                    
                    for($i=0;$i -lt $CT.count;$i++){
                        [pscustomobject]@{
                            Name = $iDrac
                            ElementName = $EN[$i]
                            Version = $V[$i]
                            InstallationDate = $ID[$i]
                            ComponentType = $CT[$i]
                            FQDD = $FQDD[$i]
                        }
                    }
                }
                #gv -Name $secpasswd,$tempcred,$ptpwd -ErrorAction SilentlyContinue | Remove-variable -ErrorAction SilentlyContinue
            }catch{throw}
        }
    }
    #END {}
}

