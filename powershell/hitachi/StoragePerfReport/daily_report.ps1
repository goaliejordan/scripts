#############################################################################################
####### SCRIPT TO CREATE DAILY REPORT EMAIL  v1.1 ###########################################
#############################################################################################

#########Prerequisites and notes #########
##  RRDtool needs to be installed and location updated on each script.
##  Hitachi Tuning manager needs to be installed and location updated on each script.
##  ImageMagick needs to be installed and location updated.
##  Server needs access to send email.
##  There is no error checking in this version
##  This was run successfully on powershell v3.

##Define Logfile to be appended to each run.##
$LogFileDirectory = "D:\scripts\logs\"
$LogFileName = "error.log"

##Define location of scripts to run.##
$ScriptDir = "D:\scripts\"
$ReportDir = "D:\scripts\reports\"

##Define location of tools
$rrdtool_dir ='D:\"Program Files (x86)"\RRDtool\rrdtool.exe'
$PDFConvertTool = 'D:\"Program Files"\ImageMagick-6.9.1-Q16\convert.exe'

##define report expressions
$processor_report = ($ScriptDir + 'daily_report_processor.ps1')
$transfer_report = ($ScriptDir + 'daily_report_transfer.ps1')
$iops_report = ($ScriptDir + 'daily_report_iops.ps1')
$clpr_report = ($ScriptDir + 'daily_report_clpr.ps1')

##Define email parameters
$timestamp = (get-date -format d)
$Label = "HDS_Daily_Rpt_"
$smallerDate = $timestamp.replace("/","")
$pdf = $Label + $smallerDate + ".pdf" ##fixes issue with the convert.exe program and formatting.
$emailRecipients = @('storageadmin@server.net')
$smtpserver = 'smtp-server.net'
$emailFrom = 'HTnMServer@server.net'

##create log file to output scripts if it is not there already.
if (!(test-path ($LogFileDirectory + $LogFileName))){
     new-item -type file ($LogFileDirectory + $LogFileName) | out-null
}

##Run each script for monitoring
invoke-expression $processor_report | out-file ($LogFileDirectory + $LogFileName) -append
invoke-expression $transfer_report | out-file ($LogFileDirectory + $LogFileName) -append
invoke-expression $iops_report | out-file ($LogFileDirectory + $LogFileName) -append
invoke-expression $clpr_report | out-file ($LogFileDirectory + $LogFileName) -append

##convert each image into 1 pdf to email.
$Run_Convert =  $PDFConvertTool + " " + $ReportDir + "*.png" + " " + $ReportDir + $pdf

invoke-expression $Run_Convert

##send email with converted pdf attached
foreach ($email in $emailRecipients){

send-mailmessage -to $email -subject ("HDS Daily Health Report " + (get-date)) -body "Daily Health Reports Attached" -smtpserver $smtpserver -from $emailFrom -attachments ($ReportDir + $pdf)

}

##cleans up all files after each run.
remove-item -force ($ReportDir + '*Subsystem*')
