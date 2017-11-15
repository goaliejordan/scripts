#create igroups to map the new luns to.
import-csv "C:\powershell\psscripts\igroups.csv" | 
foreach {
write-host "creating igroup" $_.IgroupName
New-NaIgroup $_.IgroupName -protocol iscsi -Type windows
Add-NaIgroupInitiator -Igroup $_.IgroupName -Initiator $_.initiator

}
#create qtrees to then create the luns from

import-csv "c:\powershell\psscripts\lunvolumes.csv" | 
foreach {
    write-host "creating qtree" $_.qtreepath
    new-naqtree -path $_.qtreepath
	write-host " Creating Lun from Qtree" $_.qtreepath "with size" $_.Lunsize
	#create luns from new qtrees and map the luns to the igroup
	New-NaLun -Path $_.LunPath -Size $_.LunSize -Type windows_2008 -Unreserved
	Set-NaLunComment -Path $_.LunPath -Comment "RITM0088621"
	Add-NaLunMap -Path $_.LunPath -InitiatorGroup $_.IgroupName
	}
