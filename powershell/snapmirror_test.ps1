$volumes = get-ncvol | ? {$_.name -like '*data*'}

	foreach ($vol in $volumes) {new-ncvol -name ($vol.name + "_r") -aggregate $vol.aggregate -junctionpath ('/' + $vol.name) -state online -size $vol.totalsize -vservercontext jordansown}