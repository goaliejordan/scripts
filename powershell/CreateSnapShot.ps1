Get-VM $_.Name | New-Snapshot -Name "Pre-change snapshot" -Quiesce:$true -Confirm:$false