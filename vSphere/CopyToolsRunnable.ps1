function copy-tools($path) {

    ls | % {
        Copy-DatastoreItem -Item $_ -Destination $path
    }

}

cvi vcenter -Credential $lcred

$dca1 = 'vmstore:\DCA\DCA-10K-EQL01\productLocker\packages\vmtoolsRepo\vmtools'
$dca2 = 'vmstore:\DCA\DCA-10K-EQL01\productLocker\packages\6.5.0\vmtools'

$dcb = 'vmstore:\DCB\DCB-10K-EQL01\productLocker\packages\vmtoolsRepo\vmtools'

# download tools

Read-Host -Prompt 'have latest tools been downloaded?'

# windows tools

cd C:\Users\Lewisc\Desktop\latest_vmtools\windows

# copy windows tools to dca

$dca1,$dca2 | % {
    copy-tools -path $_
}

# copy windows tools to dcb

copy-tools -path $dcb

# linux tools

cd C:\Users\Lewisc\Desktop\latest_vmtools\linux

# copy linux tools for dca

$dca1,$dca2 | % {
    copy-tools -path $_
}

# copy linux tools for dcb

copy-tools -path $dcb
