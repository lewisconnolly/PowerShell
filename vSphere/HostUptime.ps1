Get-VMHost | Select Name,
  @{N="Uptime"; E={New-Timespan -Start $_.ExtensionData.Summary.Runtime.BootTime -End (Get-Date) | Select -ExpandProperty Days}}