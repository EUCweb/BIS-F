﻿<#
    .SYNOPSIS
        Prepare F-Secure AntiVirus for Image Managemement
	.DESCRIPTION
      	Scan system and stop services
    .EXAMPLE
    .NOTES
		Author: Matthias Schlimm

		History:
		  29.07.2017 MS: Script created
		  14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		  03.10.2019 MS: ENH 51 - ADMX Extension: select AnitVirus full scan or custom Scan arguments

	.LINK
        https://eucweb.com
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

	# Product specified
	$Product = "F-Secure Anti-Virus"
	$Inst_path = "$ProgramFilesx86\F-Secure\Anti-Virus"
	$ServiceNames = @("FSAUA", "FSMA", "F-Secure Network Request Broker", "FSORSPClient", "F-Secure WebUI Daemon", "F-Secure Gatekeeper Handler Starter")
}

Process {

	####################################################################
	####### functions #####
	####################################################################


	function RunFullScan {

		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLI = $LIC_BISF_CLI_AV
		IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO Valuedata: $varCLI"
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg
			$AVScan = "YES"
		}
		if (($AVScan -eq "YES" ) -or ($varCLI -eq "YES")) {
			IF ($LIC_BISF_CLI_AV_VIE_CusScanArgsb -eq 1) {
				Write-BISFLog -Msg "Enable Custom Scan Arguments"
				$args = $LIC_BISF_CLI_AV_VIE_CusScanArgs
			}
			ELSE {
				$args = "c:\ /REPORT=C:\Windows\Logs\fsavlog.txt"
			}

			Write-BISFLog -Msg "Running Scan with arguments: $args"
			Start-Process -FilePath "$Inst_path\fsav.exe" -ArgumentList $args
			Show-BISFProgressBar -CheckProcess "$ScanProcess" -ActivityText "$Product is scanning the system...please wait"
			IF (Test-Path "C:\Windows\Logs\fsavlog.txt") {
				Get-BISFLogContent -GetLogFile "C:\Windows\Logs\fsavlog.txt"
				Remove-Item -Path "C:\Windows\Logs\fsavlog.txt" -Force
			}
		}
		ELSE {
			Write-BISFLog -Msg "No Scan would be performed"
		}

	}



	function StopService {
		ForEach ($ServiceName in $ServiceNames) {
			$svc = Test-BISFService -ServiceName "$ServiceName"
			IF ($svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop }
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	$svc = Test-BISFService -ServiceName $ServiceNames[1] -ProductName "$product"
	IF ($svc -eq $true) {
		RunFullScan
		StopService
	}
}


End {
	Add-BISFFinishLine
}
