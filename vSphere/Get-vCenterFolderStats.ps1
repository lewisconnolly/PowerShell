<#
.EXAMPLE
   # Output Aztec and SaaS from DCA to a single sheet

   Get-vCenterFolderStats -Path 'C:\Users\Lewisc\Desktop'
.EXAMPLE
   # Output Aztec, SaaS, CoreServices, DomainServices and Utility from DCA to a single sheet

   Get-vCenterFolderStats -Path 'C:\Users\Lewisc\Desktop'`
   -RootFolders (Get-Folder Aztec, SaaS, CoreServices, DomainServices, Utility -Location DCA)
.EXAMPLE
   # Output Aztec and SaaS from DCA to first sheet
   # Output CoreServices, DomainServices and Utility from DCA to second sheet

   Get-vCenterFolderStats -Path 'C:\Users\Lewisc\Desktop'

   Get-vCenterFolderStats `
   -RootFolders (Get-Folder CoreServices, DomainServices, Utility -Location DCA) `
   -Path "C:\Users\Lewisc\Desktop\vCenterFolderStats_6-12-19.xlsx" # File path of spreadsheet from previous command 
#>
function Get-vCenterFolderStats ($Path,$RootFolders,$IncludePoweredOff,$OmitEmptyFolders,$SheetName){    
    
    function Get-VIFolderPath{
        [CmdletBinding()]
        [Alias()]
        [OutputType([string])]
        Param
        (
            [Parameter(Mandatory=$true,
                       ValueFromPipeline=$true, 
                       ValueFromPipelineByPropertyName=$true,
                       Position=0)]
            $VIObject
        )

        Begin {}
        Process
        {
            $VIObject | % {
                $VIObjectTypeName = $_.GetType().Name
        
                switch ($VIObjectTypeName)
                {
                    Default {$FirstFolderPropertyName = "FolderId"}

                    'FolderImpl' {$FirstFolderPropertyName = "ParentId"}

                    'VmfsDatastoreImpl' {$FirstFolderPropertyName = "ParentFolderId"}
                }

                if($_.$FirstFolderPropertyName -match 'StoragePod')
                {
                    $dsc = Get-DatastoreCluster -Id $_.$FirstFolderPropertyName
                    $folder= get-folder -Id $dsc.extensiondata.Parent
                    $folderpath= "$($folder.Name)\$($dsc.Name)"
                }
                else
                {
                    $folder= get-folder -Id $_.$FirstFolderPropertyName

                    $folderpath= $folder.Name
                }

                while ($folder.Parent -ne $null)
                {
                    $folder = $folder.Parent
                    $folderpath = "$($folder.Name)\$folderpath"
                }
                $folderpath
            }
        }
        End {}
    }
    
    Set-Alias -Name 'gvm' -Value 'Get-VM' | Out-Null
    
    Set-Alias -Name 'gvh' -Value 'Get-VMHost' | Out-Null

    if(-not$global:DefaultVIServer){ Connect-VIServer vcenter -WarningAction Ignore | Out-Null }

    if(!$RootFolders){ $rootFolders = get-folder -Location DCA -Name Aztec,SaaS }

    if($IncludePoweredOff){ $powerState = 'PoweredOn|PoweredOff' }else{ $powerState = 'PoweredOn'}

    if(!$OmitEmptyFolders){$OmitEmptyFolders = $false}

    $json =
    '[
    {
        "RootFolder":  "",
        "SubFolder":  "",
        "NumVMs":  "",
        "TotalNumCPUCommitted":  "",
        "TotalGHzCommitted":  "",
        "TotalMemGBCommitted":  ""
    },
    '
    
    $rootFolders | sort Name | % {
        
        if(($_ | gvm | ? PowerState -match $powerState) -or (-not$OmitEmptyFolders)){
            
            $vms = $_ | gvm | ? PowerState -match $powerState
            $viPath = Get-VIFolderPath -VIObject $_
            $dc = ($viPath -split '\\')[0]            
            $avgGhz = [math]::Round(
                (gvh -Location $dc |
                select @{n='clock';e={[double]($_.ExtensionData.Hardware.CpuInfo.Hz/1000000000)}} |
                measure clock -Average).Average,2
            )
            $numvms = ($vms | measure).Count
            $totalcpu = ($vms | measure NumCpu -Sum).Sum
            if(-not$totalcpu){$totalcpu = '0'}
            $totalghz = [math]::Round(($totalcpu * $avgGhz),1)
            $totalram = [math]::Round((($vms | measure MemoryGB -Sum).Sum),1)

            $json+=
            '{
                "RootFolder":  "rootfolder",
                "SubFolder":  "", 
                "NumVMs":  numvms,
                "TotalNumCPUCommitted":  totalcpu,
                "TotalGHzCommitted":  totalghz,
                "TotalMemGBCommitted":  totalram
            },' `
            -creplace 'rootfolder',$_.Name `
            -creplace 'numvms',$numvms `
            -creplace 'totalcpu',$totalcpu `
            -creplace 'totalghz',$totalghz `
            -creplace 'totalram',$totalram

            $rootFolderName = $_.Name
            
            if(($vms = $_ | gvm | ? {$_.Folder.Name -eq $rootFolderName} | ? PowerState -match $powerState)){
                
                $numvms = ($vms | measure).Count
                $totalcpu = ($vms | measure NumCpu -Sum).Sum
                if(-not$totalcpu){$totalcpu = '0'}
                $totalghz = [math]::Round(($totalcpu * $avgGhz),1)
                $totalram = [math]::Round((($vms | measure MemoryGB -Sum).Sum),1)

                $json+=
                '{
                    "RootFolder":  "",
                    "SubFolder":  "InRoot",
                    "NumVMs":  numvms, 
                    "TotalNumCPUCommitted":  totalcpu,
                    "TotalGHzCommitted":  totalghz,
                    "TotalMemGBCommitted":  totalram
                },' `
                -creplace 'numvms',$numvms `
                -creplace 'totalcpu',$totalcpu `
                -creplace 'totalghz',$totalghz `
                -creplace 'totalram',$totalram
            }
        
            $parid = $_.id
        
            if(($_ | get-folder).count -gt 0){

                $_ | get-folder | ? parentid -eq $parid | sort Name | % {
                    
                    if(($_ | gvm | ? PowerState -match $powerState) -or (-not$OmitEmptyFolders)){
                        
                        $vms = $_ | gvm | ? PowerState -match $powerState
                        $numvms = ($vms | measure).Count
                        $totalcpu = ($vms | measure NumCpu -Sum).Sum
                        if(-not$totalcpu){$totalcpu = '0'}
                        $totalghz = [math]::Round(($totalcpu * $avgGhz),1)
                        $totalram = [math]::Round((($vms | measure MemoryGB -Sum).Sum),1)

                        $json+=
                        '{
                            "RootFolder":  "",
                            "SubFolder":  "customer",
                            "NumVMs":  numvms, 
                            "TotalNumCPUCommitted":  totalcpu,
                            "TotalGHzCommitted":  totalghz,
                            "TotalMemGBCommitted":  totalram
                        },' `
                        -creplace 'customer',$_.Name `
                        -creplace 'numvms',$numvms `
                        -creplace 'totalcpu',$totalcpu `
                        -creplace 'totalghz',$totalghz `
                        -creplace 'totalram',$totalram
                    }
                }
            }

            $json +=
            '{
                "RootFolder":  "",
                "SubFolder":  "",
                "NumVMs":  "",
                "TotalNumCPUCommitted":  "",
                "TotalGHzCommitted":  "",
                "TotalMemGBCommitted":  ""
            },' 
        }
    }

    $json += 
    '{
        "RootFolder":  "",
        "SubFolder":  "",
        "NumVMs":  "",
        "TotalNumCPUCommitted":  "",
        "TotalGHzCommitted":  "",
        "TotalMemGBCommitted":  ""
    }
    ]'
    
    $folderStats = $json | ConvertFrom-Json

    if($Path){
        if($Path -notlike "*.xls*"){

            $splat = @{Path = "$($Path.TrimEnd('\'))\vCenterFolderStats_$(get-date -Format "d-M-y").xlsx"}

            if($SheetName){ $splat.Add("WorksheetName", $SheetName) }

            $folderStats | Export-Excel @splat            
        }elseif($SheetName){
            $folderStats | Export-Excel -Path $Path -WorksheetName $SheetName
        }else{
            $wrkbook = Open-ExcelPackage -Path $Path
            $SheetName = "Sheet$($wrkbook.Workbook.Worksheets.Count+1)"

            $folderStats | Export-Excel -Path $Path -WorksheetName $SheetName
        }    
    }else{ $folderStats }
}