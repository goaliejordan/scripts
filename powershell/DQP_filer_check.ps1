## This script queries the filers in a list for the Datecode of the Disk Qualification package
## The Current Datecode can be found here: http://mysupport.netapp.com/NOW/download/tools/diskfw/
## Use that datecode to compare with the datecode that is added to the list of filersDQP.csv

#Define Functions
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


##Define the Login to use to connect to each filer.
$user = "root"
$password = ConvertTo-SecureString "Jbod4you" -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user,$password


##Get the list of filers from the file and loop through each one.
Get-Content C:\users\jordan.smith\Desktop\filers.txt | % {
##Connect to the controller
    try {
        Connect-nccontroller $_ -Credential $cred -ErrorAction Stop | Out-Null   
        "connected to " + $_
    }
    catch {
        Write-ErrMsg ("Failed connecting to Filer $_.")
        exit
}
##Invoke SSH command to read the disk package.
    try { 
        invoke-nassh -command 'rdfile /etc/qual_devices_v3' -ErrorAction stop >> C:\users\jordan.smith\Desktop\filersDQP.txt
    }
    catch { 
        Write-ErrMsg ("Failed gathering DQP from Filer $_.")
        exit
    }

}