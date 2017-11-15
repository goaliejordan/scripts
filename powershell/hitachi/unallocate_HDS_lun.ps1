##Unallocate storage from Hitachi Command Suite
##Lun is verified and user is prompted before the Lun is removed

##Define functions:

#formats messages output
function Write-ErrMsg ($msg) {
    $fg_color = "White"
    $bg_color = "Red"
    Write-host ""
    Write-host $msg -ForegroundColor $fg_color -BackgroundColor $bg_color
    Write-host ""
}
function Write-Msg ($msg) {
    $color = "yellow"
    Write-host ""
    Write-host $msg -foregroundcolor $color
    Write-host ""
}

#Verifies that the Hitachi PSSnapin is installed
function Check-LoadedSnapin {
  Param( 
    [parameter(Mandatory = $true)]
    [string]$SnapinName
  )
  $LoadedPSSnapin = Get-PSSnapin | ? {$_.name -like "*$SnapinName*"}
  if (!$LoadedPSSnapin) {
    try {
        Add-PSSnapin -Name $SnapinName -ErrorAction Stop
        Write-Msg ("The Hitachi PSSnapin has been added")
    }
    catch {
        Write-ErrMsg ("Could not find the Hitachi PSSnapin on this system. Please download from Hitachi Portal")
        exit 
    }
  }
}

function Connect-Subsystem
{
<#
.Synopsis
   Connect to HDS Subsystem
.DESCRIPTION
   This function utilizes the Add-SubSystem function to connect to the HDS Array
.EXAMPLE
   Connect-Subsystem -DeviceManager 10.128.34.95 -DeviceManagerID monty -Subsystem 230002 -subsystemID system
#>
    [CmdletBinding(DefaultParameterSetName='HUSVM')]
    
    Param
    (
        # IP Address of the Device Manager
        [Parameter(Mandatory=$true,
                   ParameterSetName='HUSVM')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("10.128.34.95")]
        [Alias("HCS")] 
        [string]
        $DeviceManager,

        # Device Manager ID (example: monty)
        [Parameter(Mandatory=$true,
                    ParameterSetName='HUSVM')]
        [string]
        $DeviceManagerID,

        # SubSystemID
        [Parameter(Mandatory=$true,
                    ParameterSetName='HUSVM')]
        [ValidateSet("230002")]
        [String]
        $SubsystemID,

        # Subsystem User ID (example: system)
        [Parameter(Mandatory=$true,
                    ParameterSetName='HUSVM')]
        [Parameter(Mandatory=$true,
                    ParameterSetName='HUS')]
        [string]
        $UserID,

        # IP Address of Controller0
        [Parameter(Mandatory=$true,
                   ParameterSetName='HUS')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("10.140.1.61","10.140.1.62")]
        [Alias("HUS0")] 
        [string]
        $Controller0,

        # IP Address of Controller1
        [Parameter(Mandatory=$true,
                   ParameterSetName='HUS')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("10.140.1.61","10.140.1.62")]
        [Alias("HUS1")] 
        [string]
        $Controller1

    )
    
    switch ($PSCmdlet.ParameterSetName)
    {
        'HUSVM' { Add-Subsystem -DeviceManager $DeviceManager -DeviceManagerUserID $DeviceManagerID -SubsystemID $SubsystemID -UserID $UserID }
        'HUS' { Add-SubSystem -Controller0 $Controller0 -Controller1 $Controller1 -UserID $UserID }
        Default { Write-Host "An Error occured with the specified ParameterSet:`t" $PSCmdlet.ParameterSetName }
    }
}

function Get-OSDiskInfo($HostComputer)
{
Get-WmiObject win32_diskdrive -ComputerName $HostComputer |
Select-Object @{name="OSDiskNumber";expression={[Int](($_.name) -replace "\D")}},
              @{name="SANLunNumber";expression={$_.scsilogicalunit}}, 
              @{name="SizeGb";expression={[math]::truncate($_.size/1GB)}},Model
}


##Verify that Pssnapin is installed
Check-LoadedSnapin -SnapinName Hitachi

$HostComputer = Read-Host "What is the hostname/ip of the computer to be unallocated? "
$HostGroup = ($HostComputer -replace "\d+$")
$StorageSerialNumber = "230002"

##Check for a valid hostname entry
 while(!$HostComputer){
    write-msg("No Hostname given.")
    $HostComputer = Read-Host "Please enter a Hostname or type exit to quit"
    
    if($HostComputer.ToLower() -eq "exit"){
    write-msg("Ending Program.")
    exit
  }
}
 while(!(test-connection $HostComputer -count 1 -quiet)){
    write-msg("$Hostcomputer is unavailable or not a valid host.")
    $HostComputer = Read-Host "Please enter a valid Hostname/ip or type exit to quit"
    
    if($HostComputer.ToLower() -eq "exit"){
    write-msg("Ending Program.")
    exit
  }
}

#Get all disk info from host
$OSLunInfo = Get-OSDiskInfo($HostComputer)
$PhysicalDiskNumber = ($OSLunInfo | where-object {$_.model -like "*hitachi*"}).OSDiskNumber
            
#Display all of the Hitachi disks on the system
Get-OSDiskInfo($HostComputer) | where-object {$_.model -like "*hitachi*"} | Sort-Object -property OSDiskNumber | ft -auto 

#Get the OS disk number to remove.
$DiskToRemove = Read-Host "Select the OSDiskNumber to remove: "

while($PhysicalDiskNumber -notcontains $DiskToRemove) {
    Write-ErrMsg("No disk by that number in this host.")

    $DiskToRemove = read-host "Please enter a valid disk number or type exit to quit program:"
        if($DiskToRemove.ToLower() -eq "exit"){
        Write-Msg("Ending Program.")
        exit
  }
 }


#Get the Lun number from the disk selection.
$HDSLunNumber = $OSLunInfo | where-object {$_.OSDiskNumber -eq $DiskToRemove} | select-object -ExpandProperty SANLunNumber

#Get the lun information from HUS-VM to match up with the disk number.
$LunInfo = get-lu -subsystem $StorageSerialNumber | where-object {($_.hostgroups.hlun -eq $HDSLunNumber) -and ($_.hostgroups.hostgroupname -like "*$HostGroup*")}
write-msg("Is this the Lun you want to remove?")

Get-OSDiskInfo($HostComputer) | where-object {$_.OSDiskNumber -eq $DiskToRemove} | ft -auto

#Get the volume number based on the hostgroup and OS lun number.
$LuNumber = $LunInfo | select-object -ExpandProperty lu

write-msg("HDSLun = $HDSLunNumber")
write-msg("With HDS volume number $LuNumber")

#Prompts the user if they want to remove the lun from the host.
    $title = "Unallocate Volume from $HostComputer ?"
    $message = "Do you want to unallocate disk: $DiskToRemove with Lun number: $HDSLunNumber ?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Unallocates the volume from the specified host or hosts if clustered."

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Exits the unallocate volume script without removing the disk."

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 1) 

    switch ($result)
        {
            0 {"You selected Yes. Removing disk:$DiskToRemove from $HostComputer."
                try{
                    Unpresent-Lu -Subsystem $StorageSerialNumber -lu $LuNumber -All -Erroraction Stop
                    }
                catch{
                    Write-ErrMsg ("Failed to remove disk from" + $HostComputer + " : $_.")
                    exit
                    }
              }

            1 {"You selected No. Ending Unallocation Script without removing disk:$DiskToRemove from $HostComputer."

              }
        }



