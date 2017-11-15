# Creates a VFiler with one root and one data volume
# Sets the snapshot schedule to these volumes and a security style to NTFS
# Adds the VFiler to an AD Domain and creates a local Administrator User
# Creates a fileshare on the data volume
# Version 1.0
# Matthias Rettl, Aug 02 2011 using PowerShell Toolkit v1.5

#Import-Module DataONTAP

$napasswd	= "Bridgepoint1!"		# Password for the Hosting-Filer, the VFiler and the AD Administrator User
$nahost		= "filer02"		# Name of the Hosting Filer
$navfiler	= "profiles01"		# Name of the VFiler (also the NetBIOS Name of the VFiler)
$navfiler_root	= $navfiler	# Name of the root-volume (add suffix "_root" to the VFiler Name)
$navfiler_rsize	= "100m"		# Size of the root-volume
$navfiler_data	= "homedirs"	# Name of the data-volume (add suffix "_data" to the VFiler Name)
$navfiler_dsize	= "4t"		# Size of the data-volume
$navfiler_aggr	= "aggr1"	# Name of the Aggregate containing the root and the data volume
$navfiler_if	= "vif1-profiles01"			# Ethernet-Interface for the VFiler
$navfiler_ip	= "10.10.20.28"	# IP-Address of the VFiler
$navfiler_ipspace = "non-prod" # IPspace to add the vfiler to.
$navfiler_mask	= "255.255.255.0"	# Subnet-Mask of the VFiler
$navfiler_domain= "bridgepoint.local"	# DNS and AD Domain of the VFiler
$navfiler_ns1	= "10.10.10.9"		# Name-Server 1
$navfiler_ns2	= "10.10.10.11"		# Name-Server 2


#Connect-NaController $nahost

New-NaVol $navfiler_root $navfiler_aggr $navfiler_rsize -SpaceReserve none -LanguageCode en_US 
set-navoloption -name $navfiler_root -key nosnap -value on
Set-NaQtree /vol/$navfiler_root -SecurityStyle ntfs
#Set-NaSnapshotSchedule $navfiler_root -Weeks 2 -Days 14 -Hours 8 -WhichHours "6,9,12,15,18,21" 
Set-NaSnapshotReserve -TargetName $navfiler_root -Percentage 0

New-NaVol $navfiler_data $navfiler_aggr $navfiler_dsize -SpaceReserve none -LanguageCode en_US 
set-navoloption -name $navfiler_data -key nosnap -value on
Set-NaQtree /vol/$navfiler_data -SecurityStyle ntfs
#Set-NaSnapshotSchedule $navfiler_data -Weeks 6 -Days 14 -Hours 28 -WhichHours "8,10,12,14,16,18,20" 
##Create new ipspace to add the vfiler to:##
New-NaNetIpspace -name $naVfilerIpspace -interfaces $navfiler_if

New-NaVfiler $navfiler -Addresses $navfiler_ip -Storage $navfiler_root

Set-NaVfilerStorage $navfiler -AddStorage $navfiler_data

$b = New-Object NetApp.Ontapi.Filer.Vfiler73.IpbindingInfo
    $b.Interface = $navfiler_if
    $b.Ipaddress = $navfiler_ip
    $b.Netmask = $navfiler_mask
Set-NaVfilerAddress $navfiler -IpBindingInfo $b

Set-NaVfilerDns $navfiler $navfiler_domain $navfiler_ns1 $navfiler_ns2
Set-NaVfilerPassword $navfiler $napasswd

#Set-NaVfilerProtocol $navfiler -DisallowProtocols nfs,iscsi,rsh
Set-NaVfilerProtocol $navfiler -DisallowProtocols rsh

#$vfiler_password = ConvertTo-SecureString $napasswd -AsPlainText -Force
#$ps_cred = New-Object System.Management.Automation.PSCredential @("root", $vfiler_password)
#Connect-NaController $navfiler_ip -HTTP -Credential $ps_cred

#New-NaUser Administrator $napasswd Administrators

#New-NaCifsPasswordFile
#New-NaCifsGroupFile

#Set-NaCifs -CifsServer $navfiler -AuthType ad -SecurityStyle ntfs -Domain $navfiler_domain -OrganizationalUnit OU=Netapp -User Administrator -Password $napasswd

#Remove-NaCifsShare Home
#Add-NaCifsShare -Share Data -Path /vol/$navfiler_data -Comment "A VFiler CIFS Share"

