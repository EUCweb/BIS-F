﻿<#
	.SYNOPSIS
		Prepare TrenMicro OfficeScan for Image Managemement
	.DESCRIPTION
	  	Delete computer specified entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	17.09.2014 MS: Script created
		10.08.2015 MS: Kill Tasks of each TM Process before stops the services
		01.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		06.03.2017 MS: Bugfix read Variable $varCLI = ...
		01.08.2017 JS: Updated ini file and delete run value as per https://success.trendmicro.com/solution/1102736
		This should be implemented for both RDS and VDI workloads, especially if using published
		applications, as it prevents the PccNTMon.exe process from running in user sessions, which
		means that the OfficeScan (OSCE) Agent or WFBS-SVC (Worry-Free Business Security Services)
		icon is unavailable in the system tray.
		Added the TmPfw (OfficeScan NT Firewall) service to the array.
		20.08.2017 JS: I found that the services were not being stopped and set to manual, so added a new TerminateProcess
		function and modified the StopService function to make it reliable.
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured


	.LINK
		https://eucweb.com
#>

Begin {
	$reg_TM_string = "$HKLM_sw_x86\TrendMicro\PC-cillinNTCorp\CurrentVersion"
	[array]$reg_TM_name = "GUID"
	$product = "Trend Micro Office Scan"
	# The main 4 services are:
	# - TmListen (OfficeScan NT Listener)
	# - NTRTScan (OfficeScan NT RealTime Scan)
	# - TmPfw (OfficeScan NT Firewall)
	# - TmProxy (OfficeScan NT Proxy Service)
	$TMServices = @("TmListen", "NTRTScan", "TmProxy", "TmPfw")
	$TMProcesses = @("TmListen.exe", "NTRTScan.exe", "TmProxy.exe", "TmPfw.exe", "PccNTMon.exe")
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
}

Process {

	####################################################################
	####### functions #####
	####################################################################

	function RunFullScan {

		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLI = $LIC_PVS_CLI_AV
		IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO Valuedata: $varCLI"
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$AVScan = "YES"
		}
		if (($AVScan -eq "YES" ) -or ($varCLI -eq "YES")) {
			Write-BISFLog -Msg "Running Fullscan... please Wait"
			#TrendMicro does support SysClen to scan system fromm CLI, but the needed an current patternfile in the same folder as sysclean
		}
		ELSE {
			Write-BISFLog -Msg "No Full Scan would be performed"
		}

	}

	function deleteTMData {
		foreach ($key in $reg_TM_name) {
			Write-BISFLog -Msg "delete specified registry items in $reg_TM_string..."
			Write-BISFLog -Msg "delete $key"
			Remove-ItemProperty -Path $reg_TM_string -Name $key -ErrorAction SilentlyContinue
		}
	}

	Function TerminateProcess {
		ForEach ($ProcessName in $TMProcesses) {
			Write-BISFLog -Msg "Process '$ProcessName' is running, kill process now" -ShowConsole -SubMsg -Color DarkCyan
			$CommandLineContains = ""
			$delaystart = 0
			$interval = 1
			$repeat = 5
			$exitwhenfound = $True
			Start-Sleep -Seconds $delaystart
			if ([String]::IsNullOrEmpty($CommandLineContains)) {
				#Write-Verbose "Killing the '$ProcessName' process..." -verbose
			}
			Else {
				#Write-Verbose "Killing the '$ProcessName' process which contains `"$CommandLineContains`" in it's command line..." -verbose
			}
			Do {
				$i = 0
				Do {
					$ProcessFound = $False
					Try {
						$Processes = Get-CimInstance -ClassName Win32_Process -Filter "name='$ProcessName'" -ErrorAction Stop | Where-Object { $_.commandline -Like "*$CommandLineContains*" }
					}
					Catch {
						#write-verbose $_.Exception.InnerException.Message -verbose
					}
					If (($Processes | Measure-Object).Count -gt 0) {
						$ProcessFound = $True
					}
					$i++
					If ($i -eq $repeat) {
						break
					}
					Start-Sleep -Seconds $interval
				} Until ($ProcessFound -eq $true)
				If ($ProcessFound) {
					#write-verbose "Process '$ProcessName' was found." -verbose
					if (!([String]::IsNullOrEmpty($CommandLineContains))) {
						#write-verbose "Process command line contains: '$CommandLineContains'" -verbose
					}
					ForEach ($Process in $Processes) {
						Try {
							$Return = ([wmi]$Process.__RELPATH).terminate()
							If ($Return.ReturnValue -eq 0) {
								#write-verbose "Process terminated without error." -verbose
							}
							Else {
								#write-verbose "Process failed to terminate: $($Return.ReturnValue)" -verbose
							}
						}
						Catch {
							#write-verbose $_.Exception.Message -verbose
						}
					}
				}
				Else {
					If ($exitwhenfound) {
						#write-verbose "Process '$ProcessName' was not found. Giving up!" -verbose
						Write-BISFLog -Msg "Process '$ProcessName' was not found. Giving up!"
					}
					Else {
						#write-verbose "Process '$ProcessName' was not found. Trying again!" -verbose
						Write-BISFLog -Msg "Process '$ProcessName' was not found. Trying again!"
					}
				}
			} Until ($exitwhenfound -eq $true)
		}
	}

	function StopService {
		ForEach ($ServiceName in $TMServices) {
			$objService = Get-Service $ServiceName -ErrorAction SilentlyContinue
			If ($objService) {
				Write-BISFLog -Msg "Setting the '$ServiceName' service to manual start" -ShowConsole -SubMsg -Color DarkCyan
				#Write-Verbose "Setting the '$ServiceName' service to manual start..." -verbose
				#Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop -StartType manual
				# Possible results using the sc.exe command line tool:
				#   [SC] ChangeServiceConfig2 SUCCESS
				#   [SC] OpenSCManager FAILED 5:  Access is denied.
				#   [SC] OpenSCManager FAILED 1722:  The RPC server is unavailable.
				#   [SC] OpenService FAILED 1060:  The specified service does not exist as an installed service.
				$result = sc.exe config $ServiceName start= demand
				#write-verbose $result -verbose
			}
			Else {
				Write-BISFLog -Msg "Service '$ServiceName' is not installed"
			}
		}
	}

	# Stopping multiple instances of PCCNTmon.exe processes running on the Terminal (RDS) server
	# https://success.trendmicro.com/solution/1102736
	function UpdateINIFile {
		$inifile = "${env:ProgramFiles(x86)}\Trend Micro\OfficeScan Client\ofcscan.ini"
		If (Test-Path -Path "$inifile") {
			Write-BISFLog -Msg "Updating $inifile" -ShowConsole -SubMsg -Color DarkCyan
			$inicontents = Get-Content "$inifile"
			$inicontents = $inicontents | ForEach-Object { $_ -replace '^NT_RUN_KEY=.+$', "NT_RUN_KEY=" }
			$inicontents = $inicontents | ForEach-Object { $_ -replace '^NT_RUN_KEY_FILE_NAME=.+$', "NT_RUN_KEY_FILE_NAME=" }
			$inicontents | Set-Content $inifile
			# Note that you will get an access denied error when writing back to the ofcscan.ini file if the
			# services/processes are still running.
		}
	}
	function DeleteRunValue {
		$keypath = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
		$value = "OfficeScanNT Monitor"
		$IsValueMissing = (Get-ItemProperty $keypath).$value -eq $null
		If ($IsValueMissing -eq $False) {
			Write-BISFLog -Msg "Removing the $value value from the Run key" -ShowConsole -SubMsg -Color DarkCyan
			Remove-ItemProperty -path $keypath -name $value
		}
	}

	####### end functions #####


	#### Main Program
	$svc = Test-BISFService -ServiceName $TMServices[0] -ProductName "$product"
	IF ($svc -eq $true) {
		#RunFullScan  <<-currently not specified, see above...
		TerminateProcess
		StopService
		deleteTMData
		UpdateINIFile
		DeleteRunValue
	}
}

End {
	Add-BISFFinishLine
}