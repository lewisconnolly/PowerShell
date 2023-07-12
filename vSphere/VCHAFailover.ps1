# Change vcenter DNS record for failover

$origVcenterRecord = Get-DnsServerResourceRecord -Name vcenterc01 -ZoneName zonalconnect.local -ComputerName dca-utl-dc1
$origVcenterRecord | Remove-DnsServerResourceRecord -ZoneName zonalconnect.local -ComputerName dca-utl-dc1  
#$origVcenterPtrRecord = Get-DnsServerResourceRecord -ZoneName 30.172.in-addr.arpa -ComputerName dca-utl-dc1 -Name 5.2
#$origVcenterPtrRecord | Remove-DnsServerResourceRecord -ZoneName 30.172.in-addr.arpa -ComputerName dca-utl-dc1  

Add-DnsServerResourceRecord -ZoneName zonalconnect.local -ComputerName dca-utl-dc1 -CreatePtr -IPv4Address 172.31.2.5 -Name vcenterc01 -A 

# Flush DNS on dcautlprdwrk01, dca-utl-sep, dcbutlprdvbs01. Ignore error if computer unavailable (due to site failure, for example)

ipconfig /flushdns

Invoke-Command -ComputerName dca-utl-sep,dcbutlprdvbs01 -ScriptBlock {ipconfig /flushdns} -ErrorAction:Ignore

# Change vcenter DNS record for failback

$origVcenterRecord = Get-DnsServerResourceRecord -Name vcenterc01 -ZoneName zonalconnect.local -ComputerName dca-utl-dc1
$origVcenterRecord | Remove-DnsServerResourceRecord -ZoneName zonalconnect.local -ComputerName dca-utl-dc1  
#$origVcenterPtrRecord = Get-DnsServerResourceRecord -ZoneName 30.172.in-addr.arpa -ComputerName dca-utl-dc1 -Name 5.2
#$origVcenterPtrRecord | Remove-DnsServerResourceRecord -ZoneName 30.172.in-addr.arpa -ComputerName dca-utl-dc1  

Add-DnsServerResourceRecord -ZoneName zonalconnect.local -ComputerName dca-utl-dc1 -CreatePtr -IPv4Address 172.30.2.5 -Name vcenterc01 -A 

# Flush DNS on dcautlprdwrk01, dca-utl-sep, dcbutlprdvbs01. Ignore error if computer unavailable (due to site failure, for example)

ipconfig /flushdns

Invoke-Command -ComputerName dca-utl-sep,dcbutlprdvbs01 -ScriptBlock {ipconfig /flushdns} -ErrorAction:Ignore

