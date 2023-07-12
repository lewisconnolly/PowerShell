#for each host
# add store folder in capacity vol1
# update symlink for stores to new folder

$esxicred = get-credential


gvh |? name -match '8'| % {
    $foldername = $_.name.Replace('.zhost','')
    Write-Host "Adding $foldername directory to 7.2KRAID5-PV-Vol1\zHostStores\"
    new-item -Type Directory `
                -Path 'vmstores:\tf-vcenter@443\Tanfield\7.2KRAID5-PV-Vol1\zHostStores\' `
                -Name "$foldername"
    
    $sessh = New-SSHSession -ComputerName $_.name -Credential $esxicred
    $cmd = "ln -sfn /vmfs/volumes/56f40e5c-a7b53d7d-9945-180373f16773/zHostStores/$foldername/ store"
    Invoke-SSHCommand -Command $cmd -SessionId $sessh.SessionId
    Remove-SSHSession $sessh
}
