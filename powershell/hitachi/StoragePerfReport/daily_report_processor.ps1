#############################################################################################
####### SCRIPT TO CREATE DAILY SUBSYSTEM CPU USAGE REPORT ###################################
#############################################################################################

#####Define Directories and RRDtool#####
$CSVDirectory = "D:\scripts\reports\" ##Saves .csv and .png to this directory
$systemCSV = "SubsystemProc.csv"
$cleanCSV = "SubsystemProcClean.csv"

$rrdtool ='D:\"Program Files (x86)"\RRDtool\rrdtool.exe'
$rrd = "SubsystemProc.rrd"
$rrd_dir = "D:\scripts\reports\"
$png = "SubsystemProc.png"

$rrd_dir_conv = $rrd_dir.replace(":","\:") ##converts a windows path to a style that rrdtool uses.

####Define HTnM parameters####
$HTnM ='D:\"Program Files (x86)"\HiCommand\TuningManager\PerformanceReporter\tools\jpcrpt.exe'
$HTnM_XML = "D:\scripts\XMLCONFIG\daily_processor.xml"
$HTnM_ARGS = " -y -o " + $CSVDirectory + $systemCSV + " " + $HTnM_XML

##Add available MPU or CPU to $MPU_ID##
$MPU_ID = @('MPU-10','MPU-11','MPU-20','MPU-21')
$Label = 'Processor %Usage'

############ EXPORT METRICS FROM HTNM PERFORMANCE REPORTER ##################################
$Run_HTnM = $HTnM + $HTnM_ARGS
invoke-expression $Run_HTnM

####remove the fluff from the header of the csv and create clean csv ####
get-content ($CSVDirectory + $systemCSV) | select -Skip 5 > ($CSVDirectory + $cleanCSV)

####Convert the standard time to unix time ####
$epoch = get-date -date "01/01/1970"
##select from the csv to get the correct format##
$timeepoch = import-csv ($CSVDirectory + $cleanCSV) | select @{name="EpochTime";e={(New-TimeSpan -Start $epoch -End $_."Date and Time").TotalSeconds}}, "Adaptor ID", "Processor ID", "Processor Busy %"

####Create CSV per each Processor to update the RRD with ####
foreach ($MPU in $MPU_ID){
 
        $timeepoch | where-object {$_."Adaptor ID" -eq $MPU -and $_."Processor ID" -eq "_Total"} | export-csv ($CSVDirectory + $MPU + "SubsystemID.csv")
}

############# CREATE ROUND ROBIN DATABASE ###################################################
$procData0 = import-csv ($CSVDirectory + $MPU_ID[0] + "SubsystemID.csv")

$start_epoch = $procData0[0].EpochTime
$end_epoch = $procData0[-1].EpochTime

$args_create1 = " create " + $rrd_dir + $rrd + " --start " + $start_epoch
$args_create2 = @()

foreach ($MPU in $MPU_ID){ 

    $args_create2 += ("DS:Usage_" + $MPU + ":GAUGE:60:0:100 RRA:AVERAGE:0.5:1:9600")
}

##Manually add the $args_graph2 from each index of the loop here##
$rrd_ARGS_create = $args_create1 + " " + $args_create2[0] + " " + $args_create2[1] + " " + $args_create2[2] + " " + $args_create2[3] 
$Run_create_RRD = $rrdtool + $rrd_ARGS_create

##Create the RRD
invoke-expression $Run_create_RRD

############# UPDATE VALUES INTO NEWLY CREATED RRD ##########################################
$procData1 = import-csv ($CSVDirectory + $MPU_ID[1] + "SubsystemID.csv")
$procData2 = import-csv ($CSVDirectory + $MPU_ID[2] + "SubsystemID.csv")
$procData3 = import-csv ($CSVDirectory + $MPU_ID[3] + "SubsystemID.csv")

##Loop through all lines in the csv
1..(($procData0).count - 1) | foreach {

    $args_update1 = " update " + $rrd_dir + $rrd + " " + $procData0[$_].EpochTime + ":" + $procData0[$_]."Processor Busy %" + ":" + $procData1[$_]."Processor Busy %" + ":" + $procData2[$_]."Processor Busy %" + ":" + $procData3[$_]."Processor Busy %"
    $Run_update_RRD =  $rrdtool + $args_update1
    invoke-expression $Run_update_RRD

}

############ CREATE GRAPH ARGUMENTS FOR EACH CLPR ###########################################
$TITLE = '"' + "Subsystem " + $Label + " - 230002 HUSVM - " + (get-date) + '"'

$args_graph1 = '--vertical-label "' + $Label + '" --height 300 --width 800 --watermark "Hitachi Data Systems" --font TITLE:12: --font AXIS:8: --font LEGEND:10: --font UNIT:8: --lower-limit=0 --upper-limit=100 --rigid --slope-mode'

$args_graph2 = @()
$args_graph3 = @()

##add any colors you like and call them by index##
$graph_line_colors = @('006699','00CC66','663300','FF3300')
$i = 0

foreach ($MPU in $MPU_ID){ 

    $args_graph2 += ("DEF:" + $MPU + "=" + $rrd_dir_conv + $rrd + ":Usage_" + $MPU + ":AVERAGE")

    if ([array]::IndexOf($MPU_ID, $MPU) % 2 -ne 0) {  ##adds a newline entry on even indexes only.

        $args_graph3 += ('LINE1:' + $MPU + '#' + $graph_line_colors[$i] + ':"' + $MPU + '" GPRINT:' + $MPU + ':AVERAGE:"Average\:%8.2lf %s" GPRINT:' + $MPU + ':MAX:"Maximum\:%8.2lf %s\n"')
    }
    else {

        $args_graph3 += ('LINE1:' + $MPU + '#' + $graph_line_colors[$i] + ':"' + $MPU + '" GPRINT:' + $MPU + ':AVERAGE:"Average\:%8.2lf %s" GPRINT:' + $MPU + ':MAX:"Maximum\:%8.2lf %s"')
    }
    $i++

}

$args_graph4 = 'HRULE:50#000000:"Lower Processor Usage Watermark 50%\n" HRULE:70#000FFF:"Upper Processor Usage Watermark 70%\n"'

$all_args_graph2 = $args_graph2[0] + " " + $args_graph2[1] + " " + $args_graph2[2] + " " + $args_graph2[3]
$all_args_graph3 = $args_graph3[0] + " " + $args_graph3[1] + " " + $args_graph3[2] + " " + $args_graph3[3] 

$rrd_ARGS_graph = " graph " + $CSVDirectory + $png + " --start " + $start_epoch + " --end " + $end_epoch + " --title=" + $TITLE + " " + $args_graph1 + " " + $all_args_graph2 + " " + $all_args_graph3 + " " + $args_graph4
$Run_graph_RRD =  $rrdtool + $rrd_ARGS_graph

invoke-expression $Run_graph_RRD				       


#############################################################################################
