
$randomorder =@()
$torandomize = $foldersize
for($i = 0;$i -le ($foldersize.count-1);$i++){
$random = $torandomize| get-random
$randomorder += $random
$torandomize =$torandomize | ? name -ne $random.name
}

$group1=@()
$group2=@()
$group3=@()
$group4=@()

$groupmax=($randomorder | measure totalsize -Sum).sum/4

$randomorder | % {
    $group1sum = ($group1 | measure totalsize -Sum).sum + $_.totalsize
    $group2sum = ($group2 | measure totalsize -Sum).sum + $_.totalsize
    $group3sum = ($group3 | measure totalsize -Sum).sum + $_.totalsize
    $group4sum = ($group4 | measure totalsize -Sum).sum + $_.totalsize

    if($group1sum -le $groupmax){
        $group1 += $_
    }
    elseif($group2sum -le $groupmax){
        $group2 += $_
    }
    elseif($group3sum -le $groupmax){
        $group3 += $_
    }
    elseif($group4sum -le $groupmax){
        $group4 += $_
    }else{
        #add to smallest group
        $smallestgroup = (Get-Variable -Name group*sum | sort value | select -first 1).name
        if($smallestgroup -match 1){$group1 += $_}
        elseif($smallestgroup -match 2){$group2 += $_}
        elseif($smallestgroup -match 3){$group3 += $_}
        elseif($smallestgroup -match 4){$group4 += $_}
    }
}

$group1sum = ($group1 | measure totalsize -Sum).sum
$group2sum = ($group2 | measure totalsize -Sum).sum
$group3sum = ($group3 | measure totalsize -Sum).sum
$group4sum = ($group4 | measure totalsize -Sum).sum

$group1.count +  $group2.count + $group3.count + $group4.count

$group1sum/1GB
$group2sum/1GB
$group3sum/1GB
$group4sum/1GB