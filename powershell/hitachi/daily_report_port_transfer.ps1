#############################################################################################
####### SCRIPT TO CREATE DAILY SUBSYSTEM PORT TRANSFER RATE REPORT ##########################
#############################################################################################

#####Define Directories and RRDtool#####
$CSVDirectory = "D:\scripts\reports\" ##Saves .csv and .png to this directory
$systemCSV = "SubsystemPortsTransfer.csv"
$cleanCSV = "SubsystemPortsTransferClean.csv"

$rrdtool ='D:\"Program Files (x86)"\RRDtool\rrdtool.exe'
$rrd = "SubsystemPortsTransfer.rrd"
$rrd_dir = "D:\scripts\reports\"
$png = "SubsystemPortsTransfer.png"

$rrd_dir_conv = $rrd_dir.replace(":","\:") ##converts a windows path to a style that rrdtool uses.

####Define HTnM parameters####
$HTnM ='D:\"Program Files (x86)"\HiCommand\TuningManager\PerformanceReporter\tools\jpcrpt.exe'
$HTnM_XML = "D:\scripts\XMLCONFIG\daily_port_transfer.xml"
$HTnM_ARGS = " -y -o " + $CSVDirectory + $systemCSV + " " + $HTnM_XML

##Add available MPU or CPU to $MPU_ID##
$Ports = @('CL7-A','CL7-B','CL7-C','CL7-D','CL8-A','CL8-B','CL8-C','CL8-D')
$Label = 'Port Transfer Rate'

############ EXPORT METRICS FROM HTNM PERFORMANCE REPORTER ##################################
$Run_HTnM = $HTnM + $HTnM_ARGS
invoke-expression $Run_HTnM

####remove the fluff from the header of the csv and create clean csv ####
get-content ($CSVDirectory + $systemCSV) | select -Skip 5 > ($CSVDirectory + $cleanCSV)

####Convert the standard time to unix time ####
$epoch = get-date -date "01/01/1970"
##select from the csv to get the correct format##
$timeepoch = import-csv ($CSVDirectory + $cleanCSV) | select @{name="EpochTime";e={(New-TimeSpan -Start $epoch -End $_."Date and Time").TotalSeconds}}, "Port Name", "Max Xfer /sec"
####Create CSV per each Port to update the RRD with ####
foreach ($Port in $Ports){
 
        $timeepoch | where-object {$_."Port Name" -eq $Port} | export-csv ($CSVDirectory + $Port + "Subsystem.csv")
}

$portData = @()
$portData += , @(import-csv ($CSVDirectory + $Ports[0] + "Subsystem.csv"))
$start_epoch = $portData[0][0].EpochTime
$end_epoch = $portData[0][-1].EpochTime

############# CREATE ROUND ROBIN DATABASE ###################################################

$args_create1 = " create " + $rrd_dir + $rrd + " --start " + $start_epoch
$args_create2 = ""

foreach ($Port in $Ports){ 

    $args_create2 += ("DS:Usage_" + $Port + ":GAUGE:300:0:10000 RRA:AVERAGE:0.5:1:9600" + " ")
}

##Manually add the $args_graph2 from each index of the loop here##
$rrd_ARGS_create = $args_create1 + " " + $args_create2
$Run_create_RRD = $rrdtool + $rrd_ARGS_create

##Create the RRD
invoke-expression $Run_create_RRD

############# UPDATE VALUES INTO NEWLY CREATED RRD ##########################################
$portID = 1
while ($portID -le ($Ports.count - 1)){ 

    $portData += , @(import-csv ($CSVDirectory + $Ports[$portID] + "Subsystem.csv"))
    $portID++
}


$args_update1 = " update " + $rrd_dir + $rrd + " "
##Loop through all lines in the csv
$num = 0..($portData.count - 1)

1..(($portData[0]).count - 1) | foreach {
    $args_update2 = $portData[0][$_].EpochTime + ":"
    $args_update3 = ""
    foreach ($n in $num) {
        $args_update3 += ($portData[$n][$_]."Max Xfer /sec" + ":")       
    }
    $Run_update_RRD =  $rrdtool + $args_update1 + $args_update2 + $args_update3
    invoke-expression $Run_update_RRD
}

############ CREATE GRAPH ARGUMENTS FOR EACH CLPR ###########################################
$TITLE = '"' + "Subsystem " + $Label + " - 230002 HUSVM - " + (get-date) + '"'

$args_graph1 = '--vertical-label "' + $Label + '" --height 300 --width 800 --watermark "Hitachi Data Systems" --font TITLE:12: --font AXIS:8: --font LEGEND:10: --font UNIT:8: --lower-limit=0 --rigid --slope-mode'

$args_graph2 = ""
$args_graph3 = ""

##add any colors you like and call them by index##
$graph_line_colors = @('006699','00CC66','663300','FF3300','0000FF','FF00FF','00FF00','002E00','018A65','D3B62F','9D80F6','000FFF')
$i = 0

foreach ($Port in $Ports){ 

    $args_graph2 += ("DEF:" + $Port + "=" + $rrd_dir_conv + $rrd + ":Usage_" + $Port + ":AVERAGE" + " ")

    if ([array]::IndexOf($Ports, $Port) % 2 -ne 0) {  ##adds a newline entry on even indexes only.

        $args_graph3 += ('LINE1:' + $Port + '#' + $graph_line_colors[$i] + ':"' + $Port + '" GPRINT:' + $Port + ':AVERAGE:"Average\:%8.2lf %s" GPRINT:' + $Port + ':MAX:"Maximum\:%8.2lf %s\n"' + " ")
    }
    else {

        $args_graph3 += ('LINE1:' + $Port + '#' + $graph_line_colors[$i] + ':"' + $Port + '" GPRINT:' + $Port + ':AVERAGE:"Average\:%8.2lf %s" GPRINT:' + $Port + ':MAX:"Maximum\:%8.2lf %s"' + " ")
    }
    $i++

}

$rrd_ARGS_graph = " graph " + $CSVDirectory + $png + " --start " + $start_epoch + " --end " + $end_epoch + " --title=" + $TITLE + " " + $args_graph1 + " " + $args_graph2 + $args_graph3
$Run_graph_RRD =  $rrdtool + $rrd_ARGS_graph
invoke-expression $Run_graph_RRD				       


#############################################################################################

