#VM HA Status

Get-VM | select Name,PowerState,@{N="Protected";E={$_.ExtensionData.Runtime.DasVmProtection.DasProtected}} | ogv