<#
	.SYNOPSIS
		Prepare Microsoft Windows Defender for Image Management
	.DESCRIPTION
		Reconfigure Microsoft Windows Defender
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm, Florian Frank

		History:
		25.03.2014 MS: Script created
		01.04.2014 MS: Changed console message
		12.05.2014 MS: Changed Fullscan from Windows Defender directory to '$ProductPath\...'
		13.05.2014 MS: Added Silentswitch -AVFullScan (YES|NO)
		11.06.2014 MS: Syntax error to start silent pattern update and full scan, fix read variable LIC_BISF_CLI_AV
		13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		20.02.2015 MS: Added progress bar during full scan
		30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		06.03.2017 MS: Bugfix read Variable $varCLI = ...
		31.05.2017 FF: Added changes necessary to prepare Windows Defender and create a seperate script
		08.01.2017 JP: Replaced "C:\Program Files" with windows variable, fixed typos
		02.08.2017 MS: to much " at the end of Line 44, breaks script to fail
		17.08.2017 FF: Program is named "Windows Defender", not "Microsoft Windows Defender", fixed typos
		08.09.2017 FF: Feature 182 - Windows Defender Signature will only be updated if Defender is enabled to run
		20.10.2018 MS: Bugfix 55: Windows Defender -ArgumentList failing
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		03.10.2019 MS: ENH 51 - ADMX Extension: select AnitVirus full scan or custom Scan arguments
		21.11.2020 MS: HF 284 - MPCmdRun Process monitor with the current user only, exclude other accounts

	.LINK
		https://eucweb.com
	.LINK
		https://docs.microsoft.com/en-us/windows/threat-protection/windows-defender-antivirus/deployment-vdi-windows-defender-antivirus
	.LINK
		https://docs.microsoft.com/en-us/windows/threat-protection/windows-defender-antivirus/command-line-arguments-windows-defender-antivirus
#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	$Product = "Windows Defender"
	$ProductPath = "${env:ProgramFiles}\$Product"
	$ServiceName = 'WinDefend'
}

Process {

	function MSCrun {
		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLI = $LIC_BISF_CLI_AV

		If (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO Valuedata: $varCLI"
		}
		Else {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$AVScan = "YES"
		}

		If (($AVScan -eq "YES" ) -or ($varCLI -eq "YES")) {
			Write-BISFLog -Msg "Updating virus signatures... please wait"
			Start-Process -FilePath "$ProductPath\MpCMDrun.exe" -ArgumentList "-SignatureUpdate" -WindowStyle Hidden
			$procID = (Get-Process -Name "MpCMDrun" | ? { $_.SI -eq (Get-Process -PID $PID).SessionId }).Id # get MPCmdRun for the current user only
			Show-BISFProgressBar -CheckProcessId $procID -ActivityText "$Product is updating the virus signatures...please wait"

			IF ($LIC_BISF_CLI_AV_VIE_CusScanArgsb -eq 1) {
				Write-BISFLog -Msg "Enable Custom Scan Arguments"
				$args = $LIC_BISF_CLI_AV_VIE_CusScanArgs
			}
			ELSE {
				$args = "-scan -scantype 2"
			}

			Write-BISFLog -Msg "Running Scan with arguments: $args"
			#Gather process info for the MpCmdRun process so we can pass the correct ID to Show-BISFProgressBar
			$MpCmdRunProc = Start-Process -FilePath "$ProductPath\MpCMDrun.exe" -ArgumentList $args -WindowStyle Hidden -PassThru
			Show-BISFProgressBar -CheckProcessId $MpCmdRunProc.Id -ActivityText "$Product is scanning the system...please wait"
		}
		Else {
			Write-BISFLog -Msg "No Scan will be performed"
		}
	}

	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program
	If (Test-BISFService -ServiceName $ServiceName) {
		If ((Get-Service -Name $ServiceName).Status -eq 'Running') {
			Write-BISFLog -Msg "$Product is installed and activated" -ShowConsole -Color Cyan
			MSCrun
		}
		Else {
			Write-BISFLog -Msg "$Product is installed, but not activated"
		}
	}
	Else {
		Write-BISFLog -Msg "$Product is not installed"
	}

}

End {
	Add-BISFFinishLine
}