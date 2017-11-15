$a = 1..10
$num = 1..10
foreach ($b in $a){

    foreach ($n in $num) { write-host ([int]$b + [int]$n)
    }
}
