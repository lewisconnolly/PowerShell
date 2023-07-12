$LicenseManager= Get-view LicenseManager

$LicenseAssignmentManager= Get-View $LicenseManager.LicenseAssignmentManager

$lics = Get-View -ViewType HostSystem  |

select Name,

@{N='Product';E={$_.Config.Product.FullName}},

@{N='Build';E={$_.Config.Product.Build}},

@{N='LicenseType';E={

    $script:licInfo = $LicenseAssignmentManager.GetType().GetMethod("QueryAssignedLicenses").Invoke($LicenseAssignmentManager,@($_.MoRef.Value))

    $licInfo.AssignedLicense.Name

}},

@{N='LicenseExpiration';E={
    
    if($licInfo.AssignedLicense.Name -eq 'evaluation mode'){
        (($licInfo.properties | ? key -eq evaluation).Value.Properties | ? key -eq expirationdate).value
    }else{
        $script:licInfo.Properties | where{$_.Key -eq 'expirationDate'} | select -ExpandProperty Value
    }
}}

