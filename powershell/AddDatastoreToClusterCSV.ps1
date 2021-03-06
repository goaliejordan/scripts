# PowerCLI script to add NFS datastores to ESX/ESXi hosts in a specified Cluster
# Only does this to hosts marked as "Connected"

#Be sure to define the -Name for the datastore parameter.

#Define the settings
$vDataFile = "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\AddDatastoreToHost.csv"
$getData = import-csv $vDataFile
$vcserver = "bpeaz-aevc01"
$getData | foreach {
    write-host "Adding Datastore" $_.datastore "to host" $_.vmhost
	Get-vmhost $_.vmhost | New-Datastore -Nfs -Name $_.datastore -NfsHost $_.nfshost -Path $_.nfspath
    }   
    
    write-host "Adding Datastore is complete. Check to ensure no errors were reported above."

