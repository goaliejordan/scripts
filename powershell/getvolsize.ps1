Get-NaVol | where {$_.name -like "*cifs*"} | Select @{Name="VolumeName";Expression={$_.name}},@{Name="TotalSize(GB)";Expression={[math]::Round([decimal]$_.SizeTotal/1gb,2)}}`
,@{Name="AvailableSize(GB)";Expression={[math]::Round([decimal]$_.SizeAvailable/1gb,2)}}`
,@{Name="UsedSize(GB)";Expression={[math]::Round([decimal]$_.SizeUsed/1gb,2)}}`
,@{Name="SnapshotBlocksReserved(GB)";Expression={[math]::Round([decimal]$_.SnapshotBlocksReserved/1gb,2)}}`
,SnapshotPercentReserved | export-csv c:\temp\6280CifsVolumes.csv