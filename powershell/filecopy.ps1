#----- Deletes Files older than $Days and then rewrites the files with the date ---#
$Now = get-date
$Days = "45"
$TargetFolder = "\\auca-file01\users\jsmith8\Test"
$LastWrite = $Now.AddDays(-$Days)

#----- get files based on lastwrite filter and specified folder ---#
$Files = Get-Childitem $TargetFolder -Recurse | Where {$_.LastWriteTime -le "$LastWrite"}
foreach ($File in $Files)
    {
        Remove-Item $File.FullName | out-null
   }


#----- copy newer files to network location with date appended ---#
copy-item "C:\temp\test" ("\\auca-file01\users\jsmith8\Test\temp")
