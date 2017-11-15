

#get nodes to begin looping through the nodes

$nodes = Get-NcNode 


foreach ($node in $nodes) {

##get all variables to create the new aggr with.

    ##change the node name to the naming stadard.
    $AggrNodeName = ($node -replace "-0")
    
    $n = 1
    
    ##get all of the disk attributes
    $nodedisk = (get-ncdisk) | ? {$_.DiskRaidInfo.ContainerType -eq "spare" -and $_.DiskOwnershipInfo.OwnerNodeName -eq $node}
    
    ##get the number of spare disks to use.
    $DiskCount = $nodedisk.count[0]
    write-host "Spare disk count for $node is $Diskcount" -ForegroundColor Yellow
    
    ##get the type of disk tech for the aggr naming.
    $DiskType = ($nodedisk.DiskInventoryInfo.disktype[0]).ToLower()
    write-host "Disk tech for $node is $DiskType" -ForegroundColor Yellow

    ##get the disk speed for the naming convention.
    $DiskRPM = ([string]([System.Math]::Round($nodedisk.RPM[0] / 1000)) + "k")
    write-host "Disk RPM for $node is $DiskRPM" -ForegroundColor Yellow

    
    write-host "Finished getting disk info for aggregate creation from node $node" -ForegroundColor Yellow

    ##these variables should remain the standard
    $BlockType = "64_bit"
    $RaidType = "raid_dp"
    $SASRaidsize = 7
    $OtherRaidsize = 7
    ##This will be the name of the aggregate.
    $AggrName = $AggrNodeName + "_" + $DiskType + $DiskRpm + "_$n"

    ##If disktype is SAS this loop will run.
    if ($DiskType -eq "SAS") 

    {
    
        ##calculate disk count to use for new aggregate.
        while (($DiskCount % $SASRaidsize) -ne 0) {
    
            echo $DiskCount
    
            $DiskCount--
        } ##while diskcount

    $sparecount = ($DiskCount % $SASRaidsize)
    
    $PreviewAggr = "-Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $SASRaidsize  -BlockType $BlockType -RaidType $RaidType"

    $testaggr = New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $SASRaidsize  -BlockType $BlockType -PreCheck -RaidType $RaidType
    
    write-host "Running pre-checks for aggregate creation on node:" $node.name -ForegroundColor Yellow
    echo " "

                $title = "Create new node aggregate"
                $message = ("Do you want to Create a new $node aggregate with following settings; 
                                $PreviewAggr with $sparecount spares.")

                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                        "Creates a  new aggregate with displayed settings."

                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                        "Does not creates new aggregate."

                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

                $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

                switch ($result)
                {
                 0 {"You selected Yes. Creating Aggregate now with name $Aggrname ."
                 
                    "Running prechecks for aggregate creation."
                    $testaggr = New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $SASRaidsize  -BlockType $BlockType -PreCheck -RaidType $RaidType
                    $testaggr
                    if ($testaggr -eq $null) { 
                 New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $SASRaidsize  -BlockType $BlockType -RaidType $RaidType 

                    write-host "Creating Aggregate with name $Aggrname completed" -ForegroundColor Yellow
                    } 
                    else {
                    write-host "Aggregate creation precheck failed for $Aggrname, please review output" -ForegroundColor Yellow
                    }
                 }
                 1 {"You selected No. Aggregate creation aborted"}
                }



    } ##end if for SASraidsize

    
    ##This loop runs for any other type of disk tech other than "SAS" 
    Else 

    {
    
        ##calculate disk count to use for new aggregate.
        w hile (($DiskCount % $OtherRaidsize) -ne 0) {
    
            echo $DiskCount
    
            $DiskCount--
        }

    $PreviewAggr = "-Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $OtherRaidsize  -BlockType $BlockType -RaidType $RaidType"

    $testaggr = New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $OtherRaidsize  -BlockType $BlockType -PreCheck -RaidType $RaidType
    
    write-host "Running pre-checks for aggregate creation on node:" $node.name -ForegroundColor Yellow
    echo " "

                $title = "Create new node aggregate"
                $message = ("Do you want to Create a new $node aggregate with following settings; 
                            $PreviewAggr with $sparecount spares.")

                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                        "Creates a  new aggregate with displayed settings."

                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                        "Does not creates new aggregate."

                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

                $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

                switch ($result)
                {
                 0 {"You selected Yes. Creating Aggregate now with name $Aggrname ."
                 
                    "Running prechecks for aggregate creation."
                    $testaggr = New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $OtherRaidsize  -BlockType $BlockType -PreCheck -RaidType $RaidType
                    $testaggr
                    if ($testaggr -eq $null) { 
                 New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $OtherRaidsize  -BlockType $BlockType -RaidType $RaidType 

                    write-host "Creating Aggregate with name $Aggrname completed" -ForegroundColor Yellow
                    } 
                    else {
                    write-host "Aggregate creation precheck failed for $Aggrname, please review output" -ForegroundColor Yellow
                    }
                 }
                 1 {"You selected No. Aggregate creation aborted"}
                }
    } ##end else

}