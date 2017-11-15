##Powershell Workflow for new Cluster Install
#########################################################################
# Declare Variables
$ClusterName = ""
$VserverName = ""
$mgmtIP = ""
$mgmtSubnet = ""
$mgmtGateway = ""
$ClusterNameMgmtPort = ""
$timeserver = @("time-server1","time-server2")
$timezone = "America/Los_Angeles"
[int]$maxraidsize = 23 #raid group size for creating an aggregate 
$TranscriptPath = "c:\temp\cluster_setup_transcript_$(get-date -format "yyyyMMdd_hhmmtt").txt"
$licensesPath = "c:\temp\licenses.txt" 

# Autosupport Variables
$from = $VserverName + "@qualcomm.com"
$to = "nas.asups@qualcomm.com,qct-ds-notify@qualcomm.com"
$mailhost = "smtphost.qualcomm.com"

#########################################################################
# Declare the functions
function Write-ErrMsg ($msg) {
    $fg_color = "White"
    $bg_color = "Red"
    Write-host ""
    Write-host $msg -ForegroundColor $fg_color -BackgroundColor $bg_color
    Write-host ""
}
function Write-Msg ($msg) {
    $color = "yellow"
    Write-host ""
    Write-host $msg -foregroundcolor $color
    Write-host ""
}
function Invoke-SshCmd ($cmd){
    try {
        Invoke-NcSsh $cmd -ErrorAction stop | out-null
        "The command completed successfully"
    }
    catch {
       Write-ErrMsg "The command did not complete successfully"
    }
}
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
function Create-Aggr {
    Param (
        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true)
        ]
        [string] $Node,
        [int] $RaidSize
    )
    ##these variables should remain the standard for the build
    $BlockType = "64_bit"
    $RaidType = "raid_dp"

    ##change the naming of the node root aggr to meet the standards
    $AggrNodeName = ($node -replace "-0")
    $NewAggrName = ("aggr0_" + $AggrNodeName)
    
    try {
        $RenameAggr = get-ncaggr | Where-Object {$_.nodes -eq "$node" -and $_.AggrRaidAttributes.HasLocalRoot -eq $true } | rename-ncaggr -newname $NewAggrName -erroraction stop
        Write-Host ""
        "Successfully renamed node root aggregate to $NewAggrName"
    }
    catch
        {
        Write-ErrMsg ("Unable to rename node root aggregate with error: $_.") 
    }

    ##change the node name to the naming stadard.
    
    $n = 1  ## ending number in aggr.
    
    ##get all of the disk attributes
    $NodeDisk = (get-ncdisk) | ? {$_.DiskRaidInfo.ContainerType -eq "spare" -and $_.DiskOwnershipInfo.OwnerNodeName -eq $Node}
    
    ##get the number of spare disks owned by the node to use.
    $DiskCount = $NodeDisk.count
    write-host "Spare disk count available for $Node is $DiskCount"
    Write-Host ""

    ##get the type of disk type for the aggr naming.
    $DiskType = $NodeDisk.DiskInventoryInfo.disktype[0].tolower()
    write-host "Disk type for $Node is $DiskType"
    Write-Host ""

    ##get the disk speed for the naming convention.
    $DiskRPM = ([string]($NodeDisk.RPM[0] / 1000 -as [INT]) + "k")
    write-host "Disk RPM for $Node is $DiskRPM"
    Write-Host ""

    write-host "Finished getting disk info for aggregate creation from node $Node"
    Write-Host ""
    
    ##This will be the name of the aggregate.
    $AggrName = $AggrNodeName + "_" + $DiskType + $DiskRpm + "_$n"
   
    if ($DiskType -eq "SAS") {

        $RaidSize = 23

        ## Get the spare drives
        $SpareCount = ($DiskCount % $RaidSize)
        
        while (($DiskCount % $RaidSize) -ne 0) {
            $DiskCount--
        } ##while diskcount
   
        $AggrSettings = @{"Name:" = $Aggrname ; "Number of Disks:" = $DiskCount ; "DiskType:" = $DiskType ; "RaidSize:" = $RaidsizeSAS ; "BlockType:" = $BlockType ; "RaidType:" = $RaidType ; "Spares for node:" = $SpareCount}
        $AggrTable = $AggrSettings | out-string

        Write-Host ""
        write-host "Running Aggregate creation precheck for aggregate: $AggrName....."

           
        try {
            New-NcAggr -Name $AggrName -Node $Node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $RaidSize -BlockType $BlockType -PreCheck -RaidType $RaidType -erroraction Stop | Out-Null
            write-host "Aggregate creation precheck for aggregate: $AggrName successful with no errors"
            Write-Host ""
            write-host "The new aggregate with be created with the following settings:" -ForegroundColor yellow
            write-host "---------------------------------------------------------------"
            write-host $AggrTable -ForegroundColor yellow

            $Title = "Create new aggregate on node $Node"
            $Message = "Do you want to Create a new aggregate for $Node with the listed settings? `n This will leave $Sparecount spares for the node"
 
            $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
            "Creates a new aggregate with settings displayed on the console."
   
            $No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
            "Does not create new aggregate."
   
            $Options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
   
            $Result = $Host.ui.PromptForChoice($Title, $Message, $Options, 0) 
   
            switch ($Result)
            {
             0 {"You selected Yes. Creating Aggregate now with name $AggrName ."
                try{
                    New-NcAggr -Name $AggrName -Node $Node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $Raidsize -BlockType $BlockType -RaidType $RaidType -ErrorAction stop | Out-Null
                    Write-Host ""
                    write-host "Created Aggregate with name $AggrName" -ForegroundColor Yellow
                }
                catch {
                    Write-ErrMsg "Aggregate creation failed for aggregate: $AggrName with error: $_." 
                }
             }
             1 {"You selected No. Aggregate creation aborted"}
             }
        }
        catch {
            Write-ErrMsg "Aggregate creation precheck failed for aggregate: $Aggrname with error: $_."
            Write-Host
        }
     }
     else {

        $RaidSize = 18

        ## Get the spare drives
        $SpareCount = ($DiskCount % $RaidSize)
        
        while (($DiskCount % $RaidSize) -ne 0) {
            $DiskCount--
        } ##while diskcount
   
        $AggrSettings = @{"Name:" = $Aggrname ; "Number of Disks:" = $DiskCount ; "DiskType:" = $DiskType ; "RaidSize:" = $RaidsizeSAS ; "BlockType:" = $BlockType ; "RaidType:" = $RaidType ; "Spares for node:" = $SpareCount}
        $AggrTable = $AggrSettings | out-string

        Write-Host ""
        write-host "Running Aggregate creation precheck for aggregate: $AggrName....."

           
        try {
            New-NcAggr -Name $AggrName -Node $Node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $RaidSize -BlockType $BlockType -PreCheck -RaidType $RaidType -erroraction Stop | Out-Null
            write-host "Aggregate creation precheck for aggregate: $AggrName successful with no errors"
            Write-Host ""
            write-host "The new aggregate with be created with the following settings:" -ForegroundColor yellow
            write-host "---------------------------------------------------------------"
            write-host $AggrTable -ForegroundColor yellow

            $Title = "Create new aggregate on node $Node"
            $Message = "Do you want to Create a new aggregate for $Node with the listed settings? `n This will leave $Sparecount spares for the node"
 
            $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
            "Creates a new aggregate with settings displayed on the console."
   
            $No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
            "Does not create new aggregate."
   
            $Options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
   
            $Result = $Host.ui.PromptForChoice($Title, $Message, $Options, 0) 
   
            switch ($Result)
            {
             0 {"You selected Yes. Creating Aggregate now with name $AggrName ."
                try{
                    New-NcAggr -Name $AggrName -Node $Node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $Raidsize -BlockType $BlockType -RaidType $RaidType -ErrorAction stop | Out-Null
                    Write-Host ""
                    write-host "Created Aggregate with name $AggrName" -ForegroundColor Yellow
                }
                catch {
                    Write-ErrMsg "Aggregate creation failed for aggregate: $AggrName with error: $_." 
                }
             }
             1 {"You selected No. Aggregate creation aborted"}
             }
         }
        catch {
            Write-ErrMsg "Aggregate creation precheck failed for aggregate: $Aggrname with error: $_."
            Write-Host
         }
     }
}
########################################################################
# Begin Cluster Setup Process
start-transcript -path $TranscriptPath

Write-Msg  "##### Beginning Cluster Setup #####"

Check-LoadedModule -ModuleName DataONTAP

try {
    Connect-nccontroller $ClusterName -ErrorAction Stop | Out-Null   
    "connected to " + $ClusterName
    }
catch {
    Write-ErrMsg ("Failed connecting to Cluster " + $ClusterName + " : $_.")
    stop-transcript
    exit
}

##get the nodes in the cluster
$nodes = (get-ncnode).node

#rename the nodes after they have been joined to the cluster
Write-Msg  "+++ Renaming Node SVMs +++"
foreach ($node in $nodes) { 
    Rename-NcNode -node $node -newname ($node -replace "-mgmt") -Confirm:$false |Out-Null
} 
Get-NcNode |select Node,NodeModel,IsEpsilonNode | Format-Table -AutoSize

$nodes = (get-ncnode).node

##create failover group cluster_mgmt and add the interfaces to the group.
Write-Msg  "+++ Create failover group cluster_mgmt and add the interfaces to the group +++"
foreach ($node in $nodes) {
    $FG_Clus = Invoke-NcSsh "net int failover-groups create -failover-group cluster_mgmt -node " $node " -port " $ClusterNameMgmtPort
    if (($FG_Clus.Value.ToString().Contains("Error")) -or ($FG_Clus.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($FG_Clus.Value)
    }
    else {
        Write-Host ("Created failover-group cluster_mgmt on node " + $node)
        Write-Host ""
    }
}

Set-NcNetInterface -Name cluster_mgmt -Vserver $ClusterName -FailoverPolicy nextavail -FailoverGroup cluster_mgmt | Out-Null
Get-NcNetInterface -Name cluster_mgmt  | select InterfaceName,FailoverGroup

sleep -s 15
##add licenses to cluster
Write-Msg "+++ Adding license +++"

$test_lic_path = Test-Path -Path $licensesPath
if ($test_lic_path -eq "True") {
    $count_licenses = (get-content $licensesPath).count
    if ($count_licenses -ne 0) {
        Get-Content $licensesPath |  foreach { Add-NcLicense -license $_ }
        Write-Host "Licenses successfully added"
        Write-Host ""
    }
    else {
        Write-ErrMsg ("License file is empty. Please add the licenses manually")
    }

}
else {
    Write-ErrMsg ("License file does not exist. Please add the licenses manually")
        
}

sleep -s 15
##configure storage failover
Write-Msg  "+++ Configure SFO +++"

if ($nodes.count -gt 2) {
    foreach ($node in $nodes) {
        $sfo_enabled = Invoke-NcSsh "storage failover modify -node " $node " -enabled true"
        if (($sfo_enabled.Value.ToString().Contains("Error")) -or ($sfo_enabled.Value.ToString().Contains("error"))) {
            Write-ErrMsg ($sfo_enabled.Value)
        }
        else {
            Write-Host ("Storage Failover is enabled on node " + $node)
        }

	    $sfo_autogive = Invoke-NcSsh "storage failover modify -node " $node " -auto-giveback true"
        if (($sfo_autogive.Value.ToString().Contains("Error")) -or ($sfo_autogive.Value.ToString().Contains("error"))) {
                Write-ErrMsg ($sfo_autogive.Value)
        }
        else {
            Write-Host ("Storage Failover option auto giveback is enabled on node " + $node)
            Write-Host ""
        }

        sleep -s 2
    }
}
elseif ($nodes.count -eq 2) {
    foreach ($node in $nodes) {
        $sfo_enabled = Invoke-NcSsh "cluster ha modify -configured true"
        if (($sfo_enabled.Value.ToString().Contains("Error")) -or ($sfo_enabled.Value.ToString().Contains("error"))) {
            Write-ErrMsg ($sfo_enabled.Value)
        }
        else {
            Write-Host ("Cluster ha is enabled on node " + $node)
            Write-Host
        }  
    }
}
else {
    Write-Host "No HA required for single node cluster. Continuing with the setup"
    Write-Host ""
}

sleep -s 15
#unlock the diag user
Write-Msg "+++ Unlock the diag user +++"
try {
    Unlock-NcUser -username diag -vserver $ClusterName -ErrorAction stop |Out-Null
    Write-Host "Diag user is unlocked"
}
catch {
    Write-ErrMsg "Diag user is either unlocked or script could not unlock the diag user"
}
#setup diag user password
Set-Ncuserpassword -UserName diag -password Jbod4you -vserver $ClusterName | Out-Null


sleep -s 15
##enable web access and other services on vservers
Write-Msg "+++ Setup web services on the SVMs +++"
foreach ($node in $nodes) {
    Invoke-NcSsh "vserver services web modify -name spi|ontapi|compat -vserver " $node " -enabled true" | Out-Null
}
Invoke-NcSsh "vserver services web access create -name spi -role admin -vserver " $ClusterName | Out-Null
Invoke-NcSsh "vserver services web access create -name ontapi -role admin -vserver " $ClusterName | Out-Null
Invoke-NcSsh "vserver services web access create -name compat -role admin -vserver " $ClusterName | Out-Null


sleep -s 15
##create admin user for access to logs through http.
Write-Msg "+++ create web log user +++"
Set-NcUser -UserName admin -Vserver $ClusterName -Application http -role admin -AuthMethod password | Out-Null


sleep -s 15
##set Date and NTP on each node
Write-Msg  "+++ setting Timezones/NTP/Datetime +++"
$datetime = Get-Date

foreach ($node in $nodes) {
    #Set-NcTime -Node $node -DateTime $datetime | Out-Null
    Write-Host "$node"
    foreach ($tserver in $timeserver) {
        $ntp_cmd = Invoke-NcSsh "system services ntp server create -node " $node  " -server "  $tserver
        if (($ntp_cmd.Value.ToString().Contains("Error")) -or ($ntp_cmd.Value.ToString().Contains("error"))) {
            Write-ErrMsg ($ntp_cmd.Value)
        }
        else {
            Write-Host ("Successfully set NTP server " + $tserver)
        }
    }
    Write-Host ""
}


sleep -s 15
##configure autosupport

Write-Msg  "+++ Configuring ASUP and testing +++"

foreach ($node in $nodes) {
    $setup_asup = Invoke-NcSsh "system node autosupport modify -node " $node " -state enable -mail-hosts " $mailhost " -from " $from " -to " $to " -support enable -transport https"
    
    if (($setup_asup.Value.ToString().Contains("Error")) -or ($setup_asup.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($setup_asup.Value)
    }
    else {
        Write-Host ("Successfully modified ASUP options for " + $node)
    }

    try {
        Invoke-NcAutosupport -node $node -message "system test" -type all | Out-Null
        "Autosupport invoked from node " + $node
        Write-Host ""
    }
    catch {
        Write-ErrMsg ("Autosupport failed on node : " + $node + " : $_.")
    }
}

sleep -s 15
##create 2 ifgroups and add 2 ports to each one.
Write-Msg  "+++ starting ifgroup creation +++"
foreach ($node in $nodes) {
    try {
        New-NcNetPortIfgrp -Name a0a -Node $node -DistributionFunction port -Mode multimode_lacp -ErrorAction Stop | Out-Null
        Add-NcNetPortIfgrpPort -name a0a -node $node -port e7a -ErrorAction Continue | Out-Null
        Add-NcNetPortIfgrpPort -name a0a -node $node -port e13a -ErrorAction Stop | Out-Null
        Write-Host ("Successfully created ifgrp a0a on node " + $node)
    }
    catch {
        Write-ErrMsg ("Error exception in ifgrp a0a " + $node + " : $_.")
    }

    try {
        New-NcNetPortIfgrp -Name a0b -Node $node -DistributionFunction port -Mode multimode_lacp -ErrorAction Stop | Out-Null
        Add-NcNetPortIfgrpPort -name a0b -node $node -port e7b -ErrorAction Continue | Out-Null
        Add-NcNetPortIfgrpPort -name a0b -node $node -port e13b -ErrorAction Stop | Out-Null
        Write-Host ("Successfully created ifgrp a0b on node " + $node)
        Write-Host ""
    }
    catch {
        Write-ErrMsg ("Error exception in ifgrp a0b " + $node + " : $_.")
    }
}

sleep -s 15
##enable cdpd on all of the nodes
Write-Msg  "+++ enable cdpd on nodes +++"
foreach ($node in $nodes) {
    $cdpd_cmd = Invoke-NcSsh "node run -node " $node " -command options cdpd.enable on"
    if (($cdpd_cmd.Value.ToString().Contains("Error")) -or ($cdpd_cmd.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($cdpd_cmd.Value)
    }
    else {
        Write-Host ("Successfully modified cdpd options for " + $node)
    }
}

sleep -s 15
##create failover groups and add the interfaces to the group.
Write-Msg  "+++ Create failover groups and add the interfaces to the group +++"
foreach ($node in $nodes) {
    $FG_data = Invoke-NcSsh "net int failover-groups create -failover-group data -node " $node " -port a0a"
    if (($FG_data.Value.ToString().Contains("Error")) -or ($FG_data.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($FG_data.Value)
    }
    else {
        Write-Host ("Successfully created failover-group data on node " + $node)
    }

    $FG_backup = Invoke-NcSsh "net int failover-groups create -failover-group backup -node " $node " -port a0b"  
    if (($FG_backup.Value.ToString().Contains("Error")) -or ($FG_backup.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($FG_backup.Value)
    }
    else {
        Write-Host ("Successfully created failover-group data on node " + $node)
        Write-Host ""
    }           
}

sleep -s 15
# set option disk.auto_assign on
Write-Msg  "+++ Setting disk autoassign +++"
foreach ($node in $nodes) {
    $set_disk_auto = Invoke-NcSsh "node run -node " $node " -command options disk.auto_assign on"
    if (($set_disk_auto.Value.ToString().Contains("Error")) -or ($set_disk_auto.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($set_disk_auto.Value)
    }
    else {
        Write-Host ("Successfully modified disk autoassign option on node " + $node)
    }   
}

sleep -s 15
##set ndmp options
Write-Msg  "+++ Setting ndmp node-scope options +++"
$set_nodescope = Invoke-NcSsh "system services ndmp node-scope on"
if (($set_nodescope.Value.ToString().Contains("Error")) -or ($set_nodescope.Value.ToString().Contains("error"))) {
    Write-ErrMsg ($set_nodescope.Value)
}
else {
    Write-Host "ndmp node-scope is enabled on the cluster"
}   

sleep -s 15
##set tape reservations
Write-Msg  "+++ Setting tape reservations +++"
foreach ($node in $nodes) {
	$set_tape_reservation = Invoke-NcSsh "node run -node " $node " -command options tape.reservations persistent"
	if (($set_tape_reservation.Value.ToString().Contains("Error")) -or ($set_tape_reservation.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($set_tape_reservation.Value)
    }
    else {
        Write-Host ("tape reservations set to persistent on node " + $node)
    } 
}

Write-Msg  "+++ Setting IP TCP fcreset threshold +++"
foreach ($node in $nodes) {
	$set_ip_tcp = Invoke-NcSsh "node run -node " $node " -command options ip.tcp.fcreset_thresh_high 1500"
	if (($set_ip_tcp.Value.ToString().Contains("Error")) -or ($set_ip_tcp.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($set_ip_tcp.Value)
    }
    else {
        Write-Host ("IP TCP fcreset is set on node " + $node)
    } 
}

sleep -s 15
# ##set flexscale options

Write-Msg  "+++ Setting flexscale options +++"
foreach ($node in $nodes) {
	$flexscale_enable = Invoke-NcSsh "node run -node " $node " -command options flexscale.enable on" 
    if (($flexscale_enable.Value.ToString().Contains("Error")) -or ($flexscale_enable.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($flexscale_enable.Value)
    }
    else {
        Write-Host ("options flexscale.enable set to on for node " + $node)
    } 

	$flexscale_lopri = Invoke-NcSsh "node run -node " $node " -command options flexscale.lopri_blocks on"
    if (($flexscale_lopri.Value.ToString().Contains("Error")) -or ($flexscale_lopri.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($flexscale_lopri.Value)
    }
    else {
        Write-Host ("options flexscale.lopri_blocks set to on for node " + $node)
    } 

	$flexscale_data = Invoke-NcSsh "node run -node " $node " -command options flexscale.normal_data_blocks on"
    if (($flexscale_data.Value.ToString().Contains("Error")) -or ($flexscale_data.Value.ToString().Contains("error"))) {
        Write-ErrMsg ($flexscale_data.Value)
    }
    else {
        Write-Host ("options flexscale.normal_data_blocks set to on for node " + $node)
        Write-Host ""
    } 

}

sleep -s 15
##disable flowcontrol on all of the ports

Write-Msg  "+++ Setting flowcontrol +++"
foreach ($node in $nodes) {
    try {
        get-ncnetport | Where-Object {$_.Port -notlike "a0*"} | select-object -Property name, node | set-ncnetport -flowcontrol none -ErrorAction Stop | Out-Null
        Write-Host $node
        Get-NcNetPort | Select-Object -Property Name,AdministrativeFlowcontrol | Format-Table -AutoSize
    }
    catch {
        Write-ErrMsg ("Error setting flowcontrol on node " + $node + ": $_.")
    }
}

##create data aggregates on the nodes
Write-Msg  "+++ Create Aggregates +++"
foreach ($node in $nodes) {
    Create-Aggr -Node $node -RaidSize $maxraidsize
}
Write-Msg  "+++ Ending script +++"

stop-transcript
