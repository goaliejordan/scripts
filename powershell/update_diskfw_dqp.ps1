<#  
.SYNOPSIS  
   Uploads a given Disk Firmware and/or Disk Qualification Package to a 7-Mode controller.  
.DESCRIPTION  
   Disk Firmware and/or Disk Qualification Package are uploaded using this Cmdlet by using the etc$ share of a 7-mode controller.  
  
   Connection is done using a PSDrive.  
  
   Requires PowerShell 3.0 or higher  
.PARAMETER PathDFW  
   Path to the Disk Firmware (either zipped file or unzipped folder).  
.PARAMETER PathDQP  
   Path to the Disk Qualification Package (either zipped zile or unzipped folder).  
.PARAMETER Credential  
   Credentials used to connect to the etc$ share of the 7-mode controller.  
.PARAMETER Controller  
   PSController to upload the files to. If no controller is specified the $global:CurrentNaController is used.  
.PARAMETER NoBackgroundUpdate  
   Switch to disable the automatic background firmware update after uploading the Disk Firmware (not applicable if only Disk Qualification Package is uploaded).  
.EXAMPLE  
  
#>  
param (  
 [Parameter(Position=1,Mandatory=$False,ValueFromPipeline=$false)]  
  [String]$PathDFW,  
 [Parameter(Position=2,Mandatory=$False,ValueFromPipeline=$false)]  
  [String]$PathDQP,  
 [Parameter(Position=3,Mandatory=$True,ValueFromPipeline=$false)]  
  $Credential,  
 [Parameter(Position=4,Mandatory=$False,ValueFromPipeline=$false)]  
 [ValidateScript({($_ -is [NetApp.Ontapi.Filer.NaController]) -and ($_ -ne $null)})]  
  $Controller = $global:CurrentNaController,  
 [Parameter(Mandatory=$False,ValueFromPipeline=$false)]    
  [Switch]$NoBackgroundUpdate  
)
## download the package from the web
$source = "http://yoursite.com/file.xml"
$destination = "c:\application\data\newdata.xml"
 
Invoke-WebRequest $source -OutFile $destination

$continue     = $true  
$DFW_unzip    = $false  
$DQP_unzip    = $false  
$DFW_uploaded = $false  
#region "Check parameters"  
# Check DataONTAP module  
if (Get-Module -ListAvailable DataONTAP) {  
 Import-Module DataONTAP  
} else {  
 Write-Error ("Required Module 'DataONTAP' is missing.")  
 $continue = $false  
}  
# Check $PathDFW and $PathDQP variable  
if (!$PathDFW -and !$PathDQP) {  
 Write-Error ("No Disk Firmware and Disk Qualification Package file specified.")  
 $continue = $false  
} else {  
 if ($PathDFW) {  
  if (Test-Path -Path $PathDFW -PathType Leaf) {  
   if ((Get-ChildItem $PathDFW).Extension -like ".zip") {  
    Write-Output "Disk Firmware file detected (zipped). Unzipping will be executed before upload."  
    $DFW_unzip = $true  
   } else {  
    Write-Error ("Invalid Disk Firmware file path specified.")  
    $continue = $false  
   }  
  } else {  
   if (Get-ChildItem $PathDFW -Recurse -Include *.lod,*.ctl) {  
    Write-Output "Disk Firmware files detected (unzipped)."  
   } else {  
    Write-Error ("Invalid Disk Firmware file path specified.")  
    $continue = $false  
   }  
  }  
 }  
 if ($PathDQP) {  
  if (Test-Path -Path $PathDQP -PathType Leaf) {  
   if ((Get-ChildItem $PathDQP).Extension -like ".zip") {  
    Write-Output "Disk Qualification Package file detected (zipped). Unzipping will be executed before upload."  
    $DQP_unzip = $true  
   } else {  
    Write-Error ("Invalid Disk Qualification Package file path specified.")  
    $continue = $false  
   }  
  } else {  
   if (Get-ChildItem $PathDQP -Recurse -include qual_device*) {  
    Write-Output "Disk Qualification Package files detected (unzipped)."  
   } else {  
    Write-Error ("Invalid Disk Qualification Package file path specified.")  
    $continue = $false  
   }  
  }  
 }  
}  
# Check $Controller variable  
if ($Controller -eq $null) {  
 if ($global:CurrentNaController -ne $null) {  
  $Controller = $global:CurrentNaController  
 } else {  
  Write-Error ("No existing connection to a controller found.")  
  $continue = $false  
 }  
}  
# Check $Credential variable  
If ($continue -and $Credential -and ($Credential.GetType().Fullname -ne "System.Management.Automation.PSCredential")) {  
   
 $Credential = Get-Credential $Credential  
   
 If ($Credential.GetType().Fullname -ne "System.Management.Automation.PSCredential") {  
  Write-Error ("No credential specified. Unable to connect to controller.")  
  $continue = $false  
 }  
}  
if (!$PathDFW -and $NoBackgroundUpdate) {  
 Write-Warning ("No Disk Firmware file specified. Background update settings are not updated.")  
}  
#endregion  
if ($continue) {  
   
 #region "Define variables"  
   
 if ($PathDFW) {  
  $DFW_zipped                 = Convert-Path $PathDFW  
  $DFW_unzipped_parenpath     = Split-Path ($DFW_zipped) -Parent  
  $DFW_unzipped_foldername    = "all\"  
  $DFW_unzipped_path          = $(Join-Path -Path $DFW_unzipped_parenpath -ChildPath $DFW_unzipped_foldername)  
  $DFW_destination_foldername = "disk_fw\"  
 }  
   
 if ($PathDQP) {  
  $DQP_zipped                 = Convert-Path $PathDQP  
  $DQP_unzipped_parenpath     = Split-Path ($DQP_zipped) -Parent  
  $DQP_unzipped_foldername    = "DQP\"  
  $DQP_unzipped_path          = $(Join-Path -Path $DQP_unzipped_parenpath -ChildPath $DQP_unzipped_foldername)  
  $DQP_destination_foldername = "\"  
 }  
   
 $controller_share             = "\\" + $Controller.Name + "\etc$"  
 $controller_share_drivename   = "ScriptWorkDir"  
 $controller_share_driveletter = $controller_share_drivename + ":"  
   
 #endregion  
   
 #region "Unzip files"  
   
 $shell_app = New-Object -ComObject Shell.Application  
   
 if ($DFW_unzip) {  
    
  if (Test-Path $DFW_unzipped_path) {  
   Remove-Item $DFW_unzipped_path -Recurse -Force  
  }  
  New-Item -ItemType directory -Path $DFW_unzipped_path | Out-Null  
    
  $zip_file = $shell_app.Namespace($DFW_zipped)  
  $unzipped_folder = $shell_app.Namespace($DFW_unzipped_path)  
  $unzipped_folder.Copyhere($zip_file.Items())  
    
  $zip_file = $null  
  $unzipped_folder = $null  
    
  Write-Output ("Disk Firmware files extracted to {0} " -f $DFW_unzipped_path)  
   
 } else {  
    
  $DFW_unzipped_path = $DFW_zipped  
    
 }  
   
 if ($DQP_unzip) {  
    
  if (Test-Path $DQP_unzipped_path) {  
   Remove-Item $DQP_unzipped_path -Recurse -Force  
  }  
  New-Item -ItemType directory -Path $DQP_unzipped_path | Out-Null  
    
  $zip_file = $shell_app.Namespace($DQP_zipped)  
  $unzipped_folder = $shell_app.Namespace($DQP_unzipped_path)  
  $unzipped_folder.Copyhere($zip_file.Items())  
    
  $zip_file = $null  
  $unzipped_folder = $null  
  $shell_app = $null  
  Write-Output ("Disk Qualification Package files extracted to {0} " -f $DQP_unzipped_path)  
    
 } else {  
    
  $DQP_unzipped_path = $DQP_zipped  
    
 }  
   
 $shell_app = $null  
      
 #endregion  
   
 #region "Copy files to controller"  
 New-PSDrive -name $controller_share_drivename -PSProvider FileSystem -Root $controller_share -Credential $Credential | Out-Null  
   
 If (Test-Path $controller_share_driveletter) {  
    
  Write-Output ("{0} connected as PSDrive '{1}'" -f $controller_share, $controller_share_drivename)  
    
  if ($PathDFW) {  
     
   $DFW_destination_path = Join-Path -Path $controller_share_driveletter -ChildPath $DFW_destination_foldername  
   Get-ChildItem -Path $DFW_unzipped_path -Recurse | ? {!$_.PSIsContainer} | % { Copy-Item -Path $_.fullname -Destination $DFW_destination_path -Force }  
   Write-Output ("Disk Firmware files uploaded at {0}" -f $DFW_destination_path)  
     
   $DFW_uploaded = $true  
     
  }  
    
  if ($PathDQP) {  
     
   $DQP_destination_path = Join-Path -Path $controller_share_driveletter -ChildPath $DQP_destination_foldername  
   Get-ChildItem -Path $DQP_unzipped_path -Recurse | ? {!$_.PSIsContainer} | % { Copy-Item -Path $_.fullname -Destination $DQP_destination_path -Force }  
   Write-Output ("Disk Qualification Package files uploaded at {0}" -f $DQP_destination_path)  
     
  }  
    
  #$net.RemoveNetworkDrive($controller_share_driveletter)  
  Remove-PSDrive -Name $controller_share_drivename  
  Write-Output ("{0} disconnected as PSDrive '{1}'" -f $controller_share, $controller_share_drivename)  
    
 } else {  
    
  Write-Error ("Unable to connect to {0}. Please check the share and/or credentials." -f $controller_share)  
    
 }  
   
 if ($DFW_unzip) {  
  Remove-Item $DFW_unzipped_path -Recurse -Force  
  Write-Output ("Disk Firmware files (unzipped) removed at {0} " -f $DFW_unzipped_path)  
 }  
   
 if ($DQP_unzip) {  
  Remove-Item $DQP_unzipped_path -Recurse -Force  
  Write-Output ("Disk Qualification Package files (unzipped) removed at {0} " -f $DQP_unzipped_path)  
 }  
     
 #endregion  
   
 <##region "Enable background firmware update"  
 if ($PathDFW -and $DFW_uploaded) {  
  if ($NoBackgroundUpdate) {  
   Set-NaOption -Controller $Controller -OptionName raid.background_disk_fw_update.enable -OptionValue off | Out-Null  
   Write-Output ("Background Disk Firmware update disabled on {0} (raid.background_disk_fw_update.enable off)" -f $Controller.Name)  
  } else {  
   Set-NaOption -Controller $Controller -OptionName raid.background_disk_fw_update.enable -OptionValue on |Out-Null  
   Write-Output ("Background Disk Firmware update enabled on {0} (raid.background_disk_fw_update.enable on)" -f $Controller.Name)  
  }  
 }  
#>  
 #endregion  
  
}  

# Here an example for performing a disk firmware and disk qualification package update on multiple controllers listed in a simple text file:
# $cred = Get-Credential <username_for_share_access>
# Get-Content .\controllers.txt | % {
#     Connect-NaController $_
#     .\Upload-NaDiskFirmware.ps1 -PathDFW <path_to_disk_firmware> -PathDQP <path_to_disk_qualification_package> -Credential $cred
#}