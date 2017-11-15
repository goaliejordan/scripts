$enablespec = New-Object VMware.Vim.VirtualMachineConfigSpec
$enablespec.vAppConfig = New-Object VMware.Vim.VmConfigSpec
$vmConfigSpec = $enablespec
$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
$vmConfigSpec.Tools.ToolsUpgradePolicy = "upgradeAtPowerCycle"
$vDataFile = "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\listofvmstomove3.csv"
$getData = import-csv $vDataFile

Write-Host "Verifying VMs are shut down.  If not, we will shut them down."
#Power on VMs
$getData | foreach {
Shutdown-VMGuest $_.Name -Confirm:$false	
Start-Sleep -s 90
Write-host "Waiting for VM to power off" 

#Move Datastore
write-host $_.Name "is being storage vmotioned to the" $_.Datastore "datastore"
Get-VM $_.Name | Move-VM -datastore (Get-datastore $_.Datastore) -DiskStorageFormat Thin

#Move host
write-host $_.Name "is being vmotioned to the" $_.Server "host"
Get-VM $_.Name | Move-VM -Destination (Get-Cluster SM-BPE | Get-VMHost -name $_.Server)

#The next line assigns the desired vlan
write-host $_.Name "is being added to the" $_.NewNW "network."
Get-NetworkAdapter $_.Name | Set-NetworkAdapter -NetworkName $_.NewNW -Confirm:$false

#Power on VMs
write-host "Starting" $_.Name "on host" $_.Server
Start-VM $_.Name -Confirm:$false
}

#Enable vApp options
Write-host "Enabling vApp options"
$getData | foreach {
#Use this to enable vApp options
$vAppEnable = Get-VM $_.Name | Get-View
$vAppEnable.ReconfigVM($enablespec)
}

#Set tools to automatically upgrade and power on VM
$getData | foreach {
write-host "Enabling check and upgrade vmtools on power cycle on VM" $_.Name "server"
	Get-VM $_.Name | %{$_.Extensiondata.ReconfigVM($vmConfigSpec)}
}

#Moves VM to specified vAPP
$getData | foreach {
Get-VM $_.Name | Move-VM -location (Get-vapp $_.vApp)
}

write-host "Scale Matrix Move Completed!!!"