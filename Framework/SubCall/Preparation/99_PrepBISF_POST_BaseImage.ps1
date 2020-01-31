[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		PostCommand after creating vDisk
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)

		History:
		27.09.2012 MS: Script created
		28.02.2013 MS: Check vDisk conversation successfull, then shutdown
		27.08.2013 MS: Show PopUp Error Message if vDisk conversion NOT successful
		18.09.2013 MS: Replaced $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		18.09.2013 MS: Added $CheckP2PVSlog=TRUE/FALSE/ERROR
		11.08.2014 MS: Removed Write-Host change to Write-BISFLog
		13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		13.08.2014 MS: Added IF ($returnTestPVSSoftware -eq "true")
		14.08.2014 MS: Added error type for Logging, to exit script without shutdown
		15.08.2014 MS: Check $ImageSW if $true to shutdown computer
		18.08.2014 MS: Add line 85; IF ($runPvd -eq "true")
		19.09.2014 MS: Get content from logfiles and write to logfile
		20.08.2014 MS: Removed log content from P2PVS, beacuse XenConvert has a size of 100 MB and more
		15.09.2014 MS: P2PVS.log or XenConvert.log would be checked if PVS Target Device is installed and the Device boot up from harddisk only
		16.09.2014 MS: Moved CheckLog function to the central functions and move CheckPVDLog after PVD Inventory Update in Script 98_XX_...
		14.04.2015 MS: Prevented shutdown the Base Image after successfull convert the image, this switch would be automaticaly set if the Base Image preperation is running from SCCM/MDT TaskSequence
		14.04.2015 MS: Get-vDiskDriveLetter to defrag vDisk after successfull build, no longer defrag the harddisk
		14.04.2015 MS: Rewriten POST Build Action $PostCommands
		18.05.2015 MS: Added CLI Switch VERYSILENT handling
		13.08.2015 MS: $P2PVS_LOGFile_search="Conversion was successful" must be changed to $P2PVS_LOGFile_search="successful" to get ready for PVS7.7 and earlier
		01.09.2015 MS: Change Request 88 - Defrag runs on BaseDisk only
		01.10.2015 MS: Rewritten script to use central BISF
		01.02.2016 MS: Added sysprep to run if No Image Management Software detected
		28.10.2016 MS: Bug fix Sysprep;  Sysprep is not running in earlier BIS-F Version. Adding errorhandling, checking setuperr.log for errors and ferorm postCommands
		28.10.2016 MS: Enhanced the defrag to run on NoVirtualDisk, previous Version PVS BaseDisk only
		28.10.2016 MS: If NoVirtualDisk would be detected, the Drive for Defrag if used would be set to SystemDrive
		29.10.2016 MS: After successfull sysprep, shutdown computer would be performed only, if not supressed by CLI command
		05.12.2016 MS: Variables must be cleared after each step, to not store the value in the variable and use them in the next $prepCommand
		12.03.2017 MS: remove $Pvd_LOGFile_search="Update Inventory completed" here and move them to 98_PrepBISF_BuildBaseImage.ps1
		21.03.2017 MS: add ProgressBar to defrag if running
		20.04.2017 MS: Issue 175: - After Patchday in April 2017 powershell command stop-computer does not work as expected (privilege not held), using shutdown /s now
		01.05.2017 MS: Bugfix: after sucessfull syprep, running PostCommand now for defrag and shutdown
		01.05.2017 MS: Bugfix 178: defrag arguments are different between client and server os, thx to Jeremy Saunders
		31.07.2017 MS: Bugfix: if Citirx PVS Target Device Driver and Citrix AppLayering is installed, PostCommand would not executed
		02.08.2017 MS: IF ADMX for custom VHDX UNC-Path is enabled, Defrag can't performed
		06.08.2017 MS: from every P2V convertion, the logfile would be included into the BIS-F log, instead of error only
		22.08.2017 MS: If defrag not run, write-out the DiskMode to the BIS-F log for further anlaysis if possible to run
		24.08.2017 MS: If AppLayering is installed and running not inside ELM, the VM is build first time, run defrag on systemdrive
		11.09.2017 MS: Writing PersSate "NotRunning" to BISF Registry to control running prep after pers first
		29.10.2017 MS: Bugifx: defrag select the the right vDisk on the custom UNC-Path or the direct convertion
		29.10.2017 MS: Bugfix: IF $DiskNameExtension -eq "noVirtualDisk" and custom UNC-Path is enabled, runnig OfflineDefrag on custom UNC-Path
		01.11.2017 MS: check if Defrag Service is running, thx to Lejkin Dmitrij
		02.11.2017 MS: Bugfix: if booting up in private Mode the vhdx and custom unc-path is configured, defrag runs on the UNC-Path and not on the BaseDisk itself.
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		03.10.2019 MS: ENH 94 - Add sysprep command-line options to ADMX
		20.12.2019 MS/SF: FRQ 154 (PR)- Edjust for compositing engine change in AppLayering 1911 an higher
		23.12.2019 MS: ENH 98 - Skip PostCommand execution, if PVS Master Image creation is skipped too
		11.01.2019 MS: HF 183 - fix defrag arguments for Server 2012 R2
		27.01.2020 MS: HF 167 - Moving AppLayering Layer Finalize to Post BIS-F script

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

	$P2PVS_LOGFile_search = "Success"
	$POstMSG = @()
	$PostXT = @()
	$PostMD = @()
	$PostCLI = @()
	$vDiskDriveLetter = get-BISFvDiskDrive

	# Specific to Citrix Application Layering -ge 1911
	$CEDir = "$env:SYSTEMDRIVE\CitrixCE" # -> Citrix Compositing Engine introduced in CAL 1911, only available when compositing offloading is enabled.
	$bootIdPath = "$CEDir\bootid" # -> Boot Order information.

	IF ($LIC_BISF_CLI_DF -eq "YES") {
		Write-BISFLog -Msg "Defrag is enabled in ADMX, check Defrag Service is running"
		Invoke-BISFService -ServiceName defragsvc -StartType manual -Action Start
		Restart-Service defragsvc | Out-Null
	}

	Write-BISFLog -Msg "Define Defrag arguments based on OS-Version"
	$defragargs = ""
	IF ($OSVersion -like "6.1*") { $defragargs = "/H /O" } #Windows Server 2008 R2 or Windows 7
	IF ($ProductType -eq "1") {  #Desktop OS
		IF ($OSVersion -like "6.2*") { $defragargs = "/H /O" } #Windows 8
		IF ($OSVersion -like "6.3*") { $defragargs = "/H /O" } #Windows 8.1
	}
	Else { #Member Server
		IF ($OSVersion -like "6.2*") { $defragargs = "/H /O" } #Windows Server 2012
		IF ($OSVersion -like "6.3*") { $defragargs = "/H /O" } #Windows Server 2012 R2
	}
	IF ($OSVersion -like "10.*") { $defragargs = "/H" } #Windows Server 2016/2019, Windows 10

	IF ($defragargs -eq "") {
		$defragargs = "/U"
		Write-BISFLog -Msg "Unsuported OS-Version $OSVersion detected. The defrag arguments would be set to standard values: $defragargs" -Type W
	}
	ELSE {
		Write-BISFLog -Msg "OS-Version $OSVersion and Producttype $ProductType detected, set defrag arguments: $defragargs"
	}

	IF ($LIC_BISF_CLI_SB -eq "") {
		$LIC_BISF_CLI_SB = "YES"
		Write-BISFLog -Msg "CLI Switch for Shutdown Base Image (-Shutdown YES or -Shutdown NO) not specified, it would be set to shutdown the Base Image after successfull build"
	}

	# All commands that are used to after successfully build the base image
	[array]$PostCommands = @()
	If ($TestDiskMode) {
		$DiskNameExtension = Get-BISFDiskNameExtension
		IF (($DiskNameExtension -eq "BaseDisk") -or ($DiskNameExtension -eq "noVirtualDisk")) {
			IF ($DiskNameExtension -eq "noVirtualDisk") {
				Write-BISFLog -Msg "Running Section noVirtualDisk"
				IF ($LIC_BISF_CLI_P2V_PT -eq "1") {
					# Custom UNC-Path for vDisk enabled
					$vhdext = $LIC_BISF_CLI_PT_FT
					$vhdpath = $LIC_BISF_CLI_P2V_PT_CUS
					$Global:VHDFileToDefrag = "$vhdpath" + "\" + $vDiskName + "." + $vhdext
					$PostCommands += [pscustomobject]@{Order = "010"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_DF"; Description = "Run defrag on mounted offline file in $VHDFileToDefrag ? "; Command = "Start-BISFVHDOfflineDefrag" }
				}
				ELSE {
					$vDiskDriveLetter = $env:SystemDrive
					$PostCommands += [pscustomobject]@{Order = "010"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_DF"; Description = "Run defrag on the Drive $vDiskDriveLetter ? "; Command = "Start-BISFProcWithProgBar -ProcPath '$($env:windir)\system32\defrag.exe' -Args '$vDiskDriveLetter $defragargs' -ActText 'Defrag is running'" }
				}
			}
			ELSE {
				Write-BISFLog -Msg "Running Section VirtualDisk"
				IF ($LIC_BISF_CLI_P2V_PT -eq "1") {
					# Custom UNC-Path for vDisk enabled
					IF ($DiskNameExtension -eq "BaseDisk") {
						$vDiskDriveLetter = $env:SystemDrive
						$PostCommands += [pscustomobject]@{Order = "010"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_DF"; Description = "Run defrag on the Drive $vDiskDriveLetter ? "; Command = "Start-BISFProcWithProgBar -ProcPath '$($env:windir)\system32\defrag.exe' -Args '$vDiskDriveLetter $defragargs' -ActText 'Defrag is running'" }
					}
					ELSE {
						$vhdext = $LIC_BISF_CLI_PT_FT
						$vhdpath = $LIC_BISF_CLI_P2V_PT_CUS
						$Global:VHDFileToDefrag = "$vhdpath" + "\" + $vDiskName + "." + $vhdext
						$PostCommands += [pscustomobject]@{Order = "010"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_DF"; Description = "Run defrag on mounted offline file in $VHDFileToDefrag ? "; Command = "Start-BISFVHDOfflineDefrag" }
					}
				}
				ELSE {
					$PostCommands += [pscustomobject]@{Order = "010"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_DF"; Description = "Run defrag on the Drive $vDiskDriveLetter ? "; Command = "Start-BISFProcWithProgBar -ProcPath '$($env:windir)\system32\defrag.exe' -Args '$vDiskDriveLetter $defragargs' -ActText 'Defrag is running'" }
				}
			}
		}
		ELSE {
			Write-BISFLog "Defrag runs on BaseDisk or with noVirtualDisk assigned , $DiskNameExtension detected" -Type W
		}
	}
	ELSE {
		IF ($CTXAppLayerName -eq "No-ELM") {
			Write-BISFLog -Msg "Running Section No-ELM"
			$vDiskDriveLetter = $env:SystemDrive
			$PostCommands += [pscustomobject]@{Order = "010"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_DF"; Description = "Run defrag on the Drive $vDiskDriveLetter ? "; Command = "Start-BISFProcWithProgBar -ProcPath '$($env:windir)\system32\defrag.exe' -Args '$vDiskDriveLetter $defragargs' -ActText 'Defrag is running'" }
		}
		ELSE {
			Write-BISFLog "Defrag not performed, not defined based on DiskMode $DiskMode"
		}

	}
	$PersState = $TaskStates[1]
	$PostCommands += [pscustomobject]@{Order = "998"; Enabled = "$true"; showmessage = "N"; CLI = ""; Description = "Set Personalization State in Registry, to control Preparation is running after Personalization first"; Command = "Set-ItemProperty -Path '$hklm_software_LIC_CTX_BISF_SCRIPTS' -Name 'LIC_BISF_PersState' -value '$PersState' -force " }
	$PostCommands += [pscustomobject]@{Order = "999"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_SB"; Description = "Base Image $computer successfully build, shutdown System ? "; Command = "Start-BISFProcWithProgBar -ProcPath '$($env:windir)\system32\shutdown.exe' -Args '/s /t 30 /d p:2:4 /c ""BIS-F shutdown finalize in 30 seconds..."" ' -ActText 'Sealing completed.. waiting for shutdown in 30 seconds'" }

	####################################################################
	# Post Command after succesfull build vDisk
	function PostCommand {
		Write-BISFLog -Msg "Running PostCommands on your Base Image" -ShowConsole -Color Green
		Foreach ($postCommand in ($PostCommands | Sort-Object -Property "Order")) {
			Write-BISFLog -Msg "$($PostCommand.Description)" -ShowConsole -Color DarkGreen -SubMsg
			IF (($PostCommand.showmessage) -eq "N") {
				Write-BISFLog -Msg "$($PostCommand.Command)"
				Invoke-Expression $($PostCommand.Command)
			}
			ELSE {
				Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
				$varCLI = Get-Variable -Name $($PostCommand.CLI) -ValueOnly
				If (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
					Write-BISFLog -Msg "GPO Valuedata: $varCLI"
				}
				ELSE {
					Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
					$DefaultValue = "No"
				}

				If (($varCLI -eq "YES") -or ($DefaultValue -eq "YES")) {

					Write-BISFLog -Msg "Running Command $($PostCommand.Command)"
					Invoke-Expression $($PostCommand.Command)
				}
				ELSE {
					Write-BISFLog -Msg " Skipping Command $($prepCommand.Description)" -ShowConsole -Color DarkCyan -SubMsg
				}

				# these 2 variables must be cleared after each step, to not store the value in the variable and use them in the next $PostCommand
				$varCLI = @()
				$PreMsgBox = @()
			}

		}
		####################################################################
	}
	
	function Start-AppLayeringLayerFinalze {
		IF (!($CTXAppLayerName -eq "No-ELM")) {
			IF ($CTXAppLayeringSW) {
				$tmpLogFile = "C:\Windows\logs\BISFtmpProcessLog.log"
				Write-BISFLog -Msg "Prepare Citrix AppLayering" -ShowConsole -Color Cyan
				$txt = "Prepare AppLayering - List and remove unused network devices"
				Write-BISFLog -Msg "$txt" -ShowConsole -Color DarkCyan -SubMsg
				$ctxAppLay1 = Start-Process -FilePath "${env:ProgramFiles}\Unidesk\Uniservice\Uniservice.exe" -ArgumentList "-G" -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
				Show-BISFProgressBar -CheckProcessId $ctxAppLay1.Id -ActivityText "$txt"
				Get-BISFLogContent -GetLogFile "$tmpLogFile"
				Remove-Item -Path "$tmpLogFile" -Force | Out-Null

				$txt = "Prepare AppLayering - Check System Layer integrity"
				Write-BISFLog -Msg "$txt" -ShowConsole -Color DarkCyan -SubMsg
				$ctxAppLay2 = Start-Process -FilePath "${env:ProgramFiles}\Unidesk\Uniservice\Uniservice.exe" -ArgumentList "-L" -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
				Show-BISFProgressBar -CheckProcessId $ctxAppLay2.Id -ActivityText "$txt"
				Get-BISFLogContent -GetLogFile "$tmpLogFile"
				$ctxAppLay2log = Test-BISFLog -CheckLogFile "$tmpLogFile" -SearchString "allowed"
				Remove-Item -Path "$tmpLogFile" -Force | Out-Null
				IF ($ctxAppLay2log -eq $true) {
					Write-BISFLog -Msg "Layer finalize is allowed" -ShowConsole -Color DarkCyan -SubMsg
				}
				ELSE {
					Write-BISFLog -Msg "Layer finalize is NOT allowed, this issue is sending out from AppLayering and not BIS-F, please check the BIS-F log for further informations" -SubMsg -Type E
				}

			}
		}
		ELSE {
			Write-BISFLog -Msg "AppLayering is running $($CTXAppLayerName), UniService must not optimized" -ShowConsole -Color Cyan
		}
	}
	
}

Process {

	#### Main Program
	Write-BISFLog -Msg "Write Sysprep status to registry location Path: $hklm_software_LIC_CTX_BISF_SCRIPTS -Name: LIC_BISF_RunSysPrep -Value: $RunSysPrep"
	Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_RunSysPrep" -value "$RunSysPrep" #-ErrorAction SilentlyContinue
	
	Start-AppLayeringLayerFinalze
	
	IF ($returnTestPVSSoftware -eq $true) {
		IF ($CTXAppLayeringSW) {
			Write-BISFLog -Msg "Successfully build your Base Image with Citrix AppLayering - $CTXAppLayerName ..." -ShowConsole -Color DarkCyan -SubMsg
			if (Test-Path $bootIdPath) {
				$bootId = Get-Content -Path $bootIdPath
				& bcdedit /bootsequence $bootId
				$shutdownFlag = "/r"
				$PostCommands = $PostCommands | where { $_.order -ne "999" }
				$PostCommands += [pscustomobject]@{Order = "999"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_SB"; Description = "Base Image $computer successfully build, restart System ? "; Command = "Start-BISFProcWithProgBar -ProcPath '$($env:windir)\system32\shutdown.exe' -Args '/r /t 30 /d p:2:4 /c ""BIS-F restart finalize in 30 seconds..."" ' -ActText 'Sealing completed.. waiting for restart in 30 seconds'" }
				Write-BISFLog -Msg "Machine will be restarted to allow layer finalize ..." -ShowConsole -Color DarkCyan -SubMsg
			}
			PostCommand
		}
		ELSE {
			IF ($SkipPVSImaging -eq $false) {
				IF ($CheckP2PVSlog -eq $true) {
					$CheckPVSLog = Test-BISFLog -CheckLogFile "$P2PVS_LOGFile" -SearchString "$P2PVS_LOGFile_search"
					get-BISFLogContent -GetLogFile "$P2PVS_LOGFile"
					IF ($CheckPVSLog -ne "") {
						Write-BISFLog -Msg "Successfully build your Base Image..." -ShowConsole -Color DarkCyan -SubMsg
						Write-BISFLog -Msg "vDisk $P2PVS_LOGFile_search"
						PostCommand
					}
					ELSE {
						Write-BISFLog -Msg "vDisk operation NOT successfull, check $P2PVS_LOGFile for further details" -Type E
					}
				}
				IF ($CheckP2PVSlog -eq $false) {
					Write-BISFLog -Msg "Successfully build your Base Image..." -ShowConsole -Color DarkCyan -SubMsg
					PostCommand
				}

				IF ($CheckP2PVSlog -eq "ERROR") {
					get-BISFLogContent -GetLogFile "$P2PVS_LOGFile"
					Write-BISFLog -Msg "vDisk operation NOT successfull, check $LIC_PVS_LogPath for further details" -Type E
				}
			}
			ELSE {
				Write-BISFLog -Msg "Execution of PostCommands are skipped, if the PVS Master Image creation is skipped..." -ShowConsole -Color Yellow -Type W
				Start-Sleep -s 30
			}
		}
	}
	ELSE {
		IF ($ImageSW -eq $true) {
			IF ($CTXAppLayeringSW) {
				$txt = "Successfully build your Base Image with Citrix AppLayering in $CTXAppLayerName ..."
				if (Test-Path $bootIdPath) {
					$bootId = Get-Content -Path $bootIdPath
					& bcdedit /bootsequence $bootId
					$shutdownFlag = "/r"
					$PostCommands = $PostCommands | where { $_.order -ne "999" }
					$PostCommands += [pscustomobject]@{Order = "999"; Enabled = "$true"; showmessage = "Y"; CLI = "LIC_BISF_CLI_SB"; Description = "Base Image $computer successfully build, restart System ? "; Command = "Start-BISFProcWithProgBar -ProcPath '$($env:windir)\system32\shutdown.exe' -Args '/r /t 30 /d p:2:4 /c ""BIS-F restart finalize in 30 seconds..."" ' -ActText 'Sealing completed.. waiting for restart in 30 seconds'" }
					Write-BISFLog -Msg "Machine will be restarted to allow layer finalize ..." -ShowConsole -Color DarkCyan -SubMsg
				}
			}
			ELSE {
				$txt = "Successfully build your Base Image.."
			}
			Write-BISFLog -Msg "$txt" -ShowConsole -Color DarkCyan -SubMsg
			PostCommand
		}
		ELSE {
			IF ($RunSysPrep -eq $true) {
				Write-BISFLog -Msg "Running Sysprep to seal the Base Image" -ShowConsole -Color DarkCyan -SubMsg
				$LIC_BIS_Sysprep_ServiceList = $LIC_BIS_Sysprep_ServiceList -join ","
				Write-BISFLog -Msg "Write Sysprep ServiceList to registry location: $hklm_software_LIC_CTX_BISF_SCRIPTS -Name: LIC_BISF_SysPrep_ServiceList -Value: $LIC_BIS_Sysprep_ServiceList"
				Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BIS_Sysprep_ServiceList" -value "$LIC_BIS_Sysprep_ServiceList" #-ErrorAction SilentlyContinue
				$SysPrepLog = "C:\Windows\System32\sysprep\Panther\setuperr.log"

				IF ((Test-Path ("$SysPrepLog") -PathType Leaf )) {
					Write-BISFLog -Msg "Deleting old Sysprep log file $SysPrepLog" -ShowConsole -Color DarkCyan -SubMsg
					Remove-Item $SysPrepLog -recurse -ErrorAction SilentlyContinue
				}
				IF ($LIC_BISF_CLI_SP_CusArgsb) {
					Write-BISFLog -Msg "Enable Custom Sysprep Arguments"
					$args = $LIC_BISF_CLI_SP_CusArgs
				}
				ELSE {
					$args = "/generalize /oobe /quiet /quit "
				}
				Write-BISFLog -Msg "Running Sysprep with arguments: $args"
				Start-BISFProcWithProgBar -ProcPath "C:\Windows\System32\sysprep\sysprep.exe" -Args $args -ActText "Sysprep is running..."
				$CheckSysPrepLog = Test-BISFLog -CheckLogFile "$SysPrepLog" -SearchString "Error"
				IF ($CheckSysPrepLog -eq $true) {
					#syspreplog show errors
					get-BISFLogContent -GetLogFile "$SysPrepLog"
					Write-BISFLog -Msg "Sysprep encounter an error, check $SysPrepLog for further details" -Type E -SubMsg
				}
				ELSE {
					Write-BISFLog -Msg "Sysprep run successfully" -ShowConsole -Color DarkCyan -SubMsg
					PostCommand
				}
			}
			ELSE {
				Write-BISFLog -Msg "No Image Management Software detected [Citrix PVS Target Device Driver, XenDesktop VDA or VMware View Agent]" -Type W
				Write-BISFLog -Msg "The system will not be shutdown by this script. Please run Sysprep or your prefered method manualy or install one of the software above and run the script again" -Type W
				Start-Sleep -s 30
			}
		}
	}

}

End {
	Add-BISFFinishLine
}
