$o = New-Object -comobject outlook.application
$n = $o.GetNamespace("MAPI")

$f = $n.PickFolder()

##location to move files to.
$filepath = "c:\BackupManifests\"
$f.Items| foreach {
 $SendName = $_.SenderName
   $_.attachments|foreach {
    Write-Host $_.filename
  ##move file with extension below: Contains("extension")##   
    $a = $_.filename
    If ($a.Contains("pdf")) {
    $_.saveasfile((Join-Path $filepath $_.filename))
   }
  }
}