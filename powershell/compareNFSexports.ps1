#netapp powershell script to compare running exports with persistent exports

#output all exports in the system:
$allexport = get-nanfsexport

#output only the persisent exports
$persistentexports = get-nanfsexport -persistent

#compare the 2 outputs to show non-persistent exports:
echo "Comparing nfsexports for persistent and non-persitent objects"
echo "  "
echo "=> indicates that the export is in /etc/exportfs file"

compare-object $allexport $persistentexports | ft -auto
echo " "
echo "Compare to the list below of what is currently exported."
echo " "
echo $allexport

