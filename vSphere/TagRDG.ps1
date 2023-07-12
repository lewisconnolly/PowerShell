$toTag = gvm 'rdg','vms','to','tag'
$rdgtags = get-tag -Name rdg* -Category backup

$i = 0
$toTag| %{
    $_|New-TagAssignment -Tag $rdgtags[$i%$rdgtags.count]
    $i++
}