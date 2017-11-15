#############################################################################################
####### SCRIPT TO CREATE DAILY SUBSYSTEM TRANSFER REPORT ####################################
#############################################################################################

#####Define Directories and RRDtool#####
$CSVDirectory = "D:\scripts\reports\" ##Saves .csv and .png to this directory
$systemCSV = "SubsystemTransfer.csv"
$cleanCSV = "SubsystemTransferclean.csv"

$rrdtool ='D:\"Program Files (x86)"\RRDtool\rrdtool.exe'
$rrd = "SubsystemTransfer.rrd"
$rrd_dir = "D:\scripts\reports\"
$png = "SubsystemTransfer.png"

$rrd_dir_conv = $rrd_dir.replace(":","\:") ##converts a windows path to a style that rrdtool uses.

####Define HTnM parameters####
$HTnM ='D:\"Program Files (x86)"\HiCommand\TuningManager\PerformanceReporter\tools\jpcrpt.exe'
$HTnM_XML = "D:\scripts\XMLCONFIG\daily_transfer.xml"
$HTnM_ARGS = " -y -o " + $CSVDirectory + $systemCSV + " " + $HTnM_XML

##Define available metrics for monitoring##
$Metrics = @('TOTAL_Mbps','READ_Mbps','WRITE_Mbps')
$Label = 'Transfer Mbps'

############ EXPORT METRICS FROM HTNM PERFORMANCE REPORTER ##################################
$Run_HTnM = $HTnM + $HTnM_ARGS
invoke-expression $Run_HTnM

####remove the fluff from the header of the csv and create clean csv ####
get-content ($CSVDirectory + $systemCSV) | select -Skip 5 > ($CSVDirectory + $cleanCSV)

####Convert the standard time to unix time ####
$epoch = get-date -date "01/01/1970"
##select from the csv to get the correct format## 
$timeepoch = import-csv ($CSVDirectory + $cleanCSV) | 
select @{name="EpochTime";e={(New-TimeSpan -Start $epoch -End $_."Date and Time").TotalSeconds}}, "Read Xfer /sec", "Write Xfer /sec", @{name="Total_Xfer";e={[int]$_."Read Xfer /sec" + [int]$_."Write Xfer /sec"}}
$start_epoch = $timeepoch[0].EpochTime
$end_epoch = $timeepoch[-1].EpochTime

############# CREATE ROUND ROBIN DATABASE ###################################################
$args_create1 = " create " + $rrd_dir + $rrd + " --start " + $start_epoch
$args_create2 = @()
foreach ($Met in $Metrics){ 

    $args_create2 += ("DS:" + $Met + ":GAUGE:300:0:10000 RRA:AVERAGE:0.5:1:9600")
}

$rrd_ARGS_create = $args_create1 + " " + $args_create2[0] + " " + $args_create2[1] + " " + $args_create2[2]
$Run_create_RRD = $rrdtool + $rrd_ARGS_create

##Create the RRD
invoke-expression $Run_create_RRD

############# UPDATE VALUES INTO NEWLY CREATED RRD ##########################################
$timeepoch[1..($timeepoch.length-1)] | foreach {

    $rrd_ARGS_update = " update " + $rrd_dir + $rrd + " " + $_.EpochTime + ":" + $_.Total_Xfer + ":" + $_."Read Xfer /sec" + ":" + $_."Write Xfer /sec"
    $Run_update_RRD =  $rrdtool + $rrd_ARGS_update
    invoke-expression $Run_update_RRD
}

############ CREATE GRAPH ###################################################################
$TITLE = '"' + "Subsystem " + $Label + " - 230002 HUSVM - " + (get-date) + '"'


$args_graph1 = '--vertical-label "' + $Label + '" --height 300 --width 800 --watermark "Hitachi Data Systems" --font TITLE:12: --font AXIS:8: --font LEGEND:10: --font UNIT:8: --alt-autoscale-max --lower-limit=0 --rigid --slope-mode' 

$args_graph2 = @()
$graph_line_colors = @('0000FF','00FF00','FF0000')
$i = 0

foreach ($Met in $Metrics){ 

    $args_graph2 += ('DEF:' + $Met + '=' + $rrd_dir_conv + $rrd + ':' + $Met + ':AVERAGE LINE1:' + $Met + '#' + $graph_line_colors[$i] + ':"' + $Met + '" GPRINT:' + $Met + ':AVERAGE:"Average\:%8.2lf %s" GPRINT:' + $Met + ':MAX:"Maximum\:%8.2lf %s\n"')
    $i++
}

##Manually add the $args_graph2 from each index the loop here##
$rrd_ARGS_graph = " graph " + $CSVDirectory + $png + " --start " + $start_epoch + " --end " + $end_epoch + " --title=" + $TITLE + " " + $args_graph1 + " " + $args_graph2[0] + " " + $args_graph2[1] + " " + $args_graph2[2]

$Run_graph_RRD =  $rrdtool + $rrd_ARGS_graph
invoke-expression $Run_graph_RRD

#############################################################################################
