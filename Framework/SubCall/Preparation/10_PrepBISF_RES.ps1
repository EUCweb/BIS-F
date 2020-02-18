<#
	.SYNOPSIS
		Prepare RES One Workspace Management, RES ONE Automation and RES ONE Service Store Software for Image Managemement
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		Thanks to Company RES Germany: Oliver Lomberg & Nina Metz for additional enhacements informations to create this script

		History:
		10.01.2017 MS: Initial Script Created
		24.01.2017 MS: Workspace Manager and AutomationManager; In Citrix PVS if an alternate DBCache Path is already configured, BIS-F does not configured anymore
		30.01.2017 MS: RES Workspace Manager: add IF (Test-Path "$HKLM_WIN_CVN\WUID") {Remove-Item -Path "$HKLM_WIN_CVN\WUID"}
		31.01.2017 MS: Added RES ONE Automation Console stop service
		31.01.2017 MS: RES Workspace: change Remove-Item -Path "$InstallDir_REG\Data\DBCache\Resources\custom_resources\*" -recurse
		01.02.2017 MS: Bugfix wrong syntax for RES ONE Automation Console
		15.03.2017 MS: added Support for RES ONE Automation Agent Version 10 with new path in registry and filesystem
		03.04.2017 MS: BugFix - RES Workspace: wrong Path in Workspace Agent, change from DBCache to LocalCachePath
		03.04.2017 MS: BugFix - RES Workspace: delete not all folders in the CachePath
		12.07.2017 FF: BugFix for Redirecting RES Cache (Setting Cache Path to WCD)
		21.09.2017 MS: Feature: RES Automation Agent Service could be controlled from ADMX
		04.05.2019 MS: BugFix 82 - RES ONE Automation Agent - Action is missing
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured

		17.08.2019 MS: ENH 78: Sealing for Ivanti Automation agent can be disabled in ADMX
		18.02.2020 JK: Fixed Log output spelling
		
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

	$Prd1 = "RES ONE Workspace Agent"
	$Svc1 = "RES"

	$Prd2 = "RES ONE Automation Console"
	$Svc2 = "RESWCS"

	$Prd3 = "RES ONE Automation"
	$Svc3 = "RESWAS"

	$Prd4 = "RES ONE Service Store Client Service"
	$Svc4 = "RESOCWSVC"

	$HKLM_REG_ROW = "$HKLM_sw_x86\RES\Workspace Manager"
	$HKLM_REG_ROA = @() # would be set in the RES ONE Automation Agent section, because of different path between RES Versions 9 and 10
	$HKLM_WIN_CVN = "$HKLM_sw_x86\Microsoft\Windows\CurrentVersion"

	####################################################################
}

Process {


	#RES ONE Workspace Agent
	$svc = Test-BISFService -ServiceName $Svc1 -ProductName $Prd1
	IF ($svc) {
		Invoke-BISFService -ServiceName $Svc1 -Action Stop
		Write-BISFLog -Msg "Prepare for Imaging..."
		Invoke-BISFService -ServiceName "RESPESVC" -Action Stop

		$TestROWValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROW" -Value "CachedSystemInfo"
		IF ($TestROWValue) { Remove-ItemProperty -Path "$HKLM_REG_ROW" -Name "CachedSystemInfo" }

		$TestROWValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROW" -Value "CachedSystemInfoEx"
		IF ($TestROWValue) { Remove-ItemProperty -Path "$HKLM_REG_ROW" -Name "CachedSystemInfoEx" }

		$TestROWValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROW" -Value "ComputerGUID"
		IF ($TestROWValue) { Remove-ItemProperty -Path "$HKLM_REG_ROW" -Name "ComputerGUID" }

		$TestROWValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROW" -Value "LastSyncUTC"
		IF ($TestROWValue) { Remove-ItemProperty -Path "$HKLM_REG_ROW" -Name "LastSyncUTC" }

		IF (Test-Path "$HKLM_REG_ROW\UpdateGUIDs") { Remove-Item -Path "$HKLM_REG_ROW\UpdateGUIDs" }

		IF (Test-Path "$HKLM_WIN_CVN\WUID") { Remove-Item -Path "$HKLM_WIN_CVN\WUID" }

		$TestROWValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROW" -Value "LocalCachePath"
		IF ($TestROWValue) {
			$LocalCachePath_REG = Get-ItemProperty -path "$HKLM_REG_ROW" | % { $_.LocalCachePath }
			Write-BISFLog -Msg "LocalCachePath is set to $LocalCachePath_REG and would deleted now"
			IF (Test-Path $LocalCachePath_REG) { Remove-Item -Path "$LocalCachePath_REG" -recurse -force }
		}
		ELSE {
			$InstallDir_REG = Get-ItemProperty -path "$HKLM_REG_ROW" | % { $_.InstallDir }

			IF (Test-Path $InstallDir_REG) {
				Write-BISFLog -Msg "DB Cache is set to $InstallDir_REG\Data\DBCache and will be deleted now"
				Remove-Item -Path "$InstallDir_REG\Data\DBCache" -recurse
			}
			ELSE {
				Write-BISFLog -Msg "DB Cache is set to $InstallDir_REG\Data\DBCache and could NOT be deleted" -Type W -SubMsg

			}
		}

		IF ($returnTestPVSSoftware -eq "true") {

			Write-BISFLog -Msg "Citrix PVS Target Device Driver installed" -SubMsg -ShowConsole -Color DarkCyan
			$ROWCachePath = (Get-ItemProperty "$HKLM_REG_ROW").DBCache
			$ROWCachePathDrive = $ROWCachePath.substring(0, 2)
			IF ($PVSDiskDrive -eq $ROWCachePathDrive) {
				Write-BISFLog -Msg "RES Workspace Manager DBCache is already redirected $ROWCachePath" -SubMsg -ShowConsole -Color DarkCyan
			}
			ELSE {
				$ROWCachePath = "$PVSDiskDrive\RES\Workspace Manager\DBCache"
				Write-BISFLog -Msg "Redirecting RES ONE Workspace Agent DBCache to $ROWCachePath" -SubMsg -ShowConsole -Color DarkCyan
				Set-ItemProperty -Path "$HKLM_REG_ROW" -Name "LocalCachePath" -Value "$ROWCachePath"
				Set-ItemProperty -Path "$HKLM_REG_ROW" -Name "LocalCacheOnDisk" -Value "YES"
			}
		}
	}

	#RES ONE Automation Console
	$svc = Test-BISFService -ServiceName $Svc2 -ProductName $Prd2
	IF ($svc) {
		Invoke-BISFService -ServiceName $Svc2 -Action Stop
	}

	#RES ONE Automation
	$svc = Test-BISFService -ServiceName $Svc3 -ProductName $Prd3
	IF ($svc) {
		IF ($LIC_BISF_CLI_RA_SVC -eq "YES") { Invoke-BISFService -ServiceName $Svc3 -Action Stop } ELSE { Write-BISFLog -Msg "$Prd3 Service would not stopped (ADMX configuration)" -SubMsg -ShowConsole -Color DarkCyan }
		IF ($LIC_BISF_CLI_RA_SEAL -ne "YES") {
			Write-BISFLog -Msg "Prepare $Prd3 for Imaging..."
			$glbSVCImagePath = $glbSVCImagePath.split("\")[1] #get $SVCImagePath from Test-BISFService and split them to get ProgramFiles or ProgramFiles(x86) only
			IF ($glbSVCImagePath -eq "Program Files") {
				$HKLM_REG_ROA = "$hklm_software\RES\AutomationManager"
				$Inst_Path_ROA = "C:\$glbSVCImagePath\RES\Automation\Agent"
			}
			ELSE {
				$HKLM_REG_ROA = "$HKLM_sw_x86\RES\AutomationManager"
				$Inst_Path_ROA = "C:\$glbSVCImagePath\RES Software\Automation Manager\Agent"
			}
			Write-BISFLog -Msg "RES ROA Registry Path: $HKLM_REG_ROA"
			Write-BISFLog -Msg "RES ROA Install Path: $Inst_Path_ROA"

			$TestROAValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROA\Agent" -Value "CachedDispatchers"
			IF ($TestROAValue) { Remove-ItemProperty -Path "$HKLM_REG_ROA\Agent" -Name "CachedDispatchers" }

			$TestROAValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROA\Agent" -Value "CommunicationID"
			IF ($TestROAValue) { Remove-ItemProperty -Path "$HKLM_REG_ROA\Agent" -Name "CommunicationID" }

			$TestROAValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROA\Agent" -Value "DispatcherListKGC"
			IF ($TestROAValue) { Remove-ItemProperty -Path "$HKLM_REG_ROA\Agent" -Name "DispatcherListKGC" }

			Set-ItemProperty -Path "$HKLM_REG_ROA\Agent" -Name "Prepared4Image" -Value "$computer"

			$TestROAValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROA\Preferences" -Value "WUID"
			IF ($TestROAValue) { Remove-ItemProperty -Path "$HKLM_REG_ROA\Preferences" -Name "WUID" }

			IF (Test-Path "$HKLM_WIN_CVN\WUID") { Remove-Item -Path "$HKLM_WIN_CVN\WUID" }

			$TestROAValue = Test-BISFRegistryValue -Path "$HKLM_REG_ROA\Agent" -Value "LastKnownResourceCacheFolder"
			IF ($TestROAValue) {
				$LastKnownResourceCacheFolder_REG = Get-ItemProperty -path "$HKLM_REG_ROA" | % { $_.LastKnownResourceCacheFolder }
				Write-BISFLog -Msg "LastKnownResourceCacheFolder is set to $LastKnownResourceCacheFolder_REG and would deleted now"
				IF (Test-Path $LastKnownResourceCacheFolder_REG) { Remove-Item -Path "$LastKnownResourceCacheFolder_REG\*" -recurse }
			}
			ELSE {
				$ROA_StdPath = "$Inst_Path_ROA\Workspace"
				IF (Test-Path $ROA_StdPath) {
					Write-BISFLog -Msg "Standardpath is set to $ROA_StdPath and will be deleted now"
					Remove-Item -Path "$ROA_StdPath\*" -recurse
				}
				ELSE {
					Write-BISFLog -Msg "Standardpath is set to $ROA_StdPath and could NOT be deleted" -Type W -SubMsg
				}
			}
		}
		ELSE {
			Write-BISFLog -Msg "Sealing for $Prd3 is skipped from GPO configuration" -Type W -SubMsg
		}

		IF ($returnTestPVSSoftware -eq "true") {
			Write-BISFLog -Msg "Citrix PVS Target Device Driver installed" -SubMsg -ShowConsole -Color DarkCyan
			$ROACachePath = (Get-ItemProperty "$HKLM_REG_ROA\Agent").LastKnownResourceCacheFolder
			$ROACachePathDrive = $ROACachePath.substring(0, 2)
			IF ($PVSDiskDrive -eq $ROACachePathDrive) {
				Write-BISFLog -Msg "RES Automation Manager DBCache is already redirected to $ROACachePath" -SubMsg -ShowConsole -Color DarkCyan
			}
			ELSE {
				$ROACachePath = "$PVSDiskDrive\RES\Automation Manager\DBCache"
				Write-BISFLog -Msg "Redirect RES ONE Automation Manager Agent DBCache to $ROACachePath" -SubMsg -ShowConsole -Color DarkCyan
				Set-ItemProperty -Path "$HKLM_REG_ROA\Agent" -Name "LastKnownResourceCacheFolder" -Value "$ROACachePath"
			}
		}

		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLI = $LIC_BISF_CLI_RA
		IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO Valuedata: $varCLI"
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$ROADisableSVC = "NO"
		}

		If (($ROADisableSVC -eq "YES" ) -or ($varCLI -eq "YES")) {
			Write-BISFLog -Msg "reconfigure Service... please Wait"
			Invoke-BISFService -ServiceName "$Svc3" -StartType Disabled -Action Stop

		}
		ELSE {
			Write-BISFLog -Msg "Sealing for $Prd3 is disabled in GPO" -ShowConsole -SubMSg -Type W
		}
	}

	#RES ONE Service Store Client Service
	$svc = Test-BISFService -ServiceName $Svc4 -ProductName $Prd4
	IF ($svc) {
		Invoke-BISFService -ServiceName $Svc4 -Action Stop
	}

}

End {
	Add-BISFFinishLine
}