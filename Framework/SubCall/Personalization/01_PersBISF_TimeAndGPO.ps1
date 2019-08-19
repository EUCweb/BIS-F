<#
	.SYNOPSIS
		Update Time and Reapply GPO
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Benjamin Ruoff
	  	Company: Login Consultants Germany GmbH

		History:
	  	27.10.2014 BR: Script created
		15.10.2014 JP: Added wait:0 parameter fo gpupdate
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		26.10.2015 BR: Delay between Timesync and GPO apply
		02.08.2016 MS: With AppLayering in OS-Layer do nothing
		31.08.2017 MS: Change sleep timer from 60 to 5 seconds after time sync on startup
		11.09.2017 MS: Change sleep timer from 5 to 20 seconds after time sync on startup

	.LINK
		https://eucweb.com
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

}

Process {
	
	IF (!($CTXAppLayerName -eq "OS-Layer")) {
		# Resync Time with Domain
		Write-BISFLog -Msg "Syncing Time from Domain"
		& "$env:SystemRoot\system32\w32tm.exe" /config /update
		& "$env:SystemRoot\system32\w32tm.exe" /resync /nowait
		sleep 20
		# Reapply Computer GPO
		Write-BISFLog "Apply Computer GPO"
		& "$env:SystemRoot\system32\gpupdate.exe" /Target:Computer /Force /Wait:0
	}
	ELSE {
		Write-BISFLog -Msg "Do nothing in AppLayering $CTXAppLayerName"
	}
}

End {
	Add-BISFFinishLine
}