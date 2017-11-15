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
#>

$csv_path = "c:\temp\create_volumes.csv"
$vol_details = import-csv $csv_path

#Declare functions for messages
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


#Loop through each line in the CSV and create volume.
$vol_details | foreach {

    write-host " "
    write-host "Adding volume to HUS-VM" -ForegroundColor Green
    write-host " "

    #Get all variables from the headers in the CSV
    $pool = $_.dp_pool_id
    $capacity = $_.capacity
    $hostname = $_.hostname
    $label = $_.volume_label
    $ports = $_.mapped_ports.replace(" ","").split(",")
    $hostmode = $_.hostmode
    $hba_wwns = $_.wwn.replace(" ","").replace(":","").split(",")
    $port_map = @{}

    #Create hashtable for mapping ports to wwn.
    foreach ($port in $ports){
        foreach ($hba_wwn in $hba_wwns){ 
                if (($port[-3] -like "1" -or $port[-3] -like "2" -or $port[-3] -like "7") -and ($port[-1] -like "A" -or $port[-1] -like "C") -and $hba_wwn[-3] -like "A"){
                $port_map.add($port,$hba_wwn)
            }
            elseif (($port[-3] -like "1" -or $port[-3] -like "2" -or $port[-3] -like "7") -and ($port[-1] -like "B" -or $port[-1] -like "D") -and $hba_wwn[-3] -like "B"){
                $port_map.add($port,$hba_wwn)
            } 
            elseif ($port[-3] -like "8" -and ($port[-1] -like "B" -or $port[-1] -like "D") -and $hba_wwn[-3] -like "A"){
                $port_map.add($port,$hba_wwn)
            }        
            elseif ($port[-3] -like "8" -and ($port[-1] -like "A" -or $port[-1] -like "C") -and $hba_wwn[-3] -like "B"){
                $port_map.add($port,$hba_wwn)
            }               
        }
    }

    #Check if hostgroup needs to be created.
    #Add hostgroup if it does not exist on the system
    $check_hostgroup = "raidcom get host_grp -port" + " " + $ports[0]
    if (-Not (invoke-expression $check_hostgroup | select-string "($hostname\b)")) {
        foreach ($port in $ports) {
            #Create Hostgroup on Hitachi
            $add_hostgroup = "raidcom add host_grp -port" + " " + $port + " -host_grp_name " + $hostname
            invoke-expression $add_hostgroup
            
            #Add the hostmode option to the hostgroup
            $modify_hostgroup = "raidcom modify host_grp -port" + " " + $port + " " + $hostname + " -host_mode " + $hostmode
            invoke-expression $modify_hostgroup

            #Add the wwn for each port from the hashtable
            $add_wwn = "raidcom add hba_wwn -port" + " " + $port + " " + $hostname + " -hba_wwn " + $port_map.$port
            invoke-expression $add_wwn
            
            #Set the nickname of the hostgroup to the hostname
            $add_wwn_nickname = "raidcom set hba_wwn -port" + " " + $port + " " + $hostname + " -hba_wwn " + $port_map.$port + " -wwn_nickname " + $hostname
            invoke-expression $add_wwn_nickname
            Write-Msg ("Added $hostname hostgroup to port $port and mapped wwn:" + $port_map.$port + " to it.")
        }
    }

    #Create volume only if the dp_pool is specified:
    if ($pool){
        #Get available volume numbering:
        $avail_volume = "raidcom get ldev -ldev_list dp_volume -pool_id" + " " + $pool
        $volumes = invoke-expression $avail_volume | select-string "LDEV :"
        $new_volume = ([string]$volumes[-4]).replace("LDEV : ", "")
        $volume_id = [int]$new_volume + 1

        #Create the volumes
        $create = "raidcom add ldev -pool" + " " + $pool + " -ldev_id " + $volume_id + " -capacity " + $capacity
        try { 
            invoke-expression $create -ErrorAction stop
            write-msg ("Created volume $volume_id with size of $capacity.")
            }
        catch {
            Write-ErrMsg ("Unable to create volume with error: $_.")
            }

        #Label the volume:
        $set_label = "raidcom modify ldev -ldev_id" + " " + $volume_id + " -ldev_name " + $label
        invoke-expression $set_label
       	
        #Get available lun number:
        $find_avail_lun = "raidcom get lun -port" + " " + $ports[0] + " " + $hostname
        write-msg $find_avail_lun
        $find_lun = invoke-expression $find_avail_lun | select-string $ports[0]
        $lun_counts = @()
        foreach ($lun in $find_lun) {
            $lun_counts += , ([string]$lun).split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
        }
	
        $lun_number = [int]($lun_counts[-1][3]) + 1

        #Map volume to host as lun:
        foreach ($port in $ports) {
            $map = "raidcom add lun -port" + " " + $port + " " + $hostname + " -ldev_id " + $volume_id + " -lun_id " + $lun_number
            try {
	            invoke-expression $map -ErrorAction Stop
                write-msg ("Mapped volume $volume_id to $hostname with lun id $lun_number.")
                }
            catch{
                Write-ErrMsg ("Unable to map volume $volume_id with error: $_.")
                }
        }
	
        #Verify that the new lun is allocated:
        invoke-expression $find_avail_lun
   }
    else {
        Write-Msg ("Skipping volume creation since no pool was specified")
        }
}

$port_map = $null
