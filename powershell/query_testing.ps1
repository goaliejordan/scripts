

$VserverName = "snowcone"

#Create LS mirrors

for ($i = 1 ; $i -le (Get-NcNode).count; $i++) {

$nodeAggr = get-ncaggr | ? {$_.name -notlike "*aggr0*" and -like "*$VserverName[$i]*"}

New-NcVol -Name ($VserverName + "root_ls1") -Aggregate $nodeAggr -Type "dp" -VserverContext $VserverName -Size 10g



}

Write-Msg ("Creating SnapMirror relationship between " + $SourceCluster + ":"+ $SourceVserver + "/"+ $SourceVolume + " and " + $DestinationCluster + ":"+ $DestinationVserver + "/"+ $DestinationVolume )

New-NcSnapmirror -SourceCluster $SourceCluster -DestinationCluster $DestinationCluster -SourceVserver $SourceVserver -DestinationVserver $DestinationVserver -SourceVolume $SourceVolume -DestinationVolume $DestinationVolume

Write-Msg ("Initializing the LS snapmirror relationship")

Invoke-NcSnapmirrorInitialize -SourceCluster $SourceCluster -DestinationCluster $DestinationCluster -SourceVserver $SourceVserver -DestinationVserver $DestinationVserver -SourceVolume $SourceVolume -DestinationVolume $DestinationVolume


$VserverName = "voltron"
Connect-NcController voltron-mgmt

for ($i = 1 ; $i -le (Get-NcNode).count; $i++) {

#$nodeAggr = get-ncaggr | ? {($_.name -notlike "*aggr0*") -and ($_.name -like "*$VserverName[$i]*")}
$nodeAggr = get-ncaggr | ? {($_.name -match "^$VserverName($i)|_1$")}

write-host $nodeAggr

}

$q = Get-NcAggr -Template
$q.Name = "^$VserverName($i)|_1$"
write-host $q.name

#($_.name -notlike "*aggr0*") -and 


##get the type of disk speed.

##(Get-NcDisk).DiskInventoryInfo.DiskType