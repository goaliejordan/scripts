import-module dataontap
connect-nacontroller
$name = "names from CSV"
# $Agg = aggr3
import-csv "C:\powershell\psscripts\volumes.csv" | 
foreach {
    write-host "creating volume" $_.VolName "With size" $_.VolSize
    New-NaVol -name $_.VolName -Aggregate aggr1 -SpaceReserve none -size $_.VolSize
	# Turn scheduled snapshots off for each newly created volume and set reserve to 0%.
	write-host "Turning off snapshots for volume" $_.VolName
	set-navoloption -name $_.VolName -key nosnap -value on 
	set-nasnapshotreserve -name $_.VolName -percentage 0
	
} 



