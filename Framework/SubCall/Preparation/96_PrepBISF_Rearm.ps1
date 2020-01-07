[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		Prepare for System for Image Management
	.DESCRIPTION
		Rearm System once only and if office 2010,2013,2016 detected, rearm this once only
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)
		Company:  EUCWeb.com

		History:
		10.10.2012 MS: Script created
		19.10.2012 MS: Changed rearm to silent mode -> cscript.exe //B slmgr.vbs /rearm
		07.06.2013 MS: Office 2010 rearm: OSPPREARM.EXE added, but not tested
		18.09.2013 MS: Replaced $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		18.09.2013 MS: Set Office reamstatus to 0, if office x86 not detected
		19.09.2013 MS: Set wrong value for office rearm
		27.02.2013 MS: New function MigrateValues > Migrate old values from earlier script version to new one
		13.03.2013 MS: Remove function MigrateValues > add MessageBox to OS rearm and office rearm
		18.03.2014 BR: Revisited Script
		13.05.2014 MS: Added Silentswitch -OSrearm (YES|NO)-OFrearm (YES|NO)
		11.06.2014 MS: Fixed read variable LIC_BISF_CLI_AV and LIC_BISF_CLI_OF
		13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		17.08.2014 MS: Changed line 39 to $OSPPREARM = "$CommonProgramFilesx86\microsoft shared\OfficeSoftwareProtectionPlatform\OSPPREARM.EXE"s
		13.01.2015 MB: Script created for Office 2010 and Office 2013
		08.06.2015 MS: Different path for OSSPREAM.exe not valid for Office2013, for office2010 only
		13.08.2015 MS: If Office not installed and CLI switch would be set to ream office, an error occurs. Check if Office is installed, before starting rearm process
		01.10.2015 MS: Rewritten script to use central BISF function
		07.01.2016 MS: Added Office 2016 x86 rearm support
		13.01.2016 MS: Fixed typo
		06.03.2017 MS: Bugfix read Variable $varCLI = ...
		16.10.2017 MS: Bugfix OS rearm never run, path to slmgr.vbs must be entered before, thx to Bernd Baedermann
		17.10.2017 MS: Bugfix Running Office ream first and second OS rerarm, thx to Bernd Baedermann
		01.11.2017 MS: Feature: get detailed OS License Information and write them to the BIS-F Log
		01.11.2017 MS: Feature: Office Rearm state writes to BIS-F Log
		09.11.2017 MS: Read Office Installationpath from regisrty, support now for Office x64 and x86
		22.03.2018 MS: Feature 15 - support for Office 365 ClicktoRun
		28.03.2019 MS: FRQ 86 - Office 2019 support
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		03.10.2019 MS: ENH 84 - Azure Activation for all Office 365 users
		07.01.2020 MS: HF 174 - Office detection general change

	.LINK
		https://eucweb.com
#>

Begin {

	####################################################################
	# define environment
	# Setting default variables ($PSScriptroot/$logfile/$PSCommand,$PSScriptFullname/$scriptlibrary/LogFileName) independent on running script from console or ISE and the powershell version.
	If ($($host.name) -like "* ISE *") {
		# Running script from Windows Powershell ISE
		$PSScriptFullName = $psise.CurrentFile.FullPath.ToLower()
		$PSCommand = (Get-PSCallStack).InvocationInfo.MyCommand.Definition
	}
	ELSE {
		$PSScriptFullName = $MyInvocation.MyCommand.Definition.ToLower()
		$PSCommand = $MyInvocation.Line
	}
	[string]$PSScriptName = (Split-Path $PSScriptFullName -leaf).ToLower()
	If (($PSScriptRoot -eq "") -or ($PSScriptRoot -eq $null)) { [string]$PSScriptRoot = (Split-Path $PSScriptFullName).ToLower() }

	$cu_user = $env:username
	$Domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
	$RearmREG_name1 = "LIC_BISF_RearmOS_run"
	$RearmREG_name2 = "LIC_BISF_RearmOS_user"
	$RearmREG_name3 = "LIC_BISF_RearmOS_date"
	$RearmREG_name4 = "LIC_BISF_RearmOF_run"
	$RearmREG_name5 = "LIC_BISF_RearmOF_user"
	$RearmREG_name6 = "LIC_BISF_RearmOF_date"

	$OfficeInstallations = Get-WmiObject win32_product | where {$_.Name -like "Microsoft Office Professional Plus*" -or $_.Name -Like "Microsoft Office Standard*" -or $_.Name -like "*Click-to-Run Licensing Component*"}
	[array]$OfficeInstallRoot = $null
	$OSPPREARM = $null
	ForEach ($Office in $OfficeInstallations)
	{
		$OFName = $Office.Name
		$OFVersion = Office.Version						#Version : 16.0.4266.1001
		$OFVersionShort = $OFVersion.substring(0,4)  	#Version : 16.0
		IF ($OFName -like "*Click-to-Run*") { $OFName = "Microsoft Office 365"; $O365 = $true } ELSE { $O365 = $false}
		Write-BISFLog -Msg "$OFName - $OFVersion installed" -ShowConsole -Color Cyan
		IF ($O365 -eq $false) {
			If ([Environment]::Is64BitOperatingSystem) {
				$OfficeInstallRoot += (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\$($OFVersionShort)\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
			}
			If ($OfficeInstallRoot -isnot [system.object]) { $OfficeInstallRoot += (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\$($OFVersionShort)\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }
		} ELSE {
			If ([Environment]::Is64BitOperatingSystem) {
				$OfficeInstallRoot += (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\ClickToRun -Name InstallPath -ErrorAction SilentlyContinue).InstallPath
			}
			If ($OfficeInstallRoot -isnot [system.object]) { $OfficeInstallRoot += (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\ClickToRun -Name InstallPath -ErrorAction SilentlyContinue).InstallPath }
		}
		Write-BISFLog -Msg "Installpath $OfficeInstallRoot " -ShowConsole -Color DarkCyan -SubMsg
		$OSPPREARM = Get-ChildItem -Path $OfficeInstallRoot -filter "OSPPREARM.EXE" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
		$OSPP = Get-ChildItem -Path $OfficeInstallRoot -filter "OSPP.vbs" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
		Write-BISFLog -Msg "OSPPrearm is installed in $OSPPREARM"
		Write-BISFLog -Msg "OSPP is installed in $OSPP"
	}

	####################################################################

	####################################################################
	####### functions #####

	#Rearm System
	function RearmOS {
		Write-BISFLog -Msg "Check Operating System $OSName rearm status" -ShowConsole -Color Cyan
		Write-BISFLog -Msg "check OS rearm registry keys in $hklm_software_LIC_CTX_BISF_SCRIPTS"
		Write-BISFLog -Msg "get OS rearm Status [0=never run, 1=run] ..Status = $LIC_BISF_RearmOS_run"
		IF ($LIC_BISF_RearmOS_run -ne 1) {
			Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
			$varCLI = $LIC_BISF_CLI_OS
			IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
				Write-BISFLog -Msg "GPO Valuedata: $varCLI"
			}
			ELSE {
				Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
				$OSrearmAnsw = "NO"

			}
			if (($OSrearmAnsw -eq "YES" ) -or ($varCLI -eq "YES")) {
				Write-BISFLog -Msg "Operating System will be rearmed now" -ShowConsole -Color DarkCyan -SubMsg
				Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo $env:windir\system32\slmgr.vbs /rearm" -ActText "OS - Reset OS License state"
				Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo $env:windir\system32\slmgr.vbs /dlv" -ActText "OS - Get detailed license informations"
			}
			Write-BISFLog -Msg "Set specified registry keys in $hklm_software_LIC_CTX_BISF_SCRIPTS"

			Write-BISFLog -Msg "Set Value = $RearmREG_name1 / ValueData = 1"
			Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $RearmREG_name1 -value "1" #-ErrorAction SilentlyContinue

			Write-BISFLog -Msg "Set Value = $RearmREG_name2 / ValueData = $cu_user"
			Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $RearmREG_name2 -value $cu_user #-ErrorAction SilentlyContinue

			Write-BISFLog -Msg "Set Value = $RearmREG_name3 / ValueData = $(Get-Date)"
			Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $RearmREG_name3 -value $(Get-Date) #-ErrorAction SilentlyContinue

		}
		ELSE {
			Write-BISFLog -Msg "Operating System already rearmed, no action needed" -ShowConsole -Color DarkCyan -SubMsg
			Start-BISFProcWithProgBar -ProcPath "cscript.exe" -Args "//NoLogo $env:windir\system32\slmgr.vbs /dlv" -ActText "Get detailed OS license informations"
		}
	}
	####################################################################

	####################################################################
	#Rearm System
	function RearmOffice {
		IF ($OfficeInstallRoot -is [System.Object]) {
			#$OSPPREARM = $OfficeInstallRoot + "OSPPREARM.EXE"
			Write-BISFLog -Msg "Checking Office rearm status" -ShowConsole -Color Cyan
		} ELSE {
			Write-BISFLog -Msg "No Office Installation detected"
		}


		IF ($O365 -eq $true) {
			$O365onAzure = Test-BISFAzureVM
			IF ($O365onAzure -eq $true) {
				Write-BISFLog -Msg "Office 365 is hosting on Microsoft Azure" -ShowConsole -Color DarkCyan -SubMsg
				Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\dsregcmd.exe" -Args "/leave" -ActText "Office - Performs Hybrid Unjoin"
				Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\dsregcmd.exe" -Args "/status" -ActText "Office - Displays the device join status"
			}
			ELSE {
				Write-BISFLog -Msg "Office 365 is NOT hosting on Microsoft Azure" -Color DarkCyan -SubMsg
			}


		}

		IF ($null -ne $OSPPREARM) {
			IF (Test-Path -Path $OSPPREARM) {
				$OSPPREARM_Path = [System.IO.Path]::GetDirectoryName($OSPPREARM)
				Write-BISFLog -Msg "Office detected for rearm, check $OSPPREARM"
				Write-BISFLog -Msg "Check Office rearm registry keys in $hklm_software_LIC_CTX_BISF_SCRIPTS"
				Write-BISFLog -Msg "Get Office rearm Status [0=never run, 1=run] ..Status = $LIC_BISF_RearmOF_run"
				IF ($LIC_BISF_RearmOF_run -ne 1) {
					Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
					$varCLI = $LIC_BISF_CLI_OF
					IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
						Write-BISFLog -Msg "GPO Valuedata: $varCLI"
					}
					ELSE {
						Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
						$OFreamAnsw = "NO"
					}
					if (($OFreamAnsw -eq "YES" ) -or ($varCLI -eq "YES")) {
						Write-BISFLog -Msg "Office will be rearmed now" -ShowConsole -Color DarkCyan -SubMsg
						Write-BISFLog -Msg "Prepare Office for product activation - $OSPPREARM"
						$tmpLogFile = "C:\Windows\logs\BISFtmpProcessLog.log"
						$process = Start-Process -FilePath "$OSPPREARM" -Wait -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
						$ProcessExitCode = $Process.ExitCode
						Write-BISFLog -Msg  "ExitCode: $ProcessExitCode"
						Get-BISFLogContent -GetLogFile "$tmpLogFile"
						Remove-Item -Path "$tmpLogFile" -Force | Out-Null
						Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$OSPP"" /dstatus" -ActText "Office - Get detailed license informations after rearm"

					}
					Write-BISFLog -Msg "Set specified registry keys in $hklm_software_LIC_CTX_BISF_SCRIPTS"
					Write-BISFLog -Msg "Set Value = $RearmREG_name4 / ValueData = 1"
					Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $RearmREG_name4 -value "1" #-ErrorAction SilentlyContinue
					Write-BISFLog -Msg "Set Value = $RearmREG_name5 / ValueData = $cu_user"
					Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $RearmREG_name5 -value $cu_user #-ErrorAction SilentlyContinue
					Write-BISFLog -Msg "Set Value = $RearmREG_name6 / ValueData = $(Get-Date)"
					Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $RearmREG_name6 -value $(Get-Date) #-ErrorAction SilentlyContinue
				}
				ELSE {
					Write-BISFLog -Msg "Office already rearmed, no action needed" -ShowConsole -Color DarkCyan -SubMsg
					Start-BISFProcWithProgBar -ProcPath "cscript.exe" -Args "//NoLogo ""$OSPP"" /dstatus" -ActText "Get detailed Office license informations"
				}
			}
			ELSE {
				Write-BISFLog -Msg "Office for rearm not found, check $OSPPREARM"
				Write-BISFLog -Msg "Set Office rearm status to never run in $hklm_software_LIC_CTX_BISF_SCRIPTS"
				Write-BISFLog -Msg "Set Value = $RearmREG_name4 / ValueData = 0"
				Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $RearmREG_name4 -value "0" #-ErrorAction SilentlyContinue
			}
		}
		ELSE {
			Write-BISFLog -Msg "No Office installation detected, no rearm required !!" -Type W
		}
	}
	####################################################################
}
Process {

	#### Main Program
	#Loads the WinForm Assembly, Out-Null hides the message while loading.
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

	RearmOffice
	RearmOS
}
End {
	Add-BISFFinishLine
}