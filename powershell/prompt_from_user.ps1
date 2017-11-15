function Read-Choice {     
    Param(
        [System.String]$Message, 
         
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]$Choices, 
         
        [System.Int32]$DefaultChoice = 1, 
         
        [System.String]$Title = [string]::Empty 
    )        
    [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices | ForEach-Object {            
        New-Object System.Management.Automation.Host.ChoiceDescription "&$($_)", "Sets $_ as an answer."      
    }       
    $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice )     
}



$Aggrname = "moose"
$DiskCount = "13"
$DiskType = "sas"
$RaidsizeSAS = "5"
$BlockType = "64_bit"
$RaidType = "raid_dp"


$AggrSettings = @{"Name:" = $Aggrname ; "Number of Disks:" = $DiskCount ; "DiskType:" = $DiskType ; "RaidSize:" = $RaidsizeSAS ; "BlockType:" = $BlockType ; "RaidType:" = $RaidType}

$a = @{Expression={$_.Name};Label="Aggregate Attribute"},@{Expression={$_.value};Label="New Aggregate Value"}

$table = $AggrSettings | out-string



$x = 0

$title = "Endless Loop"
$message = write-host $table
  

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
    "Exits the loop."

$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
    "Displays the next 10 numbers onscreen."

$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

:OuterLoop do 
    { 
        for ($i = 1; $i -le 10; $i++)
        {$x = $x + 1; $x}

        $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

        switch ($result)
            {
                0 {break OuterLoop}
            }
    }
while ($y -ne 100)


