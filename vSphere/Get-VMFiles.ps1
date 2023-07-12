function Get-VMFiles {

    param(
        [parameter(position=0,ValueFromPipeline=$true,mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.Datastore[]]
        $DataStore,
        [parameter(position=1)]
        [int]
        $DaysSinceLastWrite = 0,
        [String]
        $Filter = '*'
    )

    process {

        $DataStore | ForEach-Object {

            $_ | Select-Object @{l='Path';e={$_.DatastoreBrowserPath}} | Get-ChildItem -Recurse -Filter $Filter | 
            Where-Object {($_.PSIsContainer -eq $false) -and (($_.LastWriteTime) -lt (Get-Date).AddDays("-$DaysSinceLastWrite"))}
        }
    }
} 
