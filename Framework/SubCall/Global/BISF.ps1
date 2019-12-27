[CmdletBinding(SupportsShouldProcess = $true)]
param()
<#
    .Synopsis
      Load Global environment
    .Description
      Setting the global configuration needed for BISF
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Matthias Schlimm
      Editor: Mike Bijl (Rewritten variable names and script format)
      Company:  EUCWeb.com

    History
		10.09.2013 MS: Script created
		16.09.2013 MS: function to read values from registry
		17.09.2013 MS: Add global values for Folders
		17.09.2013 MS: edit scriptlogic to get varibales and their values from registry, if not defined use script defined values
		18.09.2013 MS: syntax error line 140 -Erroraction SilentlyContinue
		18.09.2013 MS: add rearm values for OS (Operting System) and OF (Office)
		18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		18.09.2013 MS: Add varibale LIC_PVS_CtxImaPath to redirect local hostcache
		18.09.2013 MS: remove $LIB & $Subcall folder from gloabl variable
		18.09.2013 MS: add function CheckPVSDriveLetter and CheckPVSSysVariable
		19.09.2013 MS: remove $LOG = "C:\Windows\Log\$PSScriptName.log"
		19.09.2013 MS: add $regvarfound = @()
		19.09.2013 MS: add function CheckRegHive
		01.10.2013 MS: add global value LIC_PVS_RefSrv_HostName to detect ReferenceServer
		17.12.2013 MS: Errorhandling: add return $false for exit script
		18.12.2013 MS: Line 47: $varfound = @()
		28.01.2014 MS: Add $return for ErrorHandling
		28.01.2014 MS: Add CheckHostIDDir
		03.03.2014 BR: Revisited Script
		10.03.2014 MS: Remove Write-BISFLog in Line 139 and replace with Write-Host
		10.03.2014 MS: [array]$reg_value_data += "15_XX_Custom"
		21.03.2014 MS: last code change before release to web
		01.04.2014 MS: move central functions to 10_XX_LIB_Functions.psm1
		02.04.2014 MS: add variable to redirect Cache Location ->  $LIC_PVS_CtxCache
		02.04.2014 MS: Fix: wrong Log-Location
		15.05.2014 MS: Add get-Version to show current running version
		11.08.2014 MS: remove $returnCheckPVSDriveLetter
		12.08.2014 MS: remove to much entries for logging
		12.08.2014 MS: move function set-logfie from 10_XX_LIB_Functions.psm1 to 10_XX_LIB_Config.ps1, this function would be run from this script only and no more from other scripts
		13.08.2014 MS: add IF ($PVSDiskDrive -eq $null) {$PVSDiskDrive ="C:\Windows\Logs"}
		14.08.2014 MS: change function Set-Logfile if the Drive is not reachable
		15.08.2014 MS: add line 242: get-OSinfo
		15.08.2014 MS: add line 245: CheckXDSoftware
		18.08.2014 MS: move Logfilefolder PVSLogs to new Folder BISLogs\PVSLogs_old and remove the registry entry LIC_PVS_LogPath, their no longer needed
		31.10.2014 MB: Renamed functions: CheckXDSoftware -> Test-XDSoftware / CheckPVSSoftware -> Test-PVSSoftware / CheckPVSDriveLetter -> Get-PVSDriveLetter / CheckRegHive -> Test-BISFRegHive
		31.10.2014 MB: Renamed variables: returnCheckPVSSysVariable -> returnTestPVSEnvVariable
		14.04.2015 MS: Get-TaskSequence to activate or suppress a SystemShutdown
		14.04.2015 MS: detect if running from SCCM/MDT Tasksequence, if so it sets the logfile location to the the task sequence “LogPath”
		02.06.2015 MS: define new gobal variables for all not predefined customobjects in $BISFconfiguration, do i need to store the CLI commands in registry
		02.06.2015 MS: running from SCCM or MDT ->  changing to $logpath only (prev. $LogFilePath = "$logPath\$LogFolderName"), only files directly in the folder are preserved, not subfolders
		10.08.2015 MS: Bug 50 - added existing funtion $Global:returnTestPVSDriveLetter=Test-PVSDriveLetter -Verbose:$VerbosePreference
      	21.08.2015 MS: remove all XX,XA,XD from al files and Scripts
      	29.09.2015 MS: Bug 93: check if preperation phase is running to run $Global:returnTestPVSDriveLetter=Test-PVSDriveLetter -Verbose:$VerbosePreference
    	16.12.2015 MS: redirect spool directory to PVS WriteCacheDisk, if PVS Target Device Driver is installed only
      	16.12.2015 MS: redirect eventlogs (Aplication, Security, System) to PVS WriteCacheDisk, if PVS Target Device Driver is installed only
	 	07.01.2016 MS: Feature 20: add VMware Horizon View detection
	 	27.01.2016 MS: move $State -eq "Preparation" from BISF.ps1 to function Test-BISFPVSDriveLetter
	  	28.01.2016 MS: add Request-BISFsysprep
	  	02.03.2016 MS: check PVS DiskMode at Prerequisites, to get an error on startup if Disk is in ReadOnly Mode
	 	18.10.2016 MS: change LIC_BISF_MAIN_PersScript to new folderPath, remove wrong clip "}"
      	19.10.2016 MS: add $Global:LogFilePath = "$LogPath"  to function Set-LogFile
	  	27.07.2017 MS: replace redirection of spool and evt-logs with central function Use-BISFPVSConfig, if using Citrix AppLayering with PVS it's a complex matrix to redirect or not.
	  	03.08.2017 MS: add $Gloabl:BootMode = Get-BISFBootMode to get UEFI or Legacy
	  	14.08.2017 MS: add cli switch ExportSharedConfiguration to export BIS-F ADMX Reg Settings into an XML File
	  	07.11.2017 MS: add $LIC_BISF_3RD_OPT = $false, if vmOSOT or CTXO is enabled and found, $LIC_BISF_3RD_OPT = $true and disable BIS-F own optimizations
	  	11.11.2017 MS: Retry 30 times if Logshare on network path is not found with fallback after max. is reached
		02.07.2018 MS: Bufix 50 - function Set-Logfile -> invoke-BISFLogShare   (After LogShare is changed in ADMX, the old path will also be checked and skips execution)
		20.10.2018 MS: Feature 63 - Citrix AppLayering - Create C:\Windows\Logs folder automatically if it doesn't exist
		13.08.2019 MS: ENH 97 - Nutanix Xi Frame Support
		14.08.2019 MS: ENH 6 - Parallels RAS Support
		25.08.2019 MS: ENH 132 - Windows 10 Enterprise for Virtual Desktops (WVD) Support
		25.08.2019 MS: FRQ 85 - Make SCCM / MDT Tasksequence Logfile redirection optional
		21.09.2019 MS: EHN 36 - Shared Configuration - JSON Export
		03.10.2019 MS: ENH 126 - MCSIO persistent drive
		03.10.2019 MS: ENH 28 - Check if there's enough disk space on P2V Custom UNC-Path
		05.10.2019 MS: ENH 12 - AMDX Extension: Configure sDelete
		05.10.2019 MS: ENH 22 - Get DiskID's of the system - for monitoring only ->  for later use to fix 'Endless Reboot with VMware Paravirtual SCSI disk'
		05.10.2019 MS: ENH 144 - Enable Powershell Transcript
		05.10.2019 MS: ENH 52 - Citrix AppLayering - different shared configuration based on Layer
		08.10.2019 MS: ENH 146 - Move Get-PendingReboot to earlier phase of preparation
		08.10.2019 MS: ENH 93 - Detect Citrix Cloud Connector installation and prevent BIS-F to run
		27.12.2019 MS/MN: HF 160 - typo for Calculation of free space for the VHDX file

      #>
Begin {

	####################################################################
	# Setting default variables ($PSScriptroot/$logfile/$PSCommand,$PSScriptFullname/$scriptlibrary/LogFileName) independent on running script from console or ISE and the powershell version.
	If ($($host.name) -like "* ISE *") {
		# Running script from Windows Powershell ISE
		$PSScriptFullName = $psise.CurrentFile.FullPath.ToLower()
		$PSCommand = (Get-PSCallStack).InvocationInfo.MyCommand.Definition
	}
 Else {
		$PSScriptFullName = $MyInvocation.MyCommand.Definition.ToLower()
		$PSCommand = $MyInvocation.Line
	}
	[string]$PSScriptName = (Split-Path $PSScriptFullName -leaf).ToLower()
	If (($PSScriptRoot -eq "") -or ($PSScriptRoot -eq $null)) { [string]$PSScriptRoot = (Split-Path $PSScriptFullName).ToLower() }

	####################################################################
	#maximize Window
	If ($Host.Name -match "console") {
		$MaxHeight = $host.UI.RawUI.MaxPhysicalWindowSize.Height
		$MaxWidth = $host.UI.RawUI.MaxPhysicalWindowSize.Width
	}


	# initialize script array
	If (($PVSDiskDrive -eq $null) -or ($PVSDiskDrive -eq "") -or ($PVSDiskDrive -eq "NONE")) { $PVSDiskDrive = "C:\Windows\Logs" }

	# Predefined BISF configuration values
	[array]$BISFconfiguration = @(
		[pscustomobject]@{description = "LogFileFolder"; value = "LIC_BISF_LogPath"; data = "$PVSDiskDrive\BISFLogs"; FoundinReg = "$false" },
		[pscustomobject]@{description = "CitrixFolder"; value = "LIC_BISF_CtxPath"; data = "$PVSDiskDrive\Citrix"; FoundinReg = "$false" },
		[pscustomobject]@{description = "RedirectedLocalHostCache"; value = "LIC_BISF_CtxImaPath"; data = "$PVSDiskDrive\Citrix\IMA"; FoundinReg = "$false" },
		[pscustomobject]@{description = "RedirectedCitrixLicense"; value = "LIC_BISF_CtxCache"; data = "$PVSDiskDrive\Citrix\Cache"; FoundinReg = "$false" },
		[pscustomobject]@{description = "RedirectedEventLogs"; value = "LIC_BISF_EvtPath"; data = "$PVSDiskDrive\EventLogs"; FoundinReg = "$false" },
		[pscustomobject]@{description = "RedirectedPrintSpoolPath"; value = "LIC_BISF_SpoolPath"; data = "$PVSDiskDrive\Spool"; FoundinReg = "$false" },
		[pscustomobject]@{description = "CitrixUPMLogPath"; value = "LIC_BISF_UPMPath"; data = "$PVSDiskDrive\UPM"; FoundinReg = "$false" },
		[pscustomobject]@{description = "BISFPrepScripts"; value = "LIC_BISF_PrepFldr"; data = "Preparation"; FoundinReg = "$false" },
		[pscustomobject]@{description = "BISFPersScripts"; value = "LIC_BISF_PersFldr"; data = "Personalization"; FoundinReg = "$false" },
		[pscustomobject]@{description = "BISFPersScriptMain"; value = "LIC_BISF_MAIN_PersScript"; data = "$Main_Folder\PersBISF_Start.ps1"; FoundinReg = "$false" },
		[pscustomobject]@{description = "CustomScriptsFolder"; value = "LIC_BISF_CustomFldr"; data = "Custom"; FoundinReg = "$false" },
		[pscustomobject]@{description = "OSRearm_Enable"; value = "LIC_BISF_RearmOS_run"; data = "0"; FoundinReg = "$false" },
		[pscustomobject]@{description = "RearmOS_UserAccount"; value = "LIC_BISF_RearmOS_user"; data = $false; FoundinReg = "$false" },
		[pscustomobject]@{description = "RearmOS_Date"; value = "LIC_BISF_RearmOS_date"; data = $false; FoundinReg = "$false" },
		[pscustomobject]@{description = "RearmOF_Enable"; value = "LIC_BISF_RearmOF_run"; data = "0"; FoundinReg = "$false" },
		[pscustomobject]@{description = "RearmOF_UserAccount"; value = "LIC_BISF_RearmOF_user"; data = $false; FoundinReg = "$false" },
		[pscustomobject]@{description = "RearmOF_Date"; value = "LIC_BISF_RearmOF_date"; data = $false; FoundinReg = "$false" },
		[pscustomobject]@{description = "MTDHostname"; value = "LIC_BISF_RefSrv_HostName"; data = "$computer"; FoundinReg = "$false" },
		[pscustomobject]@{description = "OptDrive_DriveLetter"; value = "LIC_BISF_OptDrive"; data = $false; FoundinReg = "$false" },
		[pscustomobject]@{description = "ZCMAgent_args"; value = "LIC_BISF_ZCM_CFG"; data = ""; FoundinReg = "$false" },
		[pscustomobject]@{description = "3rd Party Optimizer"; value = "LIC_BISF_3RD_OPT"; data = "$false"; FoundinReg = "$false" }
	)

	####################################################################
	####### functions #####
	####################################################################

	function Set-Logfile {
		IF (!(Test-Path "$env:windir\Logs")) {
			Write-BISFLog -Msg "Folder $env:windir\Logs NOT Exist, will be created now !" -Type W -ShowConsole
			New-Item -ItemType Directory -path "$env:windir\Logs" | Out-Null

		}
		Try {
			#Try to Create BISFLogsFolder
			$LogPath = "$PVSDiskDrive\$LogFolderName"
			IF ($LIC_BISF_CLI_LSb -eq 1) {
				Invoke-BISFLogShare -Verbose:$VerbosePreference
				for ($i = 0; $i -le 30; $i++) {
					IF (!(Test-Path $LIC_BISF_LogShare)) {
						Write-BISFLog -Msg "Retry $($i): Path $LIC_BISF_LogShare not reachable" -Type W -SubMsg -ShowConsole
						$LogShareReachable = $false
						Start-Sleep -Seconds 1
					}
					ELSE {
						Write-BISFLog -Msg "Path $LIC_BISF_LogShare reachable" -SubMsg -ShowConsole -Color DarkCyan
						$LogShareReachable = $true
						break
					}
				}
				IF ($LogShareReachable -eq $true)
				{ $LogPath = "$LIC_BISF_LogShare\$computer" } ELSE { $LogPath = "$PVSDiskDrive\$LogFolderName"; Write-BISFLog -Msg "Fallback to logpath $LogPath" -Type W -ShowConsole -SubMSg }
			}
			Write-BISFLog -Msg "Creating log folder on path $LogPath" -ShowConsole -SubMsg -Color DarkCyan
			New-Item -Path $LogPath -ItemType Directory -ErrorAction Stop
		}
		Catch [System.IO.DirectoryNotFoundException] {
			Write-BISFLog -Msg "Cannot create BISFLog folder, the volume is not formatted" -Type W -SubMsg
			$LogPath = "C:\Windows\Logs\$LogFolderName"
			New-Item -Path $LogPath -ItemType Directory -Force
		}
		Catch [System.IO.IOException] {
			Write-BISFLog -Msg "BISFLog folder already exists"
			#$LogPath = $LogPath
		}
		Catch [System.UnauthorizedAccessException] {
			Write-BISFLog -Msg "Cannot create BISFLog folder, the drive is not writeable" -Type W -SubMsg
			$LogPath = "C:\Windows\Logs\$LogFolderName"
			New-Item -Path $LogPath -ItemType Directory -Force
		}
		Catch {
			Write-BISFLog -Msg "Unhandeled Exception occured" -Type W -SubMsg
			$LogPath = "C:\Windows\Logs\$LogFolderName"
			New-Item -Path $LogPath -ItemType Directory -Force
		}
		Finally {

			$ErrorActionPreference = "Continue"
			Write-BISFLog -Msg "Move BIS-F log to $LogPath" -ShowConsole -Color DarkCyan -SubMsg
			Get-ChildItem -Path "C:\Windows\Logs\*" -Include "PREP_BISF*.log","PERS_BISF*.log" -Exclude "*BISF_WPT*.log" -Recurse | Move-Item -Destination $LogPath -Force
			IF (($NewLogPath) -and ($NewLogPath -ne $LogPath)) {
				Write-BISFLog -Msg "Move BIS-F log from $NewLogPath to $LogPath" -ShowConsole -Color DarkCyan -SubMsg
				Get-ChildItem -Path "$($NewLogPath)\*" -include "PREP_BISF*.log","PERS_BISF*.log" -Exclude "*BISF_WPT*.log" -Recurse | Move-Item -Destination $LogPath -Force
			}

			$Global:Logfile = "$LogPath\$LogFileName"
			$Global:LogFilePath = $LogPath
			$Global:NewLogPath = $LogPath
		}
		return $logfile
	}




	function Get-ActualConfig {
		[CmdletBinding(SupportsShouldProcess = $true)]
		param()
		#Write-BISFLog -Msg "read values from registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
		# Get all values and data from the BISF registry key
		$regvalues = Get-BISFRegistryValues "$hklm_software_LIC_CTX_BISF_SCRIPTS"
		# Check for every key found if this is a valid configuration item and update the data of the value
		Foreach ($regvalue in $regvalues) {
			# look if there is a value in the $BISFconfiguration with the same name as the registry value
			$predefineddata = ($BISFconfiguration | where { $_.value -eq ($regvalue.value) }).data
			If ($predefineddata -ne $null) {
				$defaultdata = ($BISFconfiguration | where { $_.value -eq ($regvalue.value) }).data
				($BISFconfiguration | where { $_.value -eq ($regvalue.value) }).data = $regvalue.data # Update the data property in the array with the regvalue data
				($BISFconfiguration | where { $_.value -eq ($regvalue.value) }).FoundInReg = $true # Update the FoundInReg property in the array with $true
				#Write-BISFLog -Msg "The value `"$($regvalue.value)`" with data `"$($regvalue.data)`" read from registry $hklm_software_LIC_CTX_BISF_SCRIPTS overwrites the default value `"$defaultdata`""
			}
			ELSE {
				#Write-BISFLog -Msg "The value `"$($regvalue.value)`" with data `"$($regvalue.data)`" read from registry $hklm_software_LIC_CTX_BISF_SCRIPTS is not a valid configuration item."
				New-BISFGlobalVariable -Name $($regvalue.value) -Value $($regvalue.data)
			}
		}
	}
}

####################################################################
####### end functions #####
####################################################################

Process {

	Write-BISFLog -Msg "Setting LogFile to $(Set-Logfile -Verbose:$VerbosePreference)" -ShowConsole -Color DarkCyan -SubMsg
	Get-ActualConfig -Verbose:$VerbosePreference # Update the $BISFconfiguration with possible registry values
	Write-BISFLog -Msg "Update LogFile to $(Set-Logfile -Verbose:$VerbosePreference)" -ShowConsole -Color DarkCyan -SubMsg
	Get-BISFVersion -Verbose:$VerbosePreference
	Get-BISFOSCSessionType -Verbose:$VerbosePreference
	IF ($LIC_BISF_PrepLastRunTime) { Write-BISFLog -Msg "Last BIS-F Preparation would be performed on $LIC_BISF_PrepLastRunTime started from user $LIC_BISF_PrepLastRunUser" -ShowConsole -Color DarkCyan -SubMsg }
	Set-BISFLastRun -Verbose:$VerbosePreference
	Write-BISFLog -Msg "Running $State Phase" -ShowConsole -Color DarkCyan -SubMsg
	Invoke-BISFLogRotate -Versions 5 -Directory "$LogFilePath" -Verbose:$VerbosePreference
	Invoke-BISFLogShare -Verbose:$VerbosePreference
	Get-BISFOSinfo -Verbose:$VerbosePreference
	IF ($LIC_BISF_CLI_LOG_WPT -eq 1) {
		Write-BISFLog -Msg "Windows Powershell Transcript enabled: $WPTLog" -ShowConsole -Color Cyan
		Invoke-BISFLogRotate -Versions 5 -Directory "C:\Windows\Logs" -Verbose:$VerbosePreference
	}
	IF ($ExportSharedConfiguration) {
		#check switch ExportSharedConfiguration
		# EHN 36 - Shared Configuration - JSON Export
		IF ($LIC_BISF_CLI_EX_PT) {
			#check Path in Registry if set
			IF ($LIC_BISF_POL_AppLayCfg -eq 1) {
				#check if Citrix AppLayering is configured
				Write-BISFlog "Running Export Shared Configuration for Citrix AppLayering" -ShowConsole -Color Cyan

				Write-Host "Select the Citrix AppLayering Layer to export the current configuration" -ForegroundColor Green
				Write-Host " "
				#create dynamic menu based on ADMX configuration
				[array]$menuitem = @()
				[array]$menucfg = @()
				IF ($LIC_BISF_CLI_AppLayOSCfg -eq 1) { [array]$menuitem += "OS Layer"; [array]$menucfg += $AppLayOSCfg }
				IF ($LIC_BISF_CLI_AppLayAppPltCfg -eq 1) { [array]$menuitem += "App-/Platform Layer"; [array]$menucfg += $AppLayAppPltCfg }
				IF ($LIC_BISF_CLI_AppLayPltCfg -eq 1) { [array]$menuitem += "Platform Layer"; [array]$menucfg += $AppLayPltCfg }
				IF ($LIC_BISF_CLI_AppLayNoELMcfg -eq 1) { [array]$menuitem += "Outside ELM"; [array]$menucfg += $AppLayNoELMCfg }

				$i = 0
				ForEach ($item in $MenuItem) {
					Write-Host "     $($i): "$menuitem[$i]
					$i ++
				}

				Write-Host "     99: exit menu"
				Write-Host " "

				[int]$ans = 0
				do {
					try {
						$numOk = $true
						IF ($ans -eq 99) {
							Write-BISFLog "Press any key to exit ..." -ShowConsole -Color Red
							$x = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
							$Global:TerminateScript = $true; Exit
						}
						[int]$ans = Read-Host "Enter the Number of the Layer: (0 - $($i - 1) ) / 99 exit"
					} # end try
					catch { $numOK = $false; }
				} # end do
				until (($ans -ge 0 -and $ans -lt $i) -and $numOK)
				$CfgExportFile = "$LIC_BISF_CLI_EX_PT" + "\" + $($menucfg[$ans])
				Write-BISFlog "Export Registry for $($menuitem[$ans]) to $CfgExportFile" -ShowConsole -Color Cyan
				Export-BISFRegistry "$Reg_LIC_Policies" -ExportType json -exportpath "$CfgExportFile"

			}
			ELSE {

				$CfgOSname = $OSName.replace(' ', '')
				$CfgOSBitness = $OSBitness
				$CfgExportFile = "$LIC_BISF_CLI_EX_PT" + "\BISFconfig_" + $CfgOSname + "_" + $CfgOSBitness + ".json"
				Write-BISFlog "Export Registry to $CfgExportFile" -ShowConsole -Color Cyan
				Export-BISFRegistry "$Reg_LIC_Policies" -ExportType json -exportpath "$CfgExportFile"

			}


		}
		ELSE {
			Write-BISFLog "Error: The custom path for the shared configuration is not configured in the Policy !!" -Type E
		}
		Write-BISFLog "Press any key to exit ..." -ShowConsole -Color Red
		$x = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
		$Global:TerminateScript = $true; Exit

	}

	# ENH 146: move Get-PendingReboot to earlier phase of preparation
	IF ($State -eq "Preparation") {
		#Check pending reboot before continue
		$CheckPndReboot = Get-BISFPendingReboot
		IF (($CheckPndReboot -eq $true) -and (!($LIC_BISF_CLI_EX)) ) {
			IF (($LIC_BISF_CLI_SR -eq "NO") -or !($LIC_BISF_CLI_SR)) {
				$title = "Pending Reboot"
				$text = "A pending system reboot was detected, please reboot the system and run the script again !!!"
				Write-BISFLog -Msg $Text -Type E
				return $false
				break
			}
			ELSE {
				Write-BISFLog -Msg "A pending reboot was detected, but suppressed from GPO configuration !!!" -Type W
			}
		}
		ELSE {
			Write-BISFLog -Msg "Pending system reboot is $CheckPndReboot"
		}
		$null = Test-BISFCitrixCloudConnector
	}

	Get-BISFPSVersion -Verbose:$VerbosePreference
	Test-BISFRegHive -Verbose:$VerbosePreference
	$Global:DiskID = Get-BISFCacheDiskID Verbose:$VerbosePreference
	$Global:returnGetHypervisor = Get-BISFHypervisor -Verbose:$VerbosePreference
	$Global:returnTestAppLayeringSoftware = Test-BISFAppLayeringSoftware -Verbose:$VerbosePreference
	$Global:returnTestXDSoftware = Test-BISFXDSoftware -Verbose:$VerbosePreference
	$Global:returnTestPVSSoftware = Test-BISFPVSSoftware -Verbose:$VerbosePreference
	$Global:returnTestVMHVSoftware = Test-BISFVMwareHorizonViewSoftware -Verbose:$VerbosePreference
	$Global:returnTestXiFrameSoftware = Test-BISFNutanixFrameSoftware -Verbose:$VerbosePreference
	$Global:returnTestParallelsRASSoftware = Test-BISFParallelsRASSoftware -Verbose:$VerbosePreference
	$Global:returnTestWVDSoftware = Test-BISFWVDSoftware -Verbose:$VerbosePreference
	$Global:returnRequestSysprep = Request-BISFSysprep -Verbose:$VerbosePreference
	$Global:DiskMode = Get-BISFDiskMode -Verbose:$VerbosePreference
	$Global:BootMode = Get-BISFBootMode

	#ENH 12: Set sDelete global Value
	IF ($State -eq "Preparation") {
		Write-BISFLog -Msg "Check SDelete $State config" -ShowConsole -Color Cyan
		IF (($LIC_BISF_CLI_SD_runBI -ne 1) -and ($LIC_BISF_CLI_SD_runPVSparentDisk -ne 1) -and ($LIC_BISF_CLI_SD_runOutsideELM -ne 1) -or ($LIC_BISF_CLI_SD -ne "YES")) {
			$Global:RunPrepSdelete = $false
			Write-BISFLog -Msg "SDelete is NOT configured to run during $State" -ShowConsole -Color DarkCyan -SubMsg
		}
		ElSE {
			$Global:RunPrepSdelete = $true
			Write-BISFLog -Msg "SDelete is configured to run during $State" -ShowConsole -Color DarkCyan -SubMsg
		}
	}

	IF ($State -eq "Personalization") {
		Write-BISFLog -Msg "Check SDelete $State config" -ShowConsole -Color Cyan
		IF (($LIC_BISF_CLI_SD_runPVSCacheDisk -ne 1) -and ($LIC_BISF_CLI_SD_runMCSIO -ne 1) -and ($LIC_BISF_CLI_SD_runMCS -ne 1) -or ($LIC_BISF_CLI_SD -ne "YES")) {
			$Global:RunPersSdelete = $false
			Write-BISFLog -Msg "SDelete is NOT configured to run during $State" -ShowConsole -Color DarkCyan -SubMsg
		}
		ElSE {
			$Global:RunPersSdelete = $true
			Write-BISFLog -Msg "SDelete is configured to run during $State" -ShowConsole -Color DarkCyan -SubMsg
		}
	}



	Get-ActualConfig -Verbose:$VerbosePreference # Update the $BISFconfiguration with possible registry values

	# Create Powershell variables from the BISFConfiguration items.
	ForEach ($BISFconfig in $BISFconfiguration) { New-BISFGlobalVariable -Name $BISFconfig.value -Value $BISFconfig.data }

	# 03.10.2019 MS: ENH 126 - depend on the new MCSIO redirection the calling of the functions must be different now
	IF ($returnTestPVSSoftware) {
		IF (($State -eq "Preparation") -and ($LIC_BISF_CLI_P2V_PT -eq "1")) {
			Write-BISFLog -Msg "Check if there enough free Diskspace on the Custom UNC-Path available before proceed" -ShowConsole -Color Cyan
			$FreeSpace = Get-BISFSpace -path "$LIC_BISF_CLI_P2V_PT_CUS" -FreeSpace
			$UsedSpace = Get-BISFSpace -path $env:SystemDrive
			IF ($FreeSpace -le $UsedSpace) {
				Write-BISFLog -Msg "STOP: There is NOT enough Free Space on the Custom UNC path to store the vDisk " -ShowConsole -Type E -SubMsg
			}
			ELSE {
				Write-BISFLog -Msg "Custom UNC Path has $FreeSpace GB left to convert to SystemDrive with $UsedSpace GB" -ShowConsole -Color DarkCyan -SubMsg
			}

		}
		Use-BISFPVSConfig -Verbose:$VerbosePreference  #27.07.2017 MS: new created
	}
	ELSE {
		Use-BISFMCSConfig -Verbose:$VerbosePreference  #03.10.2019 MS: new created
	}

	$TSenvExist = Get-BISFTaskSequence -Verbose:$VerbosePreference
	IF ($TSenvExist -eq $true) {
		IF ($LIC_BISF_CLI_TSLogRedirection -eq 1) {
			$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
			$logPath = $tsenv.Value("LogPath")
			Write-BISFLog -Msg "Set Log folder path to task sequence Log folder $logPath"
			$LogFilePath = "$logPath"
			$oldlogfile = $LogFile
			$Global:Logfile = "$LogFilePath\$LogFileName"

			If (!(Test-Path -Path $LogFilePath)) {
				New-Item -Path $LogFilePath -ItemType Directory -Force
			}

			IF (Test-Path ($oldLogfile) -PathType Leaf ) {
				Move-Item -Path "$OldLogfile" -Destination "$LogFile"
				Write-BISFLog "LogFile $logfile" -ShowConsole -Color DarkCyan -SubMsg
			}
		}
		ELSE {
			Write-BISFLog -Msg "SCCM/MDT Logfile Redirection is NOT enabled, using logpath $LogPath"
		}
	}

}

End {
	Add-BISFFinishLine
}