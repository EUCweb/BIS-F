﻿<#
	.SYNOPSIS
		Configure several System Startup Actions (SSA)
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
	  	11.08.2015 BR: Script created
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		22.03.2016 MS: Added SDelete to run on the WriteCacheDisk on PVS Target Devices only
		10.11.2016 MS: SDelete will no longer be ditributed by BISF, it must be installed in C:\Windows\system32
		12.03.2017 MS: get WCDrive from $LIC_BISF_CLI_WCD insted of PVSWriteCacheDisk System Variable, it can be configured via ADMX now
		01.08.2017 MS: change sdeletePath, it can be set to a custom value
		02.08.2017 MS: With DiskMode AppLayering in OS-Layer the WSUS Update Service would be start
		29.10.2017 MS: replace VDA instead of MCS in the DiskMode Test
		20.10.2018 MS: Bugfix 73: MCS Image in Private Mode does not start the Windows Update Service
		18.08.2019 MS: ENH 101: Use sdelete64.exe on x64 system
		05.10.2019 MS: ENH 12 - Configure sDelete for different environments
		05.10.2019 MS: ENH 43 - sihclient.exe consumes CPU load with disabled WSUS Service (function invoke-sihTask)

	.LINK
		https://eucweb.com
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	#sdelete
	IF ($OSBitness -eq "32-bit") { $sdeleteversion = "sdelete.exe" } ELSE { $sdeleteversion = "sdelete64.exe" }
	IF ($LIC_BISF_CLI_SD_SF -eq "1") {
		$SDeletePath = "$($LIC_BISF_CLI_SD_SF_CUS)\$sdeleteversion"
	}
 ELSE {
		$SDeletePath = "C:\Windows\system32\$sdeleteversion"
	}

}

Process {

	# region functions
	function start-sdelete {
		IF ($RunPersSdelete -eq $true) {
			IF ((Test-Path ("$SDeletePath") -PathType Leaf )) {
				$ProductFileVersion = (Get-Item "$SDeletePath").VersionInfo.FileVersion
				Write-BISFLog -Msg "Product SDelete $ProductFileVersion installed" -ShowConsole -Color Cyan
				IF ($ProductFileVersion -lt "2.02") {
					Write-BISFLog -Msg "WARNING: SDelete $ProductFileVersion is not supported, Please use Version 2.02 or newer !!" -ShowConsole -Type W
					Start-Sleep 20
				}
				ELSE {
					Write-BISFLog -Msg "Supported SDelete Version detected, processing configuration" -ShowConsole

					#Citrix PVS Image on the WriteCache Disk if the image is in shared image mode
					IF (($LIC_BISF_CLI_SD_runPVSCacheDisk -eq 1) -and ($DiskMode -eq "ReadOnly") -and ($LIC_BISF_CLI_WCD -ne "NONE")) {
						Write-BISFLog -Msg "Running SDelete on PVS WriteCacheDisk Drive $LIC_BISF_CLI_WCD" -ShowConsole -Color DarkCyan -SubMsg
						Start-BISFProcWithProgBar -ProcPath "$SDeletePath" -Args "-accepteula -z $($LIC_BISF_CLI_WCD)" -ActText "SDelete is running to Zero Out Free Space on drive $LIC_BISF_CLI_WCD"

					}

					#Citrix MCSIO on persistent CacheDisk if the image is in shared image mode
					IF (($LIC_BISF_CLI_SD_runMCSIO -eq 1) -and ($DiskMode -eq "VDAShared") -and ($LIC_BISF_CLI_MCSIODriveLetter -ne "NONE") -and ($MCSIO -eq $true)) {
						Write-BISFLog -Msg "Running SDelete on MCSIO CacheDisk Drive $LIC_BISF_CLI_MCSIODriveLetter" -ShowConsole -Color DarkCyan -SubMsg
						Start-BISFProcWithProgBar -ProcPath "$SDeletePath" -Args "-accepteula -z $($LIC_BISF_CLI_MCSIODriveLetter)" -ActText "SDelete is running to Zero Out Free Space on drive $LIC_BISF_CLI_MCSIODriveLetter"

					}

					#Citrix MCS on Systemdrive if the image is in shared image mode
					IF (($LIC_BISF_CLI_SD_runMCS -eq 1) -and ($DiskMode -eq "VDAShared") -and ($MCSIO -eq $false)) {
						Write-BISFLog -Msg "Running SDelete on MCS SystemDrive $env:SystemDrive" -ShowConsole -Color DarkCyan -SubMsg
						Start-BISFProcWithProgBar -ProcPath "$SDeletePath" -Args "-accepteula -z $($env:SystemDrive)" -ActText "SDelete is running to Zero Out Free Space on drive $env:SystemDrive"
					}
				}

			}
			ELSE {
				Write-BISFLog -Msg "SDelete could not detected in Path $SDeletePath"
			}
		}
	}

	function start-WUAserv {
		Write-BISFLog -Msg "Activating Windows Update Service" -ShowConsole -Color DarkCyan -SubMsg
		Invoke-BISFService -ServiceName wuauserv -Action Start -StartType Automatic
	}

	function Invoke-sihTask {

		param (
			[parameter(Mandatory = $true)][string]$Mode
		)

		$TaskName = "sih"
		$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
		IF ($task) {
			Write-BISFLog -Msg "Scheduled Task $TaskNameexists" -ShowConsole -Color Cyan
			$TaskPathName = Get-ScheduledTask -TaskName $task | % { $_.TaskPath }
			Switch ($Mode) {
				Disable {
					Write-BISFLog -Msg "Disable Scheduled Task $TaskName" -ShowConsole -SubMsg -Color DarkCyan
					Disable-ScheduledTask -Taskname $ScheduledTaskList -TaskPath $TaskPathName | Out-Null
				}
				Enable {
					Write-BISFLog -Msg "Enable Scheduled Task $TaskName" -ShowConsole -SubMsg -Color DarkCyan
					Enable-ScheduledTask -Taskname $ScheduledTaskList -TaskPath $TaskPathName | Out-Null
				}

				Default {
					Write-BISFLog -Msg "Default Action selected, doing nothing" -ShowConsole -Color DarkCy
				}
			}
		}
		ELSE {
			Write-BISFLog -Msg "Scheduled Task $TaskName NOT exists" -ShowConsole -SubMsg -Color DarkCyan
		}
	}

	#endregion

	Write-BISFLog -Msg "Running system startup actions if needed..." -ShowConsole -Color Cyan
	$Global:DiskMode = Get-BISFDiskMode
	Switch ($Diskmode) {
		ReadWrite {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			start-WUAserv
			Invoke-sihTask -Mode Enable
		}
		ReadOnly {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Invoke-sihTask -Mode Disable
			start-sdelete
		}
		Unmanaged {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
		}
		VDAPrivate {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			start-WUAserv
			Invoke-sihTask -Mode Enable
		}
		VDAShared {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Invoke-sihTask -Mode Disable
			start-sdelete
		}
		ReadWriteAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") {
				start-WUAserv
				Invoke-sihTask -Mode Enable
			}
		}
		ReadOnlyAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Invoke-sihTask -Mode Disable
			start-sdelete
		}
		UnmanagedAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") {
				start-WUAserv
				Invoke-sihTask -Mode Enable
			}
		}
		VDAPrivateAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") {
				start-WUAserv
				Invoke-sihTask -Mode Enable
			}
		}
		VDASharedAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			Invoke-sihTask -Mode Disable
		}

		Default { Write-BISFLog -Msg "Default Action selected, doing nothing" -ShowConsole -Color DarkCyan }

	}

}

End {
	Add-BISFFinishLine
}