<#
	.SYNOPSIS
		Prepare Turbo.net Applications for Image Management
	.DESCRIPTION
	  	Update the turbo subscription
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

	  	History:
		17.03.2016 MS: Script created
		06.03.2017 MS: Bugfix read Variable $varCLI = ...
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured

	.LINK
		https://eucweb.com
#>

Begin {

	####################################################################
	# define environment
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)

	#product specified
	$Product = "Turbo.net"
	$ProductInstPath = "$ProgramFilesx86\Spoon\Cmd\Turbo.exe"

}

Process {

	####################################################################
	####### functions #####
	####################################################################

	function Set-TurboSupscriptionUpdate {
		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLITB = $LIC_BISF_CLI_TB
		IF (($varCLITB -eq "YES") -or ($varCLITB -eq "NO")) {
			Write-BISFLog -Msg "GPO Valuedata: $varCLI"
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$MPFullScan = "NO"
		}

		if (($MPTB -eq "YES" ) -or ($varCLITB -eq "YES")) {
			Write-BISFLog -Msg "The Turbo.net Supscription Update would be run on system startup" -ShowConsole -Color DarkCyan -SubMsg
			$answerTB = "YES"
		}
		ELSE {
			Write-BISFLog -Msg "The Turbo.net Supscription Update would NOT be run on system startup"
			$answerTB = "NO"
		}


		IF (($answerTB -eq "YES") -or ($answerTB -eq "NO")) {
			Write-BISFLog -Msg "set your Turbo.net answer to the registry $hklm_software_LIC_CTX_BISF_SCRIPTS, Name LIC_BISF_TurboRun, value $answerTB"
			Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_TurboRun" -value "$answerTB" -Force
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program

	IF (Test-Path ("$ProductInstPath") -PathType Leaf) {
		Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
		Set-TurboSupscriptionUpdate

	}
	ELSE {
		Write-BISFLog -Msg "Product $Product not installed"
	}
}

End {
	Add-BISFFinishLine
}