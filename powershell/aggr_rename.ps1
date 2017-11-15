$controller = "192.168.5.20"
$secpasswd = convertto-securestring "netapp123" -asplaintext -force
$mycreds = New-Object System.Management.Automation.PSCredential ("admin", $secpasswd)

try{
    Connect-NcController $controller -Credential $mycreds -ErrorAction stop | Out-Null
    "Successfully connected to $controller"
    }
catch {
    "Unable to connect to $controller"
    }
$nodes = (get-ncnode).node
foreach ($node in $nodes) {

$AggrNodeName = ($node -replace "-0")
$NewAggrName = ("aggr0_" + $AggrNodeName)
try {
$renameaggr = get-ncaggr | ? {$_.name -like "*aggr0*" -and $_.nodes -eq "$node"} | rename-ncaggr -newname $NewAggrName -erroraction stop
"Successfully renamed node root aggregate to $NewAggrName"
    }
catch
    {
 "Unable to rename node root aggregate with error: $_" 
    }
} ##end foreach