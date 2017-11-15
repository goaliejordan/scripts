    Import-Module DataONTAP  
$newfilerIP = 10.58.96.155
$newfilerSubnet = 255.255.255.0
$newfilerGW = 10.58.96.1
	
	#example of how to connect to multiple controllers.
	#to add multiple cluster systems use: connect-nccontroller x.x.x.x -credential -add
	#to add multiple 7-mode systems save as a variable: $d = connect-nacontroller x.x.x.x -transient -credential root
    Connect-NaController $newfiler -Credential root  
    Initialize-NaController -DhcpAddress $newfilerIP -Hostname vSIM01 -PrimaryInterface e0a -PrimaryInterfaceAddress $newfilerIP -PrimaryInterfaceNetmask 255.255.255.0 -Gateway 10.58.96.1 -Password 'Password1' -DnsDomain Sea-tm.netapp.com -DnsServers 10.58.88.21,10.58.88.22  
    get-nadisk  #fails with the new password added
    Add-NaCredential $newfilerIP 
    Connect-NaController $newfilerIP  
    Get-NaDisk  
    Get-NaAggr  
    Get-NaVol  
    Get-NaQtree  
    Get-NaLicense # no licenses are listed on the filer	 
    notepad .\licenses.csv  # create csv with row one code, name
    import-Csv .\licenses.csv  
    Import-Csv .\licenses.csv| Add-NaLicense  
    Get-NaLicense  
    # Working with storage  
    Get-NaDisk|Where-Object {$_.status -eq 'spare'}|Measure-Object   
    Add-NaAggr -Name aggr0 -DiskCount 10  
    # need more spindles...  
    Get-NaDiskOwner  
    Get-NaDiskOwner|?{-NOT $_.Owner}| Set-NaDiskOwner -force  #get any disk that does not have an owner and assign it.
    Set-NaAggrOption -Name aggr0 -Key raidsize -Value 13  
    Add-NaAggr -Name aggr0 -DiskCount 13  
    # Create a new volume.  
    New-NaVol -Name vol1 -Size 10g -Aggregate aggr0 -SpaceReserve none  
    Get-NaSnapshotReserve vol1  
    Set-NaSnapshotReserve vol1 -Percentage 0  
    Get-NaVol vol1| Set-NaSis -Schedule auto| Enable-NaSis| Start-NaSis  #one line for 4 commands
    # Export that volume!  
    Rename-NaVol -Name vol1 -NewName vol5  
    Add-NaNfsExport -Persistent -Path /vol/vol5 -ReadWrite 10.58.96.0/24 -Root 10.58.96.0/24  
    Get-NaNfsExport   
    Get-NaNfsExport | Select-Object -ExpandProperty SecurityRules  
    # use it!  
    Connect-VIServer 10.58.96.67 -User root -Password ''  
    New-Datastore -Name vol5 -Nfs -Path /vol/vol5 -NfsHost 10.58.96.155  
    New-VM -Name VM01 -DiskMB 4096 -DiskStorageFormat thin -MemoryMB 256 -Datastore vol5  
    # What about Windows?    
    Get-NaCifs  
    $creds = Get-Credential 'DOMAIN\Administrator'  
    $date = Invoke-Command -ComputerName 10.58.88.21 -ScriptBlock { get-date } -Credential $creds  
    Set-NaTimezone -Timezone 'US/Pacific-New'  
    Set-NaTime -DateTime $date.ToUniversalTime()  
    Set-NaOption timed.servers '10.58.88.21'  
    Set-NaOption timed.enable on  
    Set-NaCifs -CifsServer vSIM01 -AuthType ad -SecurityStyle multiprotocol -Domain Sea-Tm.netapp.com -Credential $creds  
    Test-NaCifsPasswordGroupFile  
    New-NaCifsGroupFile  
    New-NaCifsPasswordFile  
    Test-NaCifsPasswordGroupFile  
    Set-NaCifs -CifsServer vSIM01 -AuthType ad -SecurityStyle multiprotocol -Domain Sea-Tm.netapp.com -Credential $creds  
    # We're on the domain.  
    Get-NaCifs  
    # Create a share  
    Add-NaCifsShare -Share vol5 -Path /vol/vol5  
    # Getting started...  
    New-NaUser -Credential RDP -FullName 'PUTANAMEHERE' -Comment 'creds for RPC passthrough' -Groups Administrators  
    Get-NaOption cifs*  
    Get-NaOption cifs.smb2.enable | Set-NaOption -OptionValue on  
    Invoke-Item \\10.58.96.155\vol5  
    # host integration  
    Enter-PSSession -ComputerName '10.58.96.102' -Credential XD\administrator  

# Import-module DataONTAP

# $SIM1=Connect-NaController SIM1

# Add-nalicense -Codes GWNTKCL,BCJEAZL,ELNRLTG,MTVVGAF,NAZOMKC,NQBYFJJ,DFVXFJJ,PVOIVFK,PDXMQMI

# set-naoption wafl.optimize_write_once off

# New-NaAggr aggr1 -DiskCount 8

# do { $aggr; $aggr=get-naaggr aggr1} until ($aggr.State -eq "online")

# Set-NaSnapshotReserve aggr1 0 -Aggregate

# foreach ($VOL in @("vol1", "vol2", "vol3", "vol4"))

# {

                # New-NaVol $VOL aggr1 1g
                # set-navoloption $VOL nosnap on
                # set-navoloption $VOL no_atime_update yes
                # set-navoloption $VOL fractional_reserve 0
                # set-nasnapshotreserve  $VOL 0
                # set-nasnapshotschedule $VOL -Weeks 0 -Days 0 -Hours 0
                # get-nasnapshot $VOL | remove-nasnapshot

# }

# Enable-NaIscsi	
	
	
 