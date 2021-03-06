# PowerCLI script to add NFS datastores to ESX/ESXi hosts in a specified Cluster
# Only does this to hosts marked as "Connected"

#Be sure to define the -Name for the datastore parameter.

#Define the settings
$vcserver = "bpeca-aevc01"
$clustername = "BPECA-vCLOUD-RESOURCES"
$nfshost = "bpeca01-aisdev-3240-nfs02"
$nfspath1 = "/vol/AE_VCloud_SAS_DatastoreVolume12_NFS"
$DSname = "AE_VCloud_SAS_DatastoreVolume12_NFS"

#Add paths for multiple datastores.


# Connect to vCenter server
Connect-VIServer $vcserver

#Add the datastore to each host in the cluster.
$hostsincluster = Get-Cluster $clustername | Get-VMHost -State "Connected"
ForEach ($vmhost in $hostsincluster)
{
    
    ""
    "Adding NFS Datastores to ESX host: $vmhost"
    "-----------------"
   
    New-Datastore -Nfs -VMHost $vmhost -Name $DSname -NfsHost $nfshost -Path $nfspath1
    }   
    
    "Adding Datastore is complete. Check to ensure no errors were reported above."
    