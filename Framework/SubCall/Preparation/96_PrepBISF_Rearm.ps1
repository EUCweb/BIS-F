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
		Company: Login Consultants Germany GmbH

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

		$RearmMSG_OS = "Is this Operating System succesfully rearmed ? If you click NO, the script wwill rearm your Operating System, otherwise click YES. TIP: For the most common scenarios; if you setup a fresh new clean system you can click NO, if you installed this script library at a later time to the base image, you can click YES."
		$RearmMSG_OF = "Is the Office installation succesfully rearmed ? If you click NO, the script will rearm your Office installation(s), otherwise click YES. TIP: For the most common scenarios; if you installed a fresh new Office installation you can click NO, if you installed this script library at a later time to the base image, you can click YES."

		# Check the installation path of Office 2010
		$Office2010InstallRoot = $null
		If ([Environment]::Is64BitOperatingSystem) {
				$Office2010InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\14.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
		}
		If ($Office2010InstallRoot -isnot [system.object]) { $Office2010InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\14.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }

		# Check the installation path of Office 2013
		$Office2013InstallRoot = $null
		If ([Environment]::Is64BitOperatingSystem) {
				$Office2013InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\15.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
		}
		If ($Office2013InstallRoot -isnot [system.object]) { $Office2013InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\15.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }

		# Check the installation path of Office 2016
		$Office2016InstallRoot = $null
		If ([Environment]::Is64BitOperatingSystem) {
				$Office2016InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\16.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
		}
		If ($Office2016InstallRoot -isnot [system.object]) { $Office2016InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\16.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }

		# Check the installation path of Office 2019
		$Office2019InstallRoot = $null
		If ([Environment]::Is64BitOperatingSystem) {
				$Office2019InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\17.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
		}
		If ($Office2019InstallRoot -isnot [system.object]) { $Office2019InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\17.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }


		# Check the installation path of Office 365 ClickToRun
		$Office365Inst
		allRoot = $null
		If ([Environment]::Is64BitOperatingSystem) {
				$Office365InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\ClickToRun -Name InstallPath -ErrorAction SilentlyContinue).Path
		}
		If ($Office365InstallRoot -isnot [system.object]) { $Office2016InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\ClickToRun -Name InstallPath -ErrorAction SilentlyContinue).Path }



		#$OSPPREARM_2k10x86 = "$CommonProgramFilesx86\microsoft shared\OfficeSoftwareProtectionPlatform\OSPPREARM.EXE"
		#$OSPPREARM_2k13x86 = "$ProgramFilesx86\Microsoft Office\Office15\OSPPREARM.EXE"
		#$OSPPREARM_2k16x86 = "$ProgramFilesx86\Microsoft Office\Office16\OSPPREARM.EXE"
		$OSPPREARM = @()
		####################################################################

		####################################################################
		####### functions #####

		#Rearm System
		function RearmOS {
				Write-BISFLog -Msg "Check Operating System $OSName rearm status" -ShowConsole -Color Cyan
				Write-BISFLog -Msg "check OS rearm registry keys in $hklm_software_LIC_CTX_BISF_SCRIPTS"
				Write-BISFLog -Msg "get OS rearm Status [0=never run, 1=run] ..Status = $LIC_BISF_RearmOS_run"
				IF ($LIC_BISF_RearmOS_run -ne 1) {
						Write-BISFLog -Msg "Check Silentswitch..."
						$varCLI = $LIC_BISF_CLI_OS
						IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
								Write-BISFLog -Msg "Silentswitch would be set to $varCLI"
						}
						ELSE {
								Write-BISFLog -Msg "Show Messagebox to rearm System" -ShowConsole -Color DarkCyan -SubMsg
								$OSrearmAnsw = Show-MessageBox -Msg $RearmMSG_OS -Title "Operating System KMS rearm " -YesNo -Question
								Write-BISFLog -Msg "$OSrearmAnsw woul be choosen [YES = System is already rearmed, registry flags would be set only] [NO = System mus be rearmed from script]"
						}
						if (($OSrearmAnsw -eq "NO" ) -or ($varCLI -eq "YES")) {
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
				IF ($Office2010InstallRoot -is [System.Object]) {
						$OSPPREARM = $Office2010InstallRoot + "OSPPREARM.EXE"
						Write-BISFLog -Msg "Checking Office 2010 rearm status" -ShowConsole -Color Cyan

				}
				ELSE {
						Write-BISFLog -Msg "Office 2010 x86 not installed"

				}

				IF ($Office2013InstallRoot -is [System.Object]) {
						$OSPPREARM = $Office2013InstallRoot + "OSPPREARM.EXE"
						Write-BISFLog -Msg "Checking Office 2013 rearm status" -ShowConsole -Color Cyan

				}
				ELSE {
						Write-BISFLog -Msg "Office 2013 is not installed"
				}

				IF ($Office2016InstallRoot -is [System.Object]) {
						$OSPPREARM = $Office2016InstallRoot + "OSPPREARM.EXE"
						Write-BISFLog -Msg "Checking Office 2016 rearm status" -ShowConsole -Color Cyan

				}
				ELSE {
						Write-BISFLog -Msg "Office 2016 is not installed"
				}

				IF ($Office2019InstallRoot -is [System.Object]) {
						$OSPPREARM = $Office2019InstallRoot + "OSPPREARM.EXE"
						Write-BISFLog -Msg "Checking Office 2019 rearm status" -ShowConsole -Color Cyan

				}
				ELSE {
						Write-BISFLog -Msg "Office 2019 is not installed"
				}

				IF ($Office365InstallRoot -is [System.Object]) {
						$OSPPREARM = $Office365InstallRoot + "OSPPREARM.EXE"
						Write-BISFLog -Msg "Checking Office 365 rearm status" -ShowConsole -Color Cyan

				}
				ELSE {
						Write-BISFLog -Msg "Office 365 is not installed"
				}

				IF ("$OSPPREARM" -ne "") {
						IF (Test-Path -Path $OSPPREARM) {
								$OSPPREARM_Path = [System.IO.Path]::GetDirectoryName($OSPPREARM)
								Write-BISFLog -Msg "Office detected for rearm, check $OSPPREARM"
								Write-BISFLog -Msg "Check Office rearm registry keys in $hklm_software_LIC_CTX_BISF_SCRIPTS"
								Write-BISFLog -Msg "Get Office rearm Status [0=never run, 1=run] ..Status = $LIC_BISF_RearmOF_run"
								IF ($LIC_BISF_RearmOF_run -ne 1) {
										Write-BISFLog -Msg "Check Silentswitch..."
										$varCLI = $LIC_BISF_CLI_OF
										IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
												Write-BISFLog -Msg "Silentswitch would be set to $varCLI"
										}
										ELSE {
												Write-BISFLog -Msg "Show Messagebox to rearm Office" -ShowConsole -Color DarkCyan -SubMsg
												$OFreamAnsw = Show-BISFMessageBox -Msg $RearmMSG_OF -title "Office KMS rearm "  -YesNo -Question
												Write-BISFLog -Msg "$OFreamAnsw would be choosen [YES = Office is already rearmed, registry flags would be set only] [NO = Office mus be rearmed from script]"
										}
										if (($OFreamAnsw -eq "NO" ) -or ($varCLI -eq "YES")) {
												Write-BISFLog -Msg "Office will be rearmed now" -ShowConsole -Color DarkCyan -SubMsg
												Write-BISFLog -Msg "Prepare Office for product activation - $OSPPREARM"
												$tmpLogFile = "C:\Windows\logs\BISFtmpProcessLog.log"
												$process = Start-Process -FilePath "$OSPPREARM" -Wait -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
												$ProcessExitCode = $Process.ExitCode
												Write-BISFLog -Msg  "ExitCode: $ProcessExitCode"
												Get-BISFLogContent -GetLogFile "$tmpLogFile"
												Remove-Item -Path "$tmpLogFile" -Force | Out-Null
												Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$OSPPREARM_Path\OSPP.vbs"" /dstatus" -ActText "Office - Get detailed license informations after rearm"

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
										Start-BISFProcWithProgBar -ProcPath "cscript.exe" -Args "//NoLogo ""$OSPPREARM_Path\OSPP.vbs"" /dstatus" -ActText "Get detailed Office license informations"
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