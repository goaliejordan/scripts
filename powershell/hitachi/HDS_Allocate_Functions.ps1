<#
.Synopsis
   Uses Hitachi Raidcom to create hostgroup, volumes and luns on the HUS-VM.
.DESCRIPTION
   This script utilizes the HDS Raidcom CLI to add a list of volumes to the HDS Array.
   The script needs to run on a system that has a command device connect to the HUS-VM.
   The raidcom commands need to run with Administrator privileges for them to succeed.
   Obtain info for each volume parameter in the csv for the commands to run correctly.
   
   If the hostname in the csv is not listed on the HUS-VM then the hostgroup is created.
    -The wwn of the host are added if they are in the csv.

   If no dp pool is specified in the csv then no volume is created 
   Only the hostgroup is added and then it skips to the next line.
   
   #Version 1.0

   Example "Provision-Volume -hostname bn00storag001 -pool 3 -capacity 3g -label test -ports cl7-c, cl7-d -hostmode windows -wwns 20:00:00:25:b5:00:0b:3b, 20:00:00:25:b5:00:0a:3b"
           "Provision-Volume -CsvPath C:\temp\create_volumes.csv" 
#>

function check-lockstatus{
    $lock_check = "raidcom get resource"
    $lock_status = Invoke-Expression $lock_check
    $status = $lock_status[1].split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
    if ($status[2] -like "Unlocked"){
        return
        }
    else {Write-ErrMsg ("The array is currently Locked by " + $status[3] + " on host " + $status[4] + ". The script can not continue.")
        exit    
    }
}

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

function Get-NextVolumeID{

            Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$pool
            )
                        
            $avail_volume = "raidcom get ldev -ldev_list dp_volume -pool_id" + " " + $pool
            $volumes = invoke-expression $avail_volume | select-string "LDEV :"
            #Notice the -4 is only for our environmnet
            $new_volume = ([string]$volumes[-4]).replace("LDEV : ", "")
            $volume_id = [int]$new_volume + 1
            return $volume_id
}

function Create-Volume{
[cmdletbinding()]
Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$pool,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            HelpMessage="Enter a valid volume size in M, G, or T")]
            [ValidatePattern('[MmGgTt]$')]
            [String]$capacity,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$label,
            [ValidateRange(2,20)]
            [Int]$NumberOfVolumes=1       
            )
            $label_tag = 1
            $volume_count = 1

#Get available volume numbering:
    if ($NumberOfVolumes -gt 1){
        while ($volume_count -le $NumberOfVolumes){
            $volume_count++

            $script:volume_id = Get-NextVolumeID -pool $pool

            #Create the volumes
            $create = "raidcom add ldev -pool" + " " + $pool + " -ldev_id " + $volume_id + " -capacity " + $capacity
            try { 
                invoke-expression $create -ErrorAction stop
                sleep 30
                write-msg ("Created volume $volume_id with size of $capacity.")
                }
            catch {
                Write-ErrMsg ("Unable to create volume with error: $_.")
                }

            #Label the volume:
            $set_label = "raidcom modify ldev -ldev_id" + " " + $volume_id + " -ldev_name " + $label + "_" + [string]$label_tag
            invoke-expression $set_label
            sleep 5
            $label_tag++
        
        } #end while loop
    } #end if for $NumberOfVolumes
    else {
        $script:volume_id = Get-NextVolumeID -pool $pool

        #Create the volumes
        $create = "raidcom add ldev -pool" + " " + $pool + " -ldev_id " + $volume_id + " -capacity " + $capacity
        try { 
            invoke-expression $create -ErrorAction stop
            sleep 30
            write-msg ("Created volume $volume_id with size of $capacity.")
            }
        catch {
            Write-ErrMsg ("Unable to create volume with error: $_.")
            }
     #Label the volume:
            $set_label = "raidcom modify ldev -ldev_id" + " " + $volume_id + " -ldev_name " + $label
            invoke-expression $set_label
            sleep 5
                  
        
    }#end else
} #end of Create-Volume

function Validate-CreateVolume{
[cmdletbinding()]
Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$pool,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            HelpMessage="Enter a valid volume size in M, G, or T")]
            [ValidatePattern('[MmGgTt]$')]
            [String]$capacity,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$label,
            [ValidateRange(2,20)]
            [Int]$NumberOfVolumes=1       
            )
            $label_tag = 1
            $volume_count = 1

#Get available volume numbering:
    if ($NumberOfVolumes -gt 1){
        while ($volume_count -le $NumberOfVolumes){
            $volume_count++

            try{
                $script:volume_id = Get-NextVolumeID -pool $pool -ErrorAction SilentlyContinue
                }
            catch{
                $script:volume_id = "VolumeId"
            }

            #Create the volumes
            $create = "raidcom add ldev -pool" + " " + $pool + " -ldev_id " + $volume_id + " -capacity " + $capacity
            try { 
                write-host ($create)
                }
            catch {
                Write-ErrMsg ("Unable to create volume with error: $_.")
                }

            #Label the volume:
            $set_label = "raidcom modify ldev -ldev_id" + " " + $volume_id + " -ldev_name " + $label + "_" + [string]$label_tag
            write-host ($set_label)
            $label_tag++
        
        } #end while loop
    } #end if for $NumberOfVolumes
    else {
        try{
                $script:volume_id = Get-NextVolumeID -pool $pool -ErrorAction SilentlyContinue
                }
            catch{
                $script:volume_id = "VolumeId"
            }

        #Create the volumes
        $create = "raidcom add ldev -pool" + " " + $pool + " -ldev_id " + $volume_id + " -capacity " + $capacity
        try { 
            write-host ($create)
            }
        catch {
            Write-ErrMsg ("Unable to create volume with error: $_.")
            }
            
        $set_label = "raidcom modify ldev -ldev_id" + " " + $volume_id + " -ldev_name " + $label
        write-host ($set_label)   
    }#end else
} #end of Validate-CreateVolume

function Create-HostGroup{
        [cmdletbinding()]
        Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$ports,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$hostname,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [ValidateSet('windows','windows-cluster','linux','linux-cluster','vmware','solaris','solaris-cluster')] #available hostmode options
            [String[]]$hostmode            
            )

#set the hostmode and hostmode options based on parameter of $hostmode
switch($hostmode){
    "windows"{$hostmode_option = "WIN_EX -host_mode_opt 40"}
    "windows-cluster"{$hostmode_option = "WIN_EX -host_mode_opt 2 40"}
    "linux"{$hostmode_option = "LINUX/IRIX"}
    "linux-cluster"{$hostmode_option = "LINUX/IRIX -host_mode_opt 2"}
    "vmware"{$hostmode_option = "VMWARE_EX -host_mode_opt 54 63"}
    "solaris"{$hostmode_option = "SOLARIS"}
    "solaris-cluster"{$hostmode_option = "SOLARIS -host_mode_opt 2"}
    }
foreach ($server in $hostname){
    foreach ($port in $ports){
        $check_hostgroup = "raidcom get host_grp -port" + " " + $port
            if (-Not (invoke-expression $check_hostgroup | select-string "($server\b)")) {
                #Create Hostgroup on Hitachi
                $add_hostgroup = "raidcom add host_grp -port" + " " + $port + " -host_grp_name " + $server
                invoke-expression $add_hostgroup
                sleep 10
            
                #Add the hostmode option to the hostgroup
                $modify_hostgroup = "raidcom modify host_grp -port" + " " + $port + " " + $server + " -host_mode " + $hostmode_option
                invoke-expression $modify_hostgroup
                sleep 5
                Write-Msg ("Created hostgroup $server on port $port with hostmode $hostmode_option")
                    } #end if hostgroup check
            else {Write-Msg ("Hostgroup $server already exists on port $port")}
        } #end foreach $port
    } #end foreach $server
} #end Create-Hostgroup function

function Validate-CreateHostGroup{
        [cmdletbinding()]
        Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$ports,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$hostname,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [ValidateSet('windows','windows-cluster','linux','linux-cluster','vmware','solaris','solaris-cluster')] #available hostmode options
            [String[]]$hostmode            
            )

#set the hostmode and hostmode options based on parameter of $hostmode
switch($hostmode){
    "windows"{$hostmode_option = "WIN_EX -host_mode_opt 40"}
    "windows-cluster"{$hostmode_option = "WIN_EX -host_mode_opt 2 40"}
    "linux"{$hostmode_option = "LINUX/IRIX"}
    "linux-cluster"{$hostmode_option = "LINUX/IRIX -host_mode_opt 2"}
    "vmware"{$hostmode_option = "VMWARE_EX -host_mode_opt 54 63"}
    "solaris"{$hostmode_option = "SOLARIS"}
    "solaris-cluster"{$hostmode_option = "SOLARIS -host_mode_opt 2"}
    }
foreach ($server in $hostname){
    foreach ($port in $ports){
       
                #Create Hostgroup on Hitachi
                $add_hostgroup = "raidcom add host_grp -port" + " " + $port + " -host_grp_name " + $server
                Write-host ($add_hostgroup)
            
                #Add the hostmode option to the hostgroup
                $modify_hostgroup = "raidcom modify host_grp -port" + " " + $port + " " + $server + " -host_mode " + $hostmode_option
                Write-host ($modify_hostgroup)
        } #end foreach $port
    } #end foreach $server
} #end Validate-CreateHostgroup function

function Add-WWNtoPort{
        [cmdletbinding()]
        Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$hostname,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$ports,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$wwns
            )

            $port_map = @{}

foreach ($port in $ports){
        foreach ($wwn in $wwns){
                $wwn_clean = $wwn.replace(" ","").replace(":","") 
                switch($port[-3]){
                    {($_ -like "1") -or ($_ -like "2") -or ($_ -like "7") }{switch($port[-1]){
                                                                                {($_ -like "a") -or ($_ -like "c")}{switch($wwn_clean[-3]){
                                                                                                                        "a"{$port_map.add($port,$wwn_clean)}
                                                        }}
                                                                                {($_ -like "b") -or ($_ -like "d")}{switch($wwn_clean[-3]){
                                                                                                                        "b"{$port_map.add($port,$wwn_clean)}
                                                        }}
             
                    }}
                    "8"{switch($port[-1]){
                        {($_ -like "a") -or ($_ -like "c")}{switch($wwn_clean[-3]){
                                                            "b"{$port_map.add($port,$wwn_clean)}
                                                        }}
                        {($_ -like "b") -or ($_ -like "d")}{switch($wwn[-3]){
                                                            "a"{$port_map.add($port,$wwn_clean)}
                                                        }}

                    }}
} #end switch
} #end foreach $wwn
} #end foreach $port

foreach ($port in $ports){
#Add the wwn for each port from the hashtable
$add_wwn = "raidcom add hba_wwn -port" + " " + $port + " " + $hostname + " -hba_wwn " + $port_map.$port #use $port_map.$port for hashtable
invoke-expression $add_wwn
sleep 5
          
#Set the nickname of the hostgroup to the hostname
$add_wwn_nickname = "raidcom set hba_wwn -port" + " " + $port + " " + $hostname + " -hba_wwn " + $port_map.$port + " -wwn_nickname " + $hostname
invoke-expression $add_wwn_nickname
sleep 5
 
Write-Msg ("Added $hostname hostgroup to port $port and mapped wwn:" + $port_map.$port + " to it.")
    } #end foreach $port
    $port_map = $null
} #end Add-WWNtoPort function

function Validate-AddWWNtoPort{
        [cmdletbinding()]
        Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$hostname,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$ports,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$wwns
            )

            $port_map = @{}

foreach ($port in $ports){
        foreach ($wwn in $wwns){
                $wwn_clean = $wwn.replace(" ","").replace(":","") 
                switch($port[-3]){
                    {($_ -like "1") -or ($_ -like "2") -or ($_ -like "7") }{switch($port[-1]){
                                                                                {($_ -like "a") -or ($_ -like "c")}{switch($wwn_clean[-3]){
                                                                                                                        "a"{$port_map.add($port,$wwn_clean)}
                                                        }}
                                                                                {($_ -like "b") -or ($_ -like "d")}{switch($wwn_clean[-3]){
                                                                                                                        "b"{$port_map.add($port,$wwn_clean)}
                                                        }}
             
                    }}
                    "8"{switch($port[-1]){
                        {($_ -like "a") -or ($_ -like "c")}{switch($wwn_clean[-3]){
                                                            "b"{$port_map.add($port,$wwn_clean)}
                                                        }}
                        {($_ -like "b") -or ($_ -like "d")}{switch($wwn[-3]){
                                                            "a"{$port_map.add($port,$wwn_clean)}
                                                        }}

                    }}
} #end switch
} #end foreach $wwn
} #end foreach $port

foreach ($port in $ports){
#Add the wwn for each port from the hashtable
$add_wwn = "raidcom add hba_wwn -port" + " " + $port + " " + $hostname + " -hba_wwn " + $port_map.$port #use $port_map.$port for hashtable
write-host ($add_wwn)           
#Set the nickname of the hostgroup to the hostname
$add_wwn_nickname = "raidcom set hba_wwn -port" + " " + $port + " " + $hostname + " -hba_wwn " + $port_map.$port + " -wwn_nickname " + $hostname
Write-host ($add_wwn_nickname)

} #end foreach $port
$port_map = $null
} #end Validate-AddWWNtoPort function

function Get-LunNumber{
        [cmdletbinding()]
        Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$ports,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$hostname,
            [Switch]$NextAvailable
            )

    #Get available lun number if switch is added:    
        if ($NextAvailable){
        $find_avail_lun = "raidcom get lun -port" + " " + $ports[0] + " " + $hostname[0]
        $find_lun = invoke-expression $find_avail_lun | select-string $ports[0] -ErrorAction stop
        $lun_counts = @()
        foreach ($lun in $find_lun) {
            $lun_counts += , ([string]$lun).split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
        }
        $lun_number = [int]($lun_counts[-1][3]) + 1

        #returns the next available lun number.
        return $lun_number
        }
        else {foreach ($server in $hostname){
        foreach ($port in $ports){
        $find_avail_lun = "raidcom get lun -port" + " " + $port + " " + $server
        invoke-expression $find_avail_lun | select-string $ports
            }
        }
    }
} #end Get-LunNumber function

function Validate-GetLunNumber{
        [cmdletbinding()]
        Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$ports,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$hostname,
            [Switch]$NextAvailable
            )

    #Get available lun number if switch is added:    
        if ($NextAvailable){
        $find_avail_lun = "raidcom get lun -port" + " " + $ports[0] + " " + $hostname[0]
        $find_lun = invoke-expression $find_avail_lun | select-string $ports[0] -ErrorAction SilentlyContinue
        $lun_counts = @()
        foreach ($lun in $find_lun) {
            $lun_counts += , ([string]$lun).split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
        }
        $lun_number = [int]($lun_counts[-1][3]) + 1

        #returns the next available lun number.
        return $lun_number
        }# end if for $NextAvailable
        else {foreach ($server in $hostname){
        foreach ($port in $ports){
        $find_avail_lun = "raidcom get lun -port" + " " + $port + " " + $server
        Write-host ($find_avail_lun)
            }
        }
    }#end else
} #end Validate-GetLunNumber function

function Map-LunToHost{
            [cmdletbinding()]
#Map volume to host as lun:
            Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$ports,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$hostname,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$volume_id,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$lun_number       
            )

            foreach ($server in $hostname){
            foreach ($port in $ports){
            $map = "raidcom add lun -port" + " " + $port + " " + $server + " -ldev_id " + $volume_id + " -lun_id " + $lun_number                
            try {
	            invoke-expression $map -ErrorAction Stop
                sleep 10               
                write-msg ("Mapped volume $volume_id to $server with lun id $lun_number.")
                }
            catch{
                Write-ErrMsg ("Unable to map volume $volume_id with error: $_.")
                
            }
        } #end foreach $port
    } #end foreach $server
} #end Map-LunToHost function

function Validate-MapLunToHost{
            [cmdletbinding()]
#Map volume to host as lun:
            Param(
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$ports,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String[]]$hostname,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$volume_id,
            [parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [String]$lun_number       
            )

            foreach ($server in $hostname){
            foreach ($port in $ports){
            $map = "raidcom add lun -port" + " " + $port + " " + $server + " -ldev_id " + $volume_id + " -lun_id " + $lun_number                
            try {               
                write-host ($map)
                }
            catch{
                Write-ErrMsg ("Unable to map volume $volume_id with error: $_.")
            }
        } #end foreach $port
    } #end foreach $server
} #end Validate-MapLunToHost function

function Provision-Volume {
    [CmdletBinding(DefaultParameterSetName="Allocate")]
    Param(

        [parameter(ValueFromPipeline=$true,Mandatory=$true,ParameterSetName="Allocate")]
        [String]$hostname,
        [parameter(ValueFromPipeline=$true,Mandatory=$true,ParameterSetName="Allocate")]
        [String]$pool,
        [parameter(ValueFromPipeline=$true,Mandatory=$true,ParameterSetName="Allocate")]
        [String]$capacity,
        [parameter(ValueFromPipeline=$true,Mandatory=$true,ParameterSetName="Allocate")]
        [String]$label,
        [parameter(ValueFromPipeline=$true,Mandatory=$true,ParameterSetName="Allocate")]
        [String[]]$ports,
        [parameter(ValueFromPipeline=$true,Mandatory=$true,ParameterSetName="Allocate")]
        [String]$hostmode,
        [parameter(ValueFromPipeline=$true,Mandatory=$true,ParameterSetName="Allocate")]
        [String[]]$wwns,
        [ValidateScript({Test-Path -Path $_})]
        [String]$CsvPath, #imports all variables from a CSV file
        [Switch]$Commit #without $commit it only prints out the commands that will be used for provisioning.

        )

try{ 
    Check-Lockstatus -erroraction continue
   }
catch{ 
    Write-ErrMsg ("Unable to connect to RAIDCOM to check status with error: $_") 
   }

#If the commit switch was not enabled it will not provision.
    if(!$Commit){
                    Write-Msg ("Validating command output")
                    Write-Msg ("No changes will be made without the -Commit parameter set.")
                    sleep -Seconds 4
                    if ($CsvPath){
                        write-msg ("Using imported CSV file for volume creation.")
                        import-csv $CsvPath | foreach {
                        $pool = $_.dp_pool_id
                        $capacity = $_.capacity
                        $hostname = $_.hostname
                        $label = $_.volume_label
                        $ports = $_.mapped_ports.replace(" ","").split(",")
                        $hostmode = $_.hostmode
                        $wwns = $_.wwn.replace(" ","").replace(":","").split(",")
                        $all_values = @($pool, $capacity, $hostname, $label, $ports, $hostmode, $wwns)
                        foreach ($value in $all_values){
                        if(-not $value){write-errmsg "Missing entry in CSV file" -ForegroundColor yellow
                            write-msg "Please fill in all cells in the csv and try again" -ForegroundColor Yellow
                            break
                            } #end if for csv value check
                        } #end for $value check

                        #Provision storage for each line in the CSV.
                        Write-Msg ("Commands to create Volumes")
                        Validate-CreateVolume -pool $pool -capacity $capacity -label $label -ErrorAction continue
                        
                        #Create the hostgroup if it is not created already
                        Write-Msg ("Commands to create Hostgroups")
                        Validate-CreateHostGroup -ports $ports -hostname $hostname -hostmode $hostmode

                        #Add wwns to Port
                        Write-Msg ("Commands to add wwn to port")
                        Validate-AddWWNtoPort -ports $ports -hostname $hostname -wwns $wwns

                        #Get the next lun number in the sequence
                        try{
                        $lun_number = Validate-GetLunNumber -ports $ports -hostname $hostname -NextAvailable -ErrorAction SilentlyContinue
                        }
                        catch{
                        $lun_number = "LunNumber"
                        }
                        #Map the new lun to the host
                        write-msg ("Commands to map lun to host")
                        Validate-MapLunToHost -ports $ports -hostname $hostname -volume_id $volume_id -lun_number $lun_number
            }#end if foreach csv value
        } #end if for $CsvPath
                    else{
                        
                        Write-Msg ("Commands to create Volumes")
                        Validate-CreateVolume -pool $pool -capacity $capacity -label $label -ErrorAction stop

                        #Create the hostgroup if it is not created already
                        Write-Msg ("Commands to create Hostgroups")
                        Validate-CreateHostGroup -ports $ports -hostname $hostname -hostmode $hostmode

                        #Add wwns to Port
                        Write-Msg ("Commands to add wwn to port")
                        Validate-AddWWNtoPort -ports $ports -hostname $hostname -wwns $wwns

                        #Get the next lun number in the sequence
                        try{
                        $lun_number = Validate-GetLunNumber -ports $ports -hostname $hostname -NextAvailable -ErrorAction SilentlyContinue
                        }
                        catch{
                        $lun_number = "LunNumber"
                        }

                        #Map the new lun to the host
                        write-msg ("Commands to map lun to host")
                        Validate-MapLunToHost -ports $ports -hostname $hostname -volume_id $volume_id -lun_number $lun_number
                        } #end else for !$CsvPath 
    } #end if for !$Commit
    else {  
            if ($CsvPath){
                        import-csv $CsvPath | foreach {
                        $pool = $_.dp_pool_id
                        $capacity = $_.capacity
                        $hostname = $_.hostname
                        $label = $_.volume_label
                        $ports = $_.mapped_ports.replace(" ","").split(",")
                        $hostmode = $_.hostmode
                        $wwns = $_.wwn.replace(" ","").replace(":","").split(",")
                        $all_values = @($pool, $capacity, $hostname, $label, $ports, $hostmode, $wwns)
                        foreach ($value in $all_values){
                        if(-not $value){write-errmsg "Missing entry in CSV file" -ForegroundColor yellow
                            write-msg "Please fill in all cells in the csv and try again" -ForegroundColor Yellow
                            break
                            } #end if for csv value check
                        } #end for $value check

                        #Provision storage for each line in the CSV.
                        Create-Volume -pool $pool -capacity $capacity -label $label -ErrorAction stop

                        #Create the hostgroup if it is not created already
                        Create-HostGroup -ports $ports -hostname $hostname -hostmode $hostmode

                        #Add wwns to Port
                        Add-WWNtoPort -ports $ports -hostname $hostname -wwns $wwns

                        #Get the next lun number in the sequence
                        $lun_number = Get-LunNumber -ports $ports -hostname $hostname -NextAvailable

                        #Map the new lun to the host
                        Map-LunToHost -ports $ports -hostname $hostname -volume_id $volume_id -lun_number $lun_number
            }#end if foreach csv value
        } #end if for $CsvPath
                    else{
                        #Provision storage for each line in the CSV.
                        Create-Volume -pool $pool -capacity $capacity -label $label -ErrorAction stop

                        #Create the hostgroup if it is not created already
                        Create-HostGroup -ports $ports -hostname $hostname -hostmode $hostmode

                        #Add wwns to Port
                        Add-WWNtoPort -ports $ports -hostname $hostname -wwns $wwns

                        #Get the next lun number in the sequence
                        $lun_number = Get-LunNumber -ports $ports -hostname $hostname -NextAvailable

                        #Map the new lun to the host
                        Map-LunToHost -ports $ports -hostname $hostname -volume_id $volume_id -lun_number $lun_number
                        } #end else for !$CsvPath 
    }
    Write-Msg ("Completed Hitachi provisioning please configure host side storage")
} #end Provision-Volume function