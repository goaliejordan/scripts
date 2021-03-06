# PowerCLI script to add NFS datastores to ESX/ESXi host in a specified Cluster
# Only does this to hosts marked as "Connected"

#Be sure to define the -Name for the datastore parameter.

#Define the settings
$vDataFile = "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\datastores.csv"
$vDataFile1 = "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Clusters.csv"
$getData = import-csv $vDataFile
$getData1 = import-csv $vDataFile1
$getData1 | foreach {

	#$hostincluster = get-cluster $_.clustername | get-vmhost -state "connected"
	foreach ($vmhost in (get-cluster $_.clustername | get-vmhost -state "connected")) {
			$getData | foreach {
				New-Datastore -vmhost $vmhost -Nfs -Name $_.datastore -NfsHost $_.nfshost -Path $_.nfspath
				}	   
		}
  }  
    write-host "Adding Datastore is complete. Check to ensure no errors were reported above."

