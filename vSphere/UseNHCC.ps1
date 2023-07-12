$esxcli = get-esxcli -VMHost 'enter host' -V2 

# get useNHCC setting

$esxcli.system.settings.kernel.list.invoke()|? name -eq useNHCC

#enable useNHCC

$esxcli.system.settings.kernel.set.Invoke(@{setting='useNHCC';value='true'})

