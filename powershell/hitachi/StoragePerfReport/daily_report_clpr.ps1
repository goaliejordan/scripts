#############################################################################################
####### SCRIPT TO CREATE DAILY SUBSYSTEM CLPR WRITE % REPORT ################################
#############################################################################################

#####Define Directories and RRDtool#####
$csv_directory = "D:\scripts\reports\" ##Saves .csv and .png to this directory
$system_csv = "SubsystemCLPRS.csv"
$clean_csv = "SubsystemCLPRSclean.csv"

$rrdtool ='D:\"Program Files (x86)"\RRDtool\rrdtool.exe'
$rrd = "SubsystemCLPRS.rrd"
$rrd_dir = "D:\scripts\reports\"
$png = "SubsystemCLPRS.png"

$rrd_dir_conv = $rrd_dir.replace(":","\:") ##converts a windows path to a style that rrdtool uses.

####Define HTnM parameters####
$HTnM ='D:\"Program Files (x86)"\HiCommand\TuningManager\PerformanceReporter\tools\jpcrpt.exe'
$HTnM_XML = "D:\scripts\XMLCONFIG\daily_clpr.xml"
$HTnM_ARGS = " -y -o " + $csv_directory + $system_csv + " " + $HTnM_XML

##Add available clprs to $clprs##
$clprs = @('0')
$label = 'CLPR Write %'

############ EXPORT METRICS FROM HTNM PERFORMANCE REPORTER ##################################
$run_HTnM = $HTnM + $HTnM_ARGS
invoke-expression $run_HTnM

####remove the fluff from the header of the csv and create clean csv ####
get-content ($csv_directory + $system_csv) | select -Skip 5 > ($csv_directory + $clean_csv)

####Convert the standard time to unix time ####
$epoch = get-date -date "01/01/1970"
##select from the csv to get the correct format## 
$timeepoch = import-csv ($csv_directory + $clean_csv) | select @{name="EpochTime";e={(New-TimeSpan -Start $epoch -End $_."Date and Time").TotalSeconds}}, "Cache Write Pending Usage %"
$start_epoch = $timeepoch[0].EpochTime
$end_epoch = $timeepoch[-1].EpochTime

############# CREATE ROUND ROBIN DATABASE ###################################################
$args_create1 = " create " + $rrd_dir + $rrd + " --start " + $start_epoch
$args_create2 = @()
foreach ($clpr in $clprs){

    $args_create2 += ("DS:Usage_" + $clpr + ":GAUGE:60:0:100 RRA:AVERAGE:0.5:1:9600")
}

##Manually add the $args_graph2 from each index of the loop here##
$rrd_ARGS_create = $args_create1 + " " + $args_create2[0]
$Run_create_RRD = $rrdtool + $rrd_ARGS_create

##Create the RRD
invoke-expression $Run_create_RRD

############# UPDATE VALUES INTO NEWLY CREATED RRD ##########################################
$timeepoch[1..($timeepoch.length-1)] | foreach {

    $args_update1 = " update " + $rrd_dir + $rrd + " " + $_.EpochTime + ":" + $_."Cache Write Pending Usage %"
    $Run_update_RRD =  $rrdtool + $args_update1
    invoke-expression $Run_update_RRD

}

############ CREATE GRAPH ARGUMENTS FOR EACH CLPR ###########################################
$TITLE = '"' + "Subsystem" + $Label + " - 230002 HUSVM - " + (get-date) + '"'

$args_graph1 = '--vertical-label "' + $Label + '" --height 300 --width 800 --watermark "Hitachi Data Systems" --font TITLE:12: --font AXIS:8: --font LEGEND:10: --font UNIT:8: --lower-limit=0 --upper-limit=100 --units-exponent=0 --rigid'

$args_graph2 = @()

##add any colors you like and call them by index##
$graph_line_colors = @('006699','00CC66','663300','FF3300')
$i = 0

foreach ($clpr in $clprs){

    $args_graph2 += ('DEF:' + $clpr + '=' + $rrd_dir_conv + $rrd + ':Usage_' + $clpr + ':AVERAGE LINE1:' + $clpr + '#' + $graph_line_colors[$i] + ':"CLPR_' + $clpr + '" GPRINT:' + $clpr + ':AVERAGE:"Average\:%8.2lf %s" GPRINT:' + $clpr + ':MAX:"Maximum\:%8.2lf %s\n"')
    $i++
}

$args_graph3 = 'HRULE:40#000000:"Lower Write Pending Watermark 40%\n" HRULE:60#000FFF:"Upper Write Pending Watermark 60%\n"'

##Manually add the $args_graph2 from each index the loop here##
$rrd_ARGS_graph = " graph " + $csv_directory + $png + " --start " + $start_epoch + " --end " + $end_epoch + " --title=" + $TITLE + " " + $args_graph1 + " " + $args_graph2[0] + " " + $args_graph3

$Run_graph_RRD =  $rrdtool + $rrd_ARGS_graph
invoke-expression $Run_graph_RRD

#############################################################################################

