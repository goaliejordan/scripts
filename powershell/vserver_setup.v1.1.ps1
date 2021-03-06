﻿
<#  
.SYNOPSIS  
   Creates a NAS VSM on a Netapp Cluster.  
.DESCRIPTION  
  Creates a fully functional NAS (CIFS and NFS) VSM on a specified cluster.
    -Creates vsm and configures interfaces for data, backup and snapmirror
    -configures LDAP, DNS and AD integration
    -Configures default export policy for NFS exports and configures CIFS to join AD.
    -Creates LS mirrors for the VSM root volume and initializes the relationship
    
Parameters are specified by manually declaring the variable.

Prerequisites:
    -Requires PowerShell 3.0 or higher 
    -Cluster has been created
    -admin access to the cluster
    -variable assignments have been gathered from the customer.
    -a user is available to join the SVM-cifs to AD  
#>  

#########################################################################
# Declare Variables
Import-Module DataONTAP

#Alternative is to get all variables from a .csv file that the customer populates with data.
<#
##Get all variables from csv config.
$Config_csv = import-csv "C:\temp\cluster_config_files\vsm_setup_config.csv"
$ClusterName = $Config_csv.ClusterName[0]
[string]$DnsDomainName = $Config_csv.DnsDomainName
[string]$DnsNameServers = $Config_csv.DnsNameServers
[string]$VserverName = $Config_csv.VserverName
[string]$VserverDataPort = $Config_csv.VserverDataPort
[string]$TestLifIpAddress = $Config_csv.TestLifIpAddress
[string]$TestLifNetmask = $Config_csv.TestLifNetmask
[string]$TestLifGateway = $Config_csv.TestLifGateway
[string]$BackupLifIpAddress = $Config_csv.BackupLifIpAddress
[string]$BackupLifNetmask = $Config_csv.BackupLifNetmask
[string]$BackupLifGateway = $Config_csv.BackupLifGateway
[string]$SMLifIpAddress = $Config_csv.SMLifIpAddress
[string]$SMLifNetmask = $Config_csv.smlifnetmask
[string]$SMLifGateway = $Config_csv.smlifgateway
[string]$VsmDnsDomainName = $Config_csv.vsmdnsdomainname
[string]$VsmDnsNameServers = $Config_csv.vsmdnsnameservers
[string]$LdapServer = $Config_csv.ldapserver
[string]$LdapSchema = $Config_csv.ldapschema
[string]$DataLifPort = $Config_csv.datalifport
[string]$BackupLifPort = $Config_csv.backupLifPort
[string]$SnapmirrorLifPort = $Config_csv.snapmirrorlifport
#>
$TranscriptPath = "c:\temp\vserver_setup_transcript_$(get-date -format "yyyyMMdd_hhmmtt").txt"




$ClusterName = "example-mgmt"
$DnsDomainName = "example.com"
$DnsNameServers = "10.10.2.2"
$VserverName = "example"
$VserverDataPort = "a0a"
$TestLifIpAddress = @("10.10.2.2","10.10.2.3")
$TestLifNetmask = "255.255.255.0"
$TestLifGateway = "10.10.2.1"
$timeserver = @("dc.example.com","wfa.example.com")
$BackupLifIpAddress = @("10.10.2.4","10.10.2.5")
$BackupLifNetmask = "255.255.255.0"
$BackupLifGateway = "10.10.2.1"
$SMLifIpAddress = @("10.10.2.4","10.10.2.5")
$SMLifNetmask = "255.255.255.0"
$SMLifGateway = "10.10.2.1"
$VsmDnsDomainName = "example.com"
$VsmDnsNameServers = "10.10.2.1"
$LdapServer = "10.43.110.23"
$LdapSchema = "RFC-2307"
$DataLifPort = "a0a"
$BackupLifPort = "a0b"
$SnapmirrorLifPort = "a0b"





#########################################################################
# Declare the functions

#used for commands that do not have a powershell command created for the API yet.
function Invoke-SshCmd ($cmd){
    Invoke-NcSsh $cmd
}

#formats messages output
function Write-Msg ($msg) {
    $color = "yellow"
    Write-host ""
    Write-host $msg -foregroundcolor $color
    Write-host ""
}
function Write-ErrMsg ($msg) {
    $fg_color = "White"
    $bg_color = "Red"
    Write-host ""
    Write-host $msg -ForegroundColor $fg_color -BackgroundColor $bg_color
    Write-host ""
}

#Verifies that the dataontap module is installed
function Check-LoadedModule {
  Param( 
    [parameter(Mandatory = $true)]
    [string]$ModuleName
  )
  $LoadedModules = Get-Module | Select Name
  if ($LoadedModules -notlike "*$ModuleName*") {
    try {
        Import-Module -Name $ModuleName -ErrorAction Stop
        Write-Msg ("The module DataONTAP is imported")
    }
    catch {
        Write-ErrMsg ("Could not find the Module DataONTAP on this system. Please download from NetApp Support")
        stop-transcript
        exit 
    }
  }
}
########################################################################

## Begin Vserver Setup Process
start-transcript -path $TranscriptPath

Write-Msg  "##### Beginning SVM Setup #####"

Check-LoadedModule -ModuleName DataONTAP

write-host "connect controller $ClusterName "

##Connect to the cluster management node
try {
    Connect-nccontroller $ClusterName -ErrorAction Stop | Out-Null   
    "connected to " + $ClusterName
    }
catch {
    Write-ErrMsg ("Failed connecting to Cluster " + $ClusterName + " : $_.")
    stop-transcript
    exit
}

#Save system info to variables to use in future commands. 

$nodes = (get-ncnode).node
$allnodes = @((get-ncnode).node)
$RootVolume = ($VserverName + "_root")
$VserverRootAggr = get-ncaggr | Where-Object {($_.nodes -eq $nodes[0]) -and ($_.AggrRaidAttributes.HasLocalRoot -eq $false) -and ($_.name -match '_1$')}
$SvmRootAggr = get-ncaggr | Where-Object {$_.nodes -eq "$node" -and $_.AggrRaidAttributes.HasLocalRoot -eq $false -and $_.name -match '_1$'}

## Create vserver
Write-Msg  "+++ Creating SVM +++"
try {
    New-NcVserver -Name $VserverName -RootVolume $RootVolume -NameServerSwitch "file", "ldap" -RootVolumeSecurityStyle "unix" -Language "C" -NameMappingSwitch "file", "ldap" -RootVolumeAggregate $SvmRootAggr -ErrorAction stop | out-null
    "Vserver $VserverName created successfully."
    }
catch {
    write-ErrMsg ("Vserver creation failed with error: $_")
    }
sleep -s 3

##Resizing root volume from standard 1g to 10g and change permissions on the volumes
try{
    Write-Msg  "+++ Resizing root volume and changing volume permissions +++"
    Set-NcVolsize -Name $RootVolume -VserverContext $VserverName -NewSize 10g -ErrorAction stop | out-null
    "Vserver root volume: $RootVolume increased to 10g"
    }
catch {
    write-errmg ("Vserver volume size increase failed with error: $_")
    }
##Query the volume attributes to get the unix permissions
$VsRoot_q = Get-NcVol -Template
Initialize-NcObjectProperty $VsRoot_q VolumeIdAttributes
$VsRoot_q.VolumeIdAttributes.Name = $RootVolume
$VsRoot_q.VolumeIdAttributes.OwningVserverName = $VserverName


$VsRoot_Unix_Perms = Get-NcVol -Template
Initialize-NcObjectProperty $VsRoot_Unix_Perms VolumeSecurityAttributes
Initialize-NcObjectProperty $VsRoot_Unix_Perms.VolumeSecurityAttributes VolumeSecurityUnixAttributes
$VsRoot_Unix_Perms.VolumeSecurityAttributes.VolumeSecurityUnixAttributes.Permissions = "0755"
##
try{
    Update-NcVol -Query $VsRoot_q -Attributes $VsRoot_Unix_Perms -erroraction stop | out-null
    $VolPermissions = (get-ncvol $RootVolume).VolumeSecurityAttributes.VolumeSecurityUnixAttributes.Permissions
    "Vserver root volume permissions set to $VolPermissions"
    }
catch {
    $VolPermissions = (get-ncvol $RootVolume).VolumeSecurityAttributes.VolumeSecurityUnixAttributes.Permissions
    Write-ErrMsg ("Unable to set root volume permissions to $VsRoot_Unix_Perms, current volume permissions are $VolPermissions")
    }
sleep -s 3
	
## Add the NAS protocols to the SVM
Write-Msg  "+++ Adding the NAS protocols to the SVM +++"
try{
    Set-NcVserver -Name $VserverName -AllowedProtocols 'cifs','nfs' -ErrorAction stop | out-null
    "Added NAS protocols to the $VserverName"
    }
catch {
    Write-ErrMsg ("Unable to add NAS protocls to vserver: $_") 
	}
sleep -s 3

## create data lif on each node.
## naming convention loops thourgh the noods and uses the ip address specified in the array.
Write-Msg  "+++ Creating data lif on each node +++"
$x = 0
for ($i = 1 ; $i -le (Get-NcNode).count; $i++) {
        try {

        if ($node_count -lt 10) {
        $LifName = ("data0" + $i)
        }
        else {
        $LifName = ("data" + $i)
        }

        New-NcNetInterface -Name $LifName -Vserver $VserverName -Role "data" -Node $allnodes[$x] -Port $DataLifPort -DataProtocols "nfs","cifs" -Address $TestLifIpAddress[$x] -Netmask $TestLifNetmask -DnsDomain $VsmDnsDomainName -FailoverPolicy "nextavail" -FailoverGroup "data" -AutoRevert $true -ErrorAction stop | out-null
        Write-Msg ("+++ lif $LifName created with ip address " + $TestLifIpAddress[$x] + " +++")
        $x++
        }
        catch {
        Write-ErrMsg ("Unable to create new data lif on $VserverName with error: $_")
        }
}
sleep -s 3

##setup dns on VSM
Write-Msg  "+++ Configuring SVM DNS +++"
New-NcNetDns -Domains $VsmDnsDomainName -NameServers $VsmDnsNameServers -State $enabled -VserverContext $VserverName | out-null
sleep -s 3

##setup ldap
New-NcLdapClient -Name ($VserverName + "_config") -Schema $LdapSchema -Servers $LdapServer -TcpPort 389 -QueryTimeout 10 -MinBindLevel "anonymous" -BindDn "-" -BaseDn "dc=qualcomm,dc=com" -BaseScope "subtree" -UserDn "ou=people,dc=qualcomm,dc=com" -UserScope "onelevel" -GroupDn "ou=unix,ou=groups,dc=qualcomm,dc=com" -GroupScope "onelevel" -NetGroupDn "ou=netgroups,dc=qualcomm,dc=com" -NetGroupScope "onelevel" -VserverContext $VserverName 
New-NcLdapConfig -ClientConfig ($VserverName + "_config") -ClientEnabled true -VserverContext $VserverName
sleep -s 3

##enable nfs on vserver
Write-Msg  "+++ Enabling SVM NFS +++"
Enable-NcNfs -VserverContext $VserverName | out-null
sleep -s 3

<#
##enable cifs on the vserver using an admin account.
Write-Msg  "+++ Enabling SVM CIFS +++"
try {
    Add-NcCifsServer -Name $VserverName -Domain $VsmDnsDomainName -OrganizationalUnit "OU=NetApps,OU=Servers,OU=San Diego" -VserverContext $VserverName -ErrorAction stop | Out-Null
    "Enabled CIFS on the vserver."
    }
catch {
    Write-ErrMsg ("Unable to enable CIFS on the vserver with following error: $_")
    }
sleep -s 3
#>  ##Cifs Setup

##Add network interfaces routing groups
Write-Msg  "+++ Creating network interface routing groups +++"
foreach ($node in $nodes) {
##create the node management routing group
invoke-ncssh "network routing-groups create -vserver " + $node + "-subnet 10.43.154.0/23 -role node-mgmt -metric 10"
##create the intercluster routing group
invoke-ncssh "network routing-groups create -vserver " + $node + "-subnet 10.43.154.0/23 -role intercluster -metric 40"
}

##create backup lif and intercluster snapmirror lif -repeat for all nodes.
Write-Msg  "+++ Creating backup and snapmirror lif on all nodes +++"
$node_count = 1
$ip = 0
foreach ($node in $nodes) {

        $BUipAddress = $BackupLifIpAddress[$ip]
        $SMipAddress = $SMLifIpAddress[$ip]
        if ($node_count -lt 10) {
        $BUinterfaceName = ("bu0" + $node_count)
        $SMinterfaceName = ("sm0" + $node_count)
        }
        else {
        $BUinterfaceName = ("bu" + $node_count)
        $SMinterfaceName = ("sm" + $node_count)
        }

        New-NcNetInterface -Name $BUinterfaceName -Vserver $node -Role "node_mgmt" -Node $node -Port $BackupLifPort -DataProtocols "none" -Address $BUipAddress -Netmask $BackupLifNetmask -FailoverPolicy "nextavail" -FailoverGroup "" -AutoRevert $true -AdministrativeStatus "up" -ErrorAction stop
        New-NcNetInterface -Name $SMinterfaceName -Vserver $node -Role "intercluster" -Node $node -Port $SnapmirrorLifPort -DataProtocols "none" -Address $SMipAddress -Netmask $SMLifNetmask -FailoverPolicy "nextavail" -FailoverGroup "" -AutoRevert $true -AdministrativeStatus "up" -ErrorAction stop

        $BUroutinggroup = $BUipAddress.split('.')
        $BUroutinggroup[-1] = "0"
        $BUroutinggroup -join '.'
        $newBUroutinggroup = ("i" + $BUroutinggroup + "/23")

        $SMroutinggroup = $SMipAddress.split('.')
        $SMroutinggroup[-1] = "0"
        $SMroutinggroup -join '.'
        $newSMroutinggroup = ("n" + $SMroutinggroup + "/23")
        
        New-NcNetRoutingGroupRoute -RoutingGroup $newBUroutinggroup -Vserver $node  -Destination "0.0.0.0/0" -Gateway $SMLifGateway -Metric 40
        New-NcNetRoutingGroupRoute -RoutingGroup $newSMroutinggroup -Vserver $node  -Destination "0.0.0.0/0" -Gateway $BackupLifGateway -Metric 10
        Write-Msg  "+++ Created backup and snapmirror lif on $node +++"
        $node_count++
        $ip++

}

##variables for LS mirror creation
$SourceCluster = $ClusterName
$DestinationCluster = $ClusterName
$SourceVserver = $VserverName
$DestinationVserver = $VserverName
$SourceVolume = ($VserverName + "_root")
$DestinationVolume = ($VserverName + "_root_ls")

##Create LS mirrors on each node of the cluster and initialize them.
$node_count = 1

foreach ($node in $nodes) {
        New-NcVol -Name ($VserverName + "_root_ls" + $node_count) -Aggregate $SvmRootAggr -Type "dp" -VserverContext $VserverName -Size 10g -ErrorAction stop | out-null

        $DestinationVolume = ($VserverName + "_root_ls" + $node_count)
        Write-Msg ("Creating SnapMirror relationship between " + $SourceCluster + ":"+ $SourceVserver + "/"+ $SourceVolume + " and " + $DestinationCluster + ":"+ $DestinationVserver + "/"+ $DestinationVolume )
        New-NcSnapmirror -SourceCluster $SourceCluster -DestinationCluster $DestinationCluster -SourceVserver $SourceVserver -DestinationVserver $DestinationVserver -SourceVolume $SourceVolume -DestinationVolume $DestinationVolume | out-null

        Write-Msg ("Initializing the LS snapmirror relationship")
        Invoke-NcSnapmirrorInitialize -SourceCluster $SourceCluster -DestinationCluster $DestinationCluster -SourceVserver $SourceVserver -DestinationVserver $DestinationVserver -SourceVolume $SourceVolume -DestinationVolume $DestinationVolume | out-null
        $node_count++
}

##create name-mappings on cluster from csv file.
Write-Msg  ("+++ Creating name-mappings on VSM: $VserverName +++")

import-csv "C:\temp\cluster_config_files\name_mappings.csv" | % {

    New-NcNameMapping -Direction $_.direction -Pattern $_.pattern -Replacement $_.replacement -VserverContext $VserverName 
}

Write-Msg ("Updated cluster name mappings with the following settings:")
write-host (Get-NcNameMapping -VserverContext $VserverName)


##modify default export policy from csv file
$index = 1
import-csv "C:\temp\cluster_config_files\export_rules.csv" | % {
    
    New-NcExportRule -policy $_.policy -Index $index -ClientMatch $_.clientmatch -ReadOnlySecurityFlavor $_.readonlysecurityflavor -ReadWriteSecurityFlavor $_.readwritesecurityflavor -Protocol $_.protocol -Anon $_.anon -VserverContext $VserverName
    $index++
}

Write-Msg ("Updated default export policy with the following settings:")
write-host (Get-NcExportRule -Vserver $VserverName  -Policy "default")

##Export policy example 
#PolicyName RuleIndex ClientMatch       Protocol RoRule RwRule Vserver  AnonymousUserId

#---------- --------- -----------       -------- ------ ------ -------  ---------------
#default    1         icepick           {any}    {any}  {any}  snowcone
#default    2         kitchen           {any}    {any}  {any}  snowcone
#default    3         srmagent-sdc-01   {any}    {any}  {any}  snowcone
#default    4         0.0.0.0/0         {any}    {any}  {any}  snowcone 65534           0.0.0.0/0
#default    5         san-pcdc2-a1-4-02 {any}    {any}  {any}  snowcone 65534           san-pcdc2-a1-4-02
#default    6         san-pcdc2-a1-4-01 {any}    {any}  {any}  snowcone 65534           san-qp200-b1-1-01
#default    7         san-pcdc2-a1-4-03 {any}    {any}  {any}  snowcone 65534           san-pcdc2-a1-4-03
#default    8         san-qp200-b1-1-10 {any}    {any}  {any}  snowcone 65534           san-pcdc2-a1-4-10

#Example of powershell implementation.
<#
New-NcExportRule -policy default -Index 1 -ClientMatch icepick -ReadOnlySecurityFlavor any -ReadWriteSecurityFlavor any -Protocol any -Anon 0 -VserverContext chronicle
New-NcExportRule -policy default -Index 2 -ClientMatch kitchen -ReadOnlySecurityFlavor any -ReadWriteSecurityFlavor any -Protocol any -Anon 0 -VserverContext chronicle
New-NcExportRule -policy default -Index 3 -ClientMatch 0.0.0.0/0 -ReadOnlySecurityFlavor any -ReadWriteSecurityFlavor any -Protocol any -Anon 65534 -VserverContext chronicle
#>