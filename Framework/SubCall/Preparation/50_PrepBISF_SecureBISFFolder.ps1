<#
	.SYNOPSIS
		Secure BISF Folder for user access
	.DESCRIPTION
		Prevent access for users to the BISF Rootfolder
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Company: Login Consultants Germany GmbH

		History:
		28.05.2015 MB: Script created
		12.08.2015 MS: integrated in BIS-F
		01.10.2015 MS: rewritten script with standard

	.LINK
		https://eucweb.com
#>

Begin {
	$RootBISFFolder = Split-Path (Split-Path $LIC_BISF_MAIN_PersScript)
	$Product = $FrameworkName
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
}

Process {

	IF ((Test-Path $RootBISFFolder) -eq $true) {
		Write-BISFLog -Msg "$Product installed, securing folder" -ShowConsole -Color Cyan
		try {
			$result = Invoke-Expression -command "icacls.exe `"$RootBISFFolder`" /inheritance:d /remove users"
			Write-BISFLog -Msg "User access on the folder `"$RootBISFFolder`" is removed." -ShowConsole -Color DarkCyan -SubMsg
		}
		catch {
			Write-Log -BISFMsg "Error removing User access on the folder `"$RootBISFFolder`". The output of the action is: $result" -Type W -SubMsg
		}
	}
	ELSE {
		Write-Log -Msg "$Product NOT installed" -Type E

	}

}

End {
	Add-BISFFinishLine
}