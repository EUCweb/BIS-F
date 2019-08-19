<#
	.SYNOPSIS
		Prepare Microsoft Security Client for Image Management
	.DESCRIPTION
	  	Reconfigure the Microsoft Security Client
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company: Login Consultants Germany GmbH

		History:
	  	25.03.2014 MS: Script created
		01.04.2014 MS: Changed Console message
		12.05.2014 MS: Changed Fullscan from Windows Defender directory to '$MSC_path\...'
		13.05.2014 MS: Added Silentswitch -AVFullScan (YES|NO)
		11.06.2014 MS: Syntax error to start silent pattern update and fullscan, fix read variable LIC_BISF_CLI_AV
		13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		20.02.2015 MS: Added progressbar during fullscan
		30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		06.03.2017 MS: Bugfix read Variable $varCLI = ...

		16.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
	.LINK
		https://eucweb.com
#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	$product = "Microsoft Security Client"
	$MSC_path = "C:\Program Files\$product"
}

Process {

	function MSCrun {

		Write-BISFLog -Msg "Update VirusSignatures"
		& "$MSC_path\MpCMDrun.exe" -SignatureUpdate

		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLI = $LIC_BISF_CLI_AV

		IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO Valuedata: $varCLI"
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$MPFullScan = "YES"
		}

		if (($MPFullScan -eq "YES" ) -or ($varCLI -eq "YES")) {
			Write-BISFLog -Msg "Running Fullscan... please Wait"
			Start-Process -FilePath "$MSC_path\MpCMDrun.exe" -ArgumentList "-scan -scantype 2"
			Show-ProgressBar -CheckProcess "MpCMDrun" -ActivityText "$Product is scanning the system...please wait"
		}
		ELSE {
			Write-BISFLog -Msg "No Full Scan would be performed"
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	IF (Test-Path ("$MSC_path\MpCMDRun.exe") -PathType Leaf ) {
		Write-BISFLog -Msg "$Product installed" -ShowConsole -Color Cyan
		MSCrun
	}
	ELSE {
		Write-BISFLog -Msg "$Product not installed"
	}

}

End {
	Add-BISFFinishLine
}