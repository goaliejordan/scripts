##update-ncvol template
param (
  [parameter(Mandatory=$true, HelpMessage="Volume name")]
  [string]$VolumeName,

  [parameter(Mandatory=$true, HelpMessage="Storage Virtual Machine name")]
  [string]$VserverName,

  [parameter(Mandatory=$false, HelpMessage="Name of the export policy to be attached to the Volume.")]
  [string]$ExportPolicyName,

  [parameter(Mandatory=$false, HelpMessage="UNIX permission bits for the volume in octal string format.")]
  [string]$UNIXPermissions

  
)

$attributeTemplate = Get-NcVol -Template

if($ExportPolicyName)
{
	Initialize-NcObjectProperty $attributeTemplate VolumeExportAttributes
	$attributeTemplate.VolumeExportAttributes.Policy = $ExportPolicyName
}

if($UNIXPermissions)
{
	Initialize-NcObjectProperty $attributeTemplate VolumeSecurityAttributes
	Initialize-NcObjectProperty $attributeTemplate.VolumeSecurityAttributes VolumeSecurityUnixAttributes
	$attributeTemplate.VolumeSecurityAttributes.VolumeSecurityUnixAttributes.Permissions = $UNIXPermissions
}
	
$queryTemplate = Get-NcVol -Template

Initialize-NcObjectProperty $queryTemplate VolumeIdAttributes
$queryTemplate.VolumeIdAttributes.Name = $VolumeName
$queryTemplate.VolumeIdAttributes.OwningVserverName = $VserverName
	
write-host("Modifying volume: " + $VolumeName + " on Storage Virtual Machine " + $VserverName)
Update-NcVol -Query $queryTemplate -Attributes $attributeTemplate