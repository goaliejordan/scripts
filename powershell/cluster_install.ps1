##powershell workflow for cluster install:
$ClusterName = "netappcluster"
$node = "nodename"
$spIP = 0.0.0.0
$spSubnet = 0.0.0.0
$spGateway = 0.0.0.0
$mgmtIP = 0.0.0.0
$mgmtSubnet = 0.0.0.0
$mgmtGateway = 0.0.0.0
$mgmtPort = e0a
$licenses = abc,abc,abc ##should get this from a csv.
$DnsDomainName = "na.qualcomm.com"
$DnsNameServers = 10.43.6.212,10.43.4.212
$NodeMgmtIP = 0.0.0.0
$NodeMgmtSubnet = 0.0.0.0
$NodeMgmtGateway = 0.0.0.0
$NodeMgmtPort = e0a
$location = "San Diego" 
$VserverName = "vserver"
$VserverDataPort = a0a
$TestLifIpAddress = 0.0.0.0
$TestLifNetmask = 0.0.0.0
$TestLifGateway = 0.0.0.0
$BackupLifIpAddress = 0.0.0.0
$BackupLifNetmask = 0.0.0.0
$BackupLifGateway = 0.0.0.0
$SMLifIpAddress = 0.0.0.0
$SMLifNetmask = 0.0.0.0
$SMLifGateway = 0.0.0.0
$VsmDnsDomainName = "na.qualcomm.com"
$VsmDnsNameServers = 10.43.6.212,10.43.4.212
$LdapServer = 10.43.110.23
##variables for LS mirror creation
$SourceCluster = $ClusterName
$DestinationCluster = $ClusterName
$SourceVserver = $VserverName
$DestinationVserver = $VserverName
$SourceVolume = "vserver_root"
$DestinationVolume = $VserverName + "root_ls1"
$nodes = get-ncnode  ##stores the nodes as an array


Connect-nccontroller
##add licenses to cluster
import-csv c:\temp\license.csv | 
foreach {
write-host "Adding license" $_.license 
Add-NcLicense -license $_.license
}

##configure the cluster SP ##needs to loop through each node and address from a file.
Set-NcServiceProcessorNetwork -Node $node -AddressType "ipv4" -Dhcp "none" -Address $spIP -Netmask $spSubnet -GatewayAddress $spGateway

#rename the nodes after they have been joined to the cluster
$nodes = (get-ncnode).node | foreach ($node in $nodes) { Rename-NcNodenode -node $node -newname ($node -replace "-mgmt")}


##set flexscale options 
Invoke-NcSsh node run -node * options flexscale.enable on
Invoke-NcSsh node run -node * options flexscale.lopri_blocks on
Invoke-NcSsh node run -node * options flexscale.normal_data_blocks on

##configure storage failover
Invoke-NcSsh storage failover modify -node * -enabled true
Invoke-NcSsh failover modify –node * -auto-giveback true

##unlock the diag user
Unlock-NcUser -username diag -vserver $VserverName
Set-Ncuserpassword -UserName diag -password netapp123 -vserver $VserverName

##enable web access and other services on vservers
Invoke-NcSsh vserver services web modify -name spi|ontapi|compat -vserver * -enabled true
Invoke-NcSsh vserver services web access create -name spi -role admin -vserver <<var_clustername>>
Invoke-NcSsh vserver services web access create -name ontapi -role admin -vserver <<var_clustername>>
Invoke-NcSsh vserver services web access create -name compat -role admin -vserver <<var_clustername>>

##create admin user for access to logs through http.
New-NcUser -UserName admin -Vserver $VserverName -Application http

##assign disks to system
Get-NcNode $node | Get-NcDiskOwner -OwnershipType unowned | Set-NcDiskOwner -Owner $node

##rename aggr0
rename-ncaggr -name aggr0_node_02_0 -newname aggr0_$node

##create new aggregates
aggr create -aggr <nodename_<disktech><speed>_<increment> -node <<var_node>> -maxraidsize 23|18 -diskcount xx
New-NcAggr -Name <String> -DiskCount xx -Node <String[]> -RaidSize 23
New-NcAggr -Name <String>$disktech$diskspeed -DiskCount xx -Node <String[]> -RaidSize 18

##remove snapshots and schedules
Invoke-NcSsh node run -node * snap sched -A <<var_aggr01>>_01 0 0 0
Invoke-NcSsh node run –node * snap delete -a -A <<var_aggr01>>

##create 2 ifgroups and add ports to each one.
New-NcNetPortIfgrp -Name a0a -Node * -DistributionFunction port -Mode multimode_lacp
Add-NcNetPortIfgrpPort -name a0a -node * -port e7a
Add-NcNetPortIfgrpPort -name a0a -node * -port e13a

New-NcNetPortIfgrp -Name a0b -Node * -DistributionFunction port -Mode multimode_lacp
Add-NcNetPortIfgrpPort -name a0a -node * -port e7b
Add-NcNetPortIfgrpPort -name a0a -node * -port e13b

##enable cdpd on all of the nodes
Invoke-NcSsh node run -node * options cdpd.enable on

##disable flowcontrol on all of the ports
get-ncnetport | Set-NcNetPort -FlowControl false

##create failover groups and add the interfaces to the group.
Invoke-NcSsh net int failover-groups create -failover-group data -node <<var_node01>> -port a0a
Invoke-NcSsh net int failover-groups create -failover-group backup -node <<var_node02>> -port a0b
Invoke-NcSsh net int failover-groups create -failover-group cluster_mgmt -node <<var_node02>> -port e0a

Set-NcNetInterface -Name cluster_mgmt -Vserver * -FailoverPolicy nextavail -FailoverGroup cluster_mgmt 

##set Date and NTP on each node
Invoke-NcSsh system services ntp server create -node * -server time-server1
Invoke-NcSsh system services ntp server create -node * -server time-server2

Invoke-NcSsh Cluster date modify -timezone America/Los_Angeles

##configure autosupport

Set-NcAutoSupportConfig -Node * [-MailHosts smtphost.qualcomm.com -From ""$cluster"@qualcomm.com" -To "nas.asups@qualcomm.com,qct-ds-notify@qualcomm.com" -transport http -IsEnabled true -IsSupportEnabled true
Invoke-NcAutosupport -node * -message "system test" -type all

##set tape reservations
Set-NcOption -name tape.reservation -value persistent -vserver *

##Set disk autoassign
Invoke-NcSsh node run -node * -command options disk.auto_assign on

##set ndmp options
Invoke-NcSsh system services ndmp on 
Invoke-NcSsh system services ndmp modify –node * -clear-text false 
Invoke-NcSsh system services ndmp node-scope –mode on

## create vserver
New-NcVserver -Name $VserverName -RootVolume <String> -NameServerSwitch <String[]> -RootVolumeSecurityStyle "unix" -Language 'c'-NameMappingSwitch <String[]> -RootVolumeAggregate $node1_disktech$diskspeed_1
	Set-NcVserver -Name $VserverName -Aggregates <String[]> -AllowedProtocols 'cifs','nfs'
	
	
	##increment the data lif naming for each node.
	Get-ncnode | New-NcNetInterface -Name "data01" -Vserver $VserverName -Role "data" -Node $node -Port "a0a" -DataProtocols "nfs","cifs" -Address $TestLifIpAddress -Netmask $TestLifNetmask -DnsDomain $VsmDnsDomainName -FailoverPolicy "nextavail" -FailoverGroup "data" [-UseFailoverGroup <String>] -AutoRevert true
    
	##setup dns
	New-NcNetDns -Domains $VsmDnsDomainName -NameServers $VsmDnsNameServers -State enabled -VserverContext $VserverName
	
	##setup ldap
	Set-NcLdapClient -Name ($VserverName + "_config") <String> -Servers $LdapServer -TcpPort 389 -QueryTimeout 10 -MinBindLevel "anonymous" -BindDn "-" -BaseDn "dc=qualcomm","dc=com" -BaseScope "subtree" -UserDn "ou=people,dc=qualcomm,dc=com" -UserScope "onelevel" -GroupDn "ou=unix,ou=groups,dc=qualcomm,dc=com" -GroupScope "onelevel" -NetGroupDn "ou=netgroups,dc=qualcomm,dc=com" -NetGroupScope "onelevel" -VserverContext $VserverName 
	Set-NcLdapConfig -ClientConfig ($VserverName + "_config") -ClientEnabled true -VserverContext $VserverName
	
	##enable nfs on vserver
	Enable-NcNfs -VserverContext $VserverName
	
	##enable cifs on the vserver
    Add-NcCifsServer -Name $VserverName -Domain $VsmDnsDomainName -OrganizationalUnit "OU=NetApps,OU=Servers,OU=San Diego" -VserverContext $VserverName
    
##Create LS mirrors
New-NcVol -Name $VserverName + "root_ls1" -Aggregate $nodeAggr -Type "dp" -VserverContext $VserverName -Size 10g
write-host ("Creating SnapMirror relationship between " + $SourceCluster + ":"+ $SourceVserver + "/"+ $SourceVolume + " and " + $DestinationCluster + ":"+ $DestinationVserver + "/"+ $DestinationVolume )
New-NcSnapmirror -SourceCluster $SourceCluster -DestinationCluster $DestinationCluster -SourceVserver $SourceVserver -DestinationVserver $DestinationVserver -SourceVolume $SourceVolume -DestinationVolume $DestinationVolume
write-host ("Initializing the LS snapmirror relationship")
Invoke-NcSnapmirrorInitialize -SourceCluster $SourceCluster -DestinationCluster $DestinationCluster -SourceVserver $SourceVserver -DestinationVserver $DestinationVserver -SourceVolume $SourceVolume -DestinationVolume $DestinationVolume


##Add network interfaces to the failover group
Set-NcNetInterface -Name "data01" -Vserver $VserverName -FailoverPolicy nextavail -FailoverGroup "data"

##create new routing groups. Repeat for all nodes in the cluster
Invoke-NcSsh Routing-groups create –vserver $node1 -routing-group i129.46.8.0/23 –subnet 129.46.8.0/23 –role intercluster –metric 40 
Invoke-NcSsh Routing-groups create –vserver $node1 -routing-group n129.46.8.0/23 –subnet 129.46.8.0/23 –role node-mgmt –metric 10 


    ##create the routes and add them to the routing groups
	New-NcNetRoutingGroupRoute -RoutingGroup "i129.46.8.0/23" -Vserver $VserverName  -Destination "0.0.0.0/0" -Gateway "129.46.8.1" -Metric 40
	New-NcNetRoutingGroupRoute -RoutingGroup "n129.46.8.0/23" -Vserver $VserverName  -Destination "0.0.0.0/0" -Gateway "129.46.8.1" -Metric 10
	
	##create backup lif -repeat for all nodes.
	New-NcNetInterface -Name "bu01" -Vserver $VserverName -Role "node_mgmt" -Node $node -Port "a0b" -DataProtocols "none" -Address $BackupLifIpAddress -Netmask $BackupLifNetmask -RoutingGroup "n10.43.154.0/23" -FailoverPolicy "nextavail" -FailoverGroup "" -AutoRevert true -AdministrativeStatus "up"
	##create intercluster snapmirror lif -repeat for all nodes.
	New-NcNetInterface -Name "sm01" -Vserver $VserverName -Role "node_mgmt" -Node $node -Port "a0b" -DataProtocols "none" -Address $SMLifIpAddress -Netmask $SMLifNetmask -RoutingGroup "i10.43.154.0/23" -FailoverPolicy "nextavail" -FailoverGroup "" -AutoRevert true -AdministrativeStatus "up"
	
##create name-mappings on cluster
New-NcNameMapping -Direction "win_unix" -Position 1 -Pattern "NA\\Administrator" -Replacement "root" -VserverContext $VserverName 
New-NcNameMapping -Direction "win_unix" -Position 2 -Pattern "NA\\(.+)" -Replacement "\1" -VserverContext $VserverName 
New-NcNameMapping -Direction "unix_win" -Position 1 -Pattern "root" -Replacement "NA\\Administrator" -VserverContext $VserverName 
New-NcNameMapping -Direction "unix_win" -Position 2 -Pattern "(.+)" -Replacement "NA\\\1" -VserverContext $VserverName 

##add ssh keys to filer
New-NcUser -UserName 'c_nchopr' -Vserver $VserverName -Application 'ssh' -AuthMethod 'publickey' -Role admin

$dirPath1 = '/var/home/c_nchopr/.ssh'
$filePath = $dirPath1 + "/authorized_keys"
$SshKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAuuYnZylwbDIBF9GwghHhlYNMTzMj/lWPYDFtkxOKS0zGHCwQRI1jHAMi9OmYk9nuqFN1KCF0gzPk9hxM+YQA4GIlJB49pHNFgPfQKzfULg3OdGt7LCjx461oadX4H99pqAP/ZhuTKHzccAFgkOygrRCWXWFE1TyTKvP/rc+/a88= c_nchopr@icepick'


# Create the directory
New-NcDirectory -Path $dirPath1 -Permission 700  -ErrorAction SilentlyContinue 
 

# Write the key to the file.
Write-NcFile -Path $filePath -Append -Data $("$SshKey" + "`n")


##get printed detail output.


