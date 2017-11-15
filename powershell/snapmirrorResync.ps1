##script to resync snapmirror of volumes, update the data, then break the snapmirror.
$destfiler = Read-Host "Enter the destination filer name"

$SourceFiler = Sourcefilername
$DestFiler = Destfilername
$SourceVol = /vol/sourcevolsnap
$DestVol = /vol/destvolsnap
$Status = get-nasnapmirror ($DestFiler + ":" + $DestVol) | select Status 
##connect to the destination filer
Connect-NaController $destfiler

##Restrict the destination vol
set-navol -name $DestVol -Restricted

##resync the snapmirror
invoke-NaSnapmirrorResync ($DestFiler + ":" + $DestVol) ($SourceFiler + ":" + $SourceVol)

##wait for snapmirror to complete
while ($Status -ne "idle")
{
	start sleep -s 60
}

## has not been tested yet
#foreach ($VOL in Get-NaSnapmirror ($filername +  ':' +$volumeName)) {
#        if ($VOL.State -eq "source")
#}

##break the snapmirror once the status is complete.
Invoke-NaSnapmirrorBreak ($DestFiler + ":" + $DestVol)

##bring the volume back online
set-navol -name $DestVol -online
	 