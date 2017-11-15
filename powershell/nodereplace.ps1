get-ncnode | % {


    $node = ($_ -replace "-0")

    echo $node

}