##moves old users from users folder to userarchive folder to be removed later.
import-csv "C:\powershell\psscripts\disabled.csv" | 
foreach { 
$foldername = $_.Userfolder
$folderpath = join-path "\\auca-file01\users\" $foldername 
move-item $folderpath \\auca-file01\users\_UserArchive 
}