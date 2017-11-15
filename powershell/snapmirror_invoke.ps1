# remove_snapmirror.ps1
# powershell script to remove snapmirror relations and destroy the destination volumes
#
$dst_cluster = read-host "please enter the destination cluster"
$src_cluster = read-host "please enter the source cluster"
#$src_vserver = (($src_cluster -split '-')[0]).TrimStart()
$src_vserver = "vs0"
$dst_vserver = (($dst_cluster -split '-')[0]).TrimStart()
$sm_vol_file = "C:\scripts\cdotsm\" + $src_vserver + "_vols_$(get-date -format "yyyyMMdd_hhmmtt").csv"
$sm_rem_file = "C:\scripts\cdotsm\" + $src_vserver + "_rem_vol_$(get-date -format "yyyyMMdd_hhmmtt").txt"
$TranscriptPath = "c:\scripts\cdotsm\"+ $src_vserver + "_transcript_$(get-date -format "yyyyMMdd_hhmmtt").txt"


$controllers = @("rodan-mgmt","stickman-mgmt","voltron-mgmt","zarkon-mgmt","chimmera-mgmt","sundae-mgmt")
$authentication = Get-Credential


##add the credentials for each cluster
foreach ($controller in $controllers) {
    Add-NcCredential -Name $controller -Credential $authentication -SystemScope | Out-Null


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
function Test_for_file ($testfilepath) {
   
 $testforfile = test-path $testfilepath
 if ($testforfile -eq $True) {
    try{
        Remove-Item $testfilepath -ErrorAction stop
        write-host "Cleaning up older version of $testfilepath" -ForegroundColor Yellow
       }
    catch{
        write-host "Failed to remove older version of $testfilepath with error: $_"
        Stop-Transcript
        exit
       }
    }
else { write-host "No older files to clean up." -ForegroundColor Yellow
    }
 }

############ MAIN CODE ##########################################

start-transcript -Path $TranscriptPath

Write-Msg  "##### Beginning remove_snapmirror.ps1 script #####"

Check-LoadedModule -ModuleName DataONTAP

Write-Msg "Connecting to Destination cluster $dst_cluster"
try {
    Connect-nccontroller $dst_cluster -ErrorAction Stop | Out-Null   
    "connected to " + $dst_cluster
    }
catch {
    Write-ErrMsg ("Failed connecting to Cluster " + $dst_cluster + " : $_.")
    stop-transcript
    exit
}

Write-Msg ("Getting DP volumes for source vserver " + $src_vserver.ToUpper())
Get-NcSnapmirror | ? {$_.sourcevserver -match $src_vserver} | select @{expression = {$_.SourceVolume}; label = "name"} | Export-csv $sm_vol_file

if (Test-Path $sm_vol_file) {
    Write-Msg ("DP volumes for source vserver " + $src_vserver.ToUpper() + " are polulated in" + $sm_vol_file)

    Write-Host "Reading file $sm_vol_file"
    $volumes = import-csv $sm_vol_file
    $vols = ($volumes).name

    Write-Msg "Connecting to Source cluster $src_cluster" 
    try {
        Connect-nccontroller $src_cluster -ErrorAction Stop | Out-Null   
        "connected to " + $src_cluster
        }
    catch {
        Write-ErrMsg ("Failed connecting to Cluster " + $src_cluster + " : $_.")
        stop-transcript
        exit
    }
    Write-Host "Checking if junction path matches the search strings"
    foreach ($volume in $vols) {
        $volume_info = get-ncvol $volume 
        if ($volume_info.junctionpath -like "/prj/qct/chips/elessar/sandiego/tapeout/r0*") {
            $volume_info.Name | out-file $sm_rem_file -append
            Write-Host ($volume_info.Name + " : junction path matches the searching string" )
        }
        elseif ($volume_info.junctionpath -like "/prj/qct/chips/istari/sandiego/tapeout/r0*") {
            $volume_info.Name | out-file $sm_rem_file -append
            Write-Host ($volume_info.Name + " : junction path matches the searching string" )
        }
    }
}
else {
     Write-ErrMsg ("The file $sm_vol_file does not exist. Cannot proceed further")
     stop-transcript
     exit
}

if (Test-Path $sm_rem_file) {
    connect-nccontroller $dst_cluster | out-null
    $smvols = Get-Content $sm_rem_file

    foreach ($smvol in $smvols) {
        $smvol_r = $smvol + "r"
        try{
            Write-Host "Quiescing SM relation for : $smvol_r"
            Invoke-NcSnapmirrorQuiesce -DestinationVserver $dst_vserver -DestinationVolume $smvol_r -ErrorAction stop | out-null
            sleep -s 2
            Write-Host "Breaking SM relation for: $smvol_r"
            Invoke-NcSnapmirrorBreak -DestinationVserver $dst_vserver -DestinationVolume $smvol_r -Confirm:$false -ErrorAction stop | out-null
            sleep -s 2
            Write-Host "Deleting SM relation for: $smvol_r"
            remove-NcSnapmirror -DestinationVserver $dst_vserver -DestinationVolume $smvol_r -Confirm:$false -ErrorAction stop | out-null
            Write-Host ""
        }
        catch{  
            Write-Host ""
            Write-Host ("Failed to perform sm removal: $_.")
        }
    }
    
    Write-Msg "+++ Deleting destination volumes +++"

    foreach ($smvol in $smvols) {
        $smvol_r = $smvol + "r"
        try{
            $x = Get-NcSnapmirror -DestinationVserver $dst_vserver -Destinationvolume $smvol_r 
            if($x -eq $null) { 
                write-host "Offlining: " $smvol_r -ForegroundColor yellow
                Set-NcVol -Name $smvol_r -Offline -VserverContext $dst_vserver -Confirm:$false -ErrorAction stop | out-null
                write-host "Destroying: " $smvol_r -ForegroundColor yellow
                remove-ncvol -Name $smvol_r -VserverContext $dst_vserver -Confirm:$false -ErrorAction stop | out-null
                }
            else{
                write-host "Not eligible for offline: " $smvol_r
            }
        }
        catch{  
            Write-Host ""
            Write-Host ("Failed to perform deletion: $_.")
        }
    }
}
else {
    Write-Host ""
    write-host "No DP volumes matching the junction-path strings" -ForegroundColor yellow
    Write-Host ""
}
stop-transcript

#create DP volume on destination cluster
##get the new volumes to be backed-up with the specified junction path and export the names to a .csv

Test_for_file ("C:\scripts\cdotsm\backtheseup_vol.csv")
foreach ($controller in $controllers) {
   
    Connect-NcController $controller
    get-ncvol | ? {$_.junctionpath -like "*elessar*" -or $_.junctionpath -like "*istari*" -and ($_.junctionpath -like "*r1*") -and ($_.junctionpath -notlike "*scratch*")} | 
    Select-Object -Property name,junctionpath,@{name = 'Size'; expression = {$_.TotalSize /1GB -as [Int]}},@{n = 'used'; e = {$_.VolumeSpaceAttributes.SizeUsed / 1GB -as [INT]}} | export-csv "C:\scripts\cdotsm\backtheseup_vol.csv" -Append

    }

#loop through the volumes that need to be backed up and create a new volume on the destination cluster with name + "r" and same size of original volume.

$new_volumes = import-csv "C:\scripts\cdotsm\backtheseup_vol.csv"
$total_volumes = (import-csv "C:\scripts\cdotsm\backtheseup_vol.csv").count

 Connect-NcController $dst_cluster

    foreach ($new_volume in $new_volumes){
            #get the aggregate with the most free space to create the volume in.
            $aggrfree = get-ncaggr | ? {$_.AggrRaidAttributes.HasLocalRoot -eq $false} | sort used
            $dest_aggr = $aggrfree[0]

            New-NcVol -Name  ($new_volume.name + "r") -Aggregate $dest_aggr -SpaceReserve none -Type DP -VserverContext $dst_vserver -Size ($new_volume.size + "g")
        }

#create the snapmirror relationship

        #get the cron schedules for the cluster and loop through them.
        $schedules = Get-NcJobCronSchedule -JobScheduleName *sm_*
        foreach ($new_volume in $new_volumes){ 
            New-NcSnapmirror -DestinationVserver $dst_vserver -DestinationVolume ($new_volume.name + "r") -SourceVserver $src_vserver -SourceVolume $new_volume.name -Schedule $schedules[(Get-Random -Maximum $schedules.count -Minimum 0)]
            
            }
        
#initialize the snapmirror
(get-ncsnapmirror | ? {($_.mirrorstate -eq "uninitialized") -and ($_.destinationvolume -like "*14*")} | select destinationvserver,destinationvolume) | % {Invoke-NcSnapmirrorInitialize -DestinationVserver $_.destinationvserver -DestinationVolume $_.destinationvolume}