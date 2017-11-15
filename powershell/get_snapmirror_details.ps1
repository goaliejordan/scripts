function Get-SmDetails {
    Param (
        [string]$cluster,
        [string]$gcfilepath,
        [string]$csvfilepath
    )
    connect-nccontroller $cluster
    foreach ($vols in Get-Content $gcfilepath) {
    $y = Get-NcVol -Name $vols

    $x = Get-NcSnapmirrorDestination -SourceVolume $vols
    $prop = [ordered]@{'Source Volume'=$y.Name;
              'Source Vserver'=$x.SourceVserver;
              'Dest Vserver' = $x.DestinationVserver;
              'Dest Volume' = $x.DestinationVolume;
              'JunctionPath' = $y.JunctionPath;
              'Total_GB' = ($y.TotalSize / 1GB -as [INT]);
              'Used_GB' = ($y.VolumeSpaceAttributes.SizeUsed / 1GB -as [INT])
    }
    $obj = New-Object -TypeName PSObject -Property $prop
    Export-Csv -InputObject $obj -Path $csvfilepath -Append
    
    }
}

#Get-SmDetails -cluster voltron-mgmt -gcfilepath C:\scripts\voltron_project_vols.txt -csvfilepath C:\scripts\voltron_sm_vols.csv
#sleep 15
#Get-SmDetails -cluster zarkon-mgmt -gcfilepath C:\scripts\zarkon_project_vols.txt -csvfilepath C:\scripts\zarkon_sm_vols.csv
#sleep 15
Get-SmDetails -cluster rodan-mgmt -gcfilepath C:\scripts\rodan_project_vols.txt -csvfilepath C:\scripts\rodan_sm_vols.csv

# get-ncvol  | Where-Object -FilterScript {($_.junctionpath -like "*cheel*") -or ($_.junctionpath -like "*estel*") -or ($_.junctionpath -like "*istari*") -or ($_.JunctionPath -like "*elessar*") -and ($_.name -notlike "*scratch*")} | select name | Out-File C:\scripts\snowcone_project_vols.txt
