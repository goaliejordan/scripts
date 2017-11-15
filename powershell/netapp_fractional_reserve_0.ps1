$hosts = gc c:\temp\filers.txt # list of filers
$hosts | % {
$Filer = $_
#$c = connect-nacontroller $filer
#$vols = Get-navol
#$vols | % {
#$volume = $_.name
#if ((get-navoloption $volume | ? {$_.name -eq "fractional_reserve"}).value -ne 0)
#{ set-navoloption $volume fractional_reserve 0
#          }
#     }
}