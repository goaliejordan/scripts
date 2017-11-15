param ( [parameter(Mandatory=$true, HelpMessage="Array name or IP address")] [string]$Array, 
[parameter(Mandatory=$true, HelpMessage="Volume name")] [string]$VolumeName, 
[parameter(Mandatory=$false, HelpMessage="Qtree name")] [string]$QtreeName, 
[parameter(Mandatory=$false, HelpMessage="List of root hosts")] [array]$RootHosts, 
[parameter(Mandatory=$false, HelpMessage="List or read/write hosts")] [array]$RWhosts, 
[parameter(Mandatory=$false, HelpMessage="List of read only hosts")] [array]$ROhosts, 
[parameter(Mandatory=$false, HelpMessage="vFiler name")] [string]$VFilerName )

function GetExistingHosts { param ( [parameter(Mandatory=$true)] [string]$ListType, 
[parameter(Mandatory=$true)] [DataONTAP.Types.Nfs.SecurityRuleInfo]$SecurityRuleInfo, 
[parameter(Mandatory=$false)] [array]$RemoveHosts ) 

$data = $SecurityRuleInfo.$ListType 
$exsistingHosts = @() 

if($data)
	{ foreach($exportInfo in $data) 
		{ if($exportInfo.AllHosts) 
			{ $exsistingHosts = "all-hosts" break; } 
		  else { if($RemoveHosts -contains $exportInfo.Name) 
				{ ## Since the host was found, do not add 
				Get-WFALogger -Info -message $("Remove host (" + $exportInfo.Name + ") from RuleSet: " + $ListType) } 
		  else { $exsistingHosts += $exportInfo.Name } 
		  } 
		} 
	} 
		  else { $exsistingHosts = $Null } 
				return $exsistingHosts } 
# connect to controller 
Connect-WFAController -Array $Array -VFiler $VFilerName 
# calculating full path 
	if($QtreeName) 
		{ $Path = "/vol/" + $VolumeName + "/" + $QtreeName } 
	else { $Path = "/vol/" + $VolumeName } 
	# validate path existence 
Get-WFALogger -Info -message $("Checking for NFS exports at path: " + $export.Pathname) 
$exports = Get-NaNfsExport -Path $Path -Persistent 
	if(!$exports) 
		{ $exports = Get-NaNfsExport -Persistent | where {$_.ActualPathname -eq $Path} } 
	if(!$exports) 
		{ throw "Export with path $Path not found" } 
$failureCount = 0 
	foreach($export in $exports) 
		{ # get the rule for the provided export 
			$securityRule = $export.SecurityRules[0] 
			$newRoots = GetExistingHosts -ListType Root -SecurityRuleInfo $securityRule -RemoveHosts $RootHosts 
			$newRWHosts = GetExistingHosts -ListType ReadWrite -SecurityRuleInfo $securityRule -RemoveHosts $RWhosts 
			$newROHosts = GetExistingHosts -ListType ReadOnly -SecurityRuleInfo $securityRule -RemoveHosts $ROhosts Get-WFALogger -Info -message $("Setting NFS export security rules on path: " + $export.Pathname) 
				try { if($securityRule.NosuidSpecified) 
						{ Set-NaNfsExport -Path $export.Pathname -Persistent -Root $newRoots -ReadOnly $newROHosts -ReadWrite $newRWHosts ` -Anon ($securityRule.Anon) -ActualPath $export.ActualPathname -SecurityFlavors ($securityRule.SecFlavor) ` -NoSuid -ErrorAction Stop } 
					  else { Set-NaNfsExport -Path $export.Pathname -Persistent -Root $newRoots -ReadOnly $newROHosts -ReadWrite $newRWHosts ` -Anon ($securityRule.Anon) -ActualPath $export.ActualPathname -SecurityFlavors ($securityRule.SecFlavor) -ErrorAction Stop } 
					} 
				catch { Get-WFALogger -Info -Warn $("Error setting NFS export security rules on path: " + $export.Pathname) $failureCount++ }
		} 
		if($failureCount -eq $exports.Length) 
			{ throw "Failed to update all exports on path $Path" }</