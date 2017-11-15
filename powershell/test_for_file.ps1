function test_for_file ($testfilepath) {
   
 $testforfile = test-path $testfilepath
 if ($testforfile -eq $True) {
    try{
        Remove-Item $testfilepath -ErrorAction stop
        write-host "Removing older version of $testfilepath" -ForegroundColor Yellow
       }
    catch{
        write-host "Failed to remove older version of $testfilepath with error: $_"
        Stop-Transcript
        exit
       }
    }
else { write-host "No older file to clean up." -ForegroundColor Yellow
    }
 }
 

 $schedules1 = Get-NcJobCronSchedule -JobScheduleName *sm_*
 
 $schedules = @(1,2,3,4,5,6,7,8)
 $c = 0
 while ($c -lt 11)
 { write-host $schedules[(Get-Random -Maximum $schedules.count -Minimum 0)]
    $c++
    
 }