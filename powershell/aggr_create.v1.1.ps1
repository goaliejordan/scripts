$controller = 192.168.30.10
$secpasswd = convertto-securestring "netapp123" -asplaintext -force
$mycreds = New-Object System.Management.Automation.PSCredential ("admin", $secpasswd)

Connect-NcController $controller -Credential $mycreds

##get the node in the cluster
$nodes = (get-ncnode).node
foreach ($node in $nodes) {

    ##change the naming of the node root aggr to meet the standards
        $AggrNodeName = ($node -replace "-0")
        $NewAggrName = ("aggr0_" + $AggrNodeName)
        try {
        $renameaggr = get-ncaggr | ? {$_.nodes -eq "$node" -and $_.AggrRaidAttributes.HasLocalRoot -eq $true} | rename-ncaggr -newname $NewAggrName -erroraction stop
        "Successfully renamed node root aggregate to $NewAggrName"
            }
        catch
            {
        "Unable to rename node root aggregate with error: $_" 
            }

##get all variables to create the new aggr with.

    ##change the node name to the naming stadard.
    
    $AggrCreateName = ($node -replace "-0")   ##gets the node name for the aggregate creation
    $n = 1  ## ending number in aggr.
    
    ##get all of the disk attributes
    $nodedisk = (get-ncdisk) | ? {$_.DiskRaidInfo.ContainerType -eq "spare" -and $_.DiskOwnershipInfo.OwnerNodeName -eq $node}
    
    ##get the number of spare disks owned by the node to use.
    $DiskCount = $nodedisk.count
    write-host "Spare disk count available for $node is $Diskcount" -ForegroundColor Yellow

    ##get the type of disk tech for the aggr naming.
    $DiskType = $nodedisk.DiskInventoryInfo.disktype[0].tolower()
    write-host "Disk tech for $node is $DiskType" -ForegroundColor Yellow

    ##get the disk speed for the naming convention.
    $DiskRPM = ([string]([System.Math]::Round($nodedisk.RPM[0] / 1000)) + "k")
    write-host "Disk RPM for $node is $DiskRPM" -ForegroundColor Yellow

    
    write-host "Finished getting disk info for aggregate creation from node $node" -ForegroundColor Yellow

    ##these variables should remain the standard for the build
    $BlockType = "64_bit"
    $RaidType = "raid_dp"
    $RaidsizeSAS = 3
    $RaidsizeOther = 3
    
    ##This will be the name of the aggregate.
    $AggrName = $AggrNodeName + "_" + $DiskType + $DiskRpm + "_$n"

    ##If disktype is SAS this loop will run.
    if ($DiskType -eq "SAS") {
    
    $SpareCount = ($DiskCount % $RaidsizeSAS)
        while (($DiskCount % $RaidsizeSAS) -ne 0) {
    
            echo $DiskCount
    
            $DiskCount--
        
        } ##while diskcount
       
        $AggrSettings = @{"Name:" = $Aggrname ; "Number of Disks:" = $DiskCount ; "DiskType:" = $DiskType ; "RaidSize:" = $RaidsizeSAS ; "BlockType:" = $BlockType ; "RaidType:" = $RaidType}
        $str = $AggrSettings | Out-String

        write-host "Running Aggregate creation precheck for aggregate: $Aggrname....."

                try {
                    New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $RaidsizeSAS  -BlockType $BlockType -PreCheck -RaidType $RaidType -erroraction Stop
                    write-host "Aggregate creation precheck for aggregate: $Aggrname successful with no errors"
                    
                    $title = "Create new aggregate on node $node"
                $message = "Do you want to Create a new aggregate on $node with following settings `n $str -ForegroundColor red `n With $SpareCount spares for node."
                            
                            

                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                        "Creates a new aggregate with displayed settings."

                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                        "Does not create new aggregate."

                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

                $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

                switch ($result)
                {
                 0 {"You selected Yes. Creating Aggregate now with name $Aggrname ."
                    try{
                    New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $RaidsizeSAS  -BlockType $BlockType -RaidType $RaidType -ErrorAction stop
                    write-host "Creating Aggregate with name $Aggrname completed" -ForegroundColor Yellow
                       }
                 catch {
                    write-host "Aggregate creation failed for aggregate: $Aggrname with error: $_" -BackgroundColor Red -ForegroundColor White
                       }
                 }
                 1 {"You selected No. Aggregate creation aborted"}
                }
                    }
                catch {
                    write-host "Aggregate creation precheck failed for aggregate: $Aggrname with error: $_" -BackgroundColor Red -ForegroundColor White
                    continue
                    }

                



    } ##end if for raidsizeSas

    
    ##This loop runs for any other type of disk tech other than "SAS" 
    Else {
    
    ##calculate disk count to use for new aggregate.
     $SpareCount = ($DiskCount % $RaidsizeOther)
        while (($DiskCount % $RaidsizeOther) -ne 0) {
    
            echo $DiskCount
    
            $DiskCount--
        } ##while diskcount
        
        $AggrSettings = "-Name: $Aggrname -Number of Disks: $DiskCount -DiskType: $DiskType -RaidSize: $RaidsizeOther -BlockType: $BlockType -RaidType: $RaidType"
        write-host "Running Aggregate creation precheck for aggregate: $Aggrname....."

                try {
                    New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $RaidsizeOther  -BlockType $BlockType -PreCheck -RaidType $RaidType -erroraction Stop
                    write-host "Aggregate creation precheck successful for aggregate: $Aggrname  with no errors"

                    $title = "Create new aggregate on node $node"
                $message = "Do you want to Create a new aggregate on $node with following settings `n $AggrSettings. `n With $SpareCount spares for node."             

                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                        "Creates a new aggregate with displayed settings."

                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                        "Does not create new aggregate."

                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

                $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

                switch ($result)
                {
                 0 {"You selected Yes. Creating Aggregate now with name $Aggrname ."
                    try{
                    New-NcAggr -Name $Aggrname -Node $node -DiskCount $DiskCount -DiskType $DiskType -RaidSize $RaidsizeOther -BlockType $BlockType -RaidType $RaidType -ErrorAction stop
                    write-host "Creating Aggregate with name $Aggrname completed" -ForegroundColor Yellow
                    }
                 catch {
                    write-host "Aggregate creation failed for aggregate: $Aggrname  with error: $_" -BackgroundColor Red -ForegroundColor White
                    }
                 }
                 1 {"You selected No. Aggregate creation aborted"}
                }
                }
                catch {
                    write-host "Aggregate creation precheck  failed for aggregate: $Aggrname with error: $_" -BackgroundColor Red -ForegroundColor White
                    
                }

                



    } ##end else for raidsizeOther

}