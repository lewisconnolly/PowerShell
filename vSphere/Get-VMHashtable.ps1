function Get-VmHashtable {
    $global:HashVMs=@{}
    ForEach ($vm in Get-VM) {if($vm.Hostname -and !$HashVMs[$vm.Hostname]){$HashVMs[$vm.Hostname]=$vm}else{$HashVMs[$vm.Name]=$vm}}
}

