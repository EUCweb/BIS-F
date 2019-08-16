<#
	.SYNOPSIS
		Personalize Turbo.net Applications for Image Management
	.DESCRIPTION
	  	Update the turbo subscription
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company: Login Consultants Germany GmbH

	  	History:
		22.03.2016 MS: Script created
		16.08.2019 MS: Add-BISFStartLine
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
	$Tas

}

Process {
	Add-BISFStartLine -ScriptName $PSScriptName
	####################################################################
	####### functions #####
	####################################################################

	function Invoke-TurboSupscriptionUpdate {
		$varTB = Get-Variable -Name LIC_BISF_TurboRun -ValueOnly
		Write-BISFLog -Msg "The Turbo Subscription Update would be set to the Value $($varTB) in the registry"

		IF ($varTB -eq "YES") {
			Write-BISFLog -Msg "Running Turbo Update Subscription Now"
			Invoke-Expression (Get-ScheduledTask -TaskPath "\turbo-net\" | Start-ScheduledTask)
			Show-ProgressBar -CheckProcess "Turbo" -ActivityText "Running Turbo Subscription Update"
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program

	IF (Test-Path ("$ProductInstPath") -PathType Leaf) {
		Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
		Invoke-TurboSupscriptionUpdate

	}
	ELSE {
		Write-BISFLog -Msg "Product $Product not installed"
	}
}

End {
	Add-BISFFinishLine
}