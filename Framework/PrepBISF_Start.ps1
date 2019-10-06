<#
	.SYNOPSIS
		Prepare BaseImage for Image Management Software like PVS, MCS, VMwareView or ask for Sysprep if nothing of them is installed
	.DESCRIPTION
		Use the parameters for CLI Switches
		For slient automation please configure BIS-F with the additional ADMX templates that can be found in your BIS-F installation folder
	.PARAMETER Verbose
		YES,NO = Enable verbose mode to show supressed messages on console
	.PARAMETER Debug
		Enable debug mode for active debugging, for developers only !!
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)
		Company:  EUCWeb.com

		History:
		24.09.2012 MS: Script created
		03.07.2013 MS: Write Scriptpath to registry $hklm_software\PS-SCRIPTS\COMMON to use in hole environment
		26.08.2013 MS  Removed $XA_PrpPVS_Folder = $SubCall_Folder + "60_XA_PrpPVS\"
		16.09.2013 MS: Added customfolder 99_XX_Custom\20_XX_PrepPVS
		16.09.2013 MS: Load_PS_Folder -def_load_PS_Folder $LIB_Folder
		17.09.2013 MS: Remove unused variable and get Foldernames fom LIB_Config
		18.09.2013 MS: Replace $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		18.09.2013 MS: Predefine $LIB & $Subcall folder
		19.09.2013 MS: IF ($scripts -ne $null)
		17.12.2013 MS: Added $return for Errorhandling and exiting script
		28.01.2014 MS: Changed $return = Invoke-Expression $item.FullName to Invoke-Expression $item.FullName for ErrorHandling returncode
		10.03.2014 BR/MS: ShowMessageBox, review Code
		10.03.2014 MS: Changed to $psfolder = $SubCall_Folder + "15_XX_Custom\20_XX_PrepPVS"
		11.03.2014 MS: For ($i = 1; $i -lt 6; $i++) {write-host}
		11.03.2014 MS: Import-Module $Modules
		18.03.2014 BR: Reviewed code, implemented central functions
		21.03.2014 MS: Last code change, before release to web
		01.04.2014 MS: Code change
		13.05.2014 MS: Added parameter for CLI Switches in silent mode
		11.08.2014 MS: Defined single log file for preparation like Prep_PVS_Target_Scripts_YYYYMMDD-HHMMSS.lg
		12.08.2014 MS: Changed log file name from .log to .bis (BIS = BaseImageScripts)
		14.08.2014 MS: Changed ForegroundColor Green Write-Host "Import Modules $Modules" -ForegroundColor Green
		17.08.2014 MS: Added CLI Switch for Citrix Personal vDisk -> CtxPvd
		18.08.2014 MS: Added computer name to logfilename $Global:LogFileName = "Prep_BIS_$($computer)_$timestamp.bis"
		15.09.2014 MS: Added CLI Switch -P2PVS to use P2PVS instead of XenConvert if installed
		15.09.2014 MS: Added CLI switch -verbose -> $LIC_PVS_CLI_VB to show supressed messages in console
		06.02.2015 MS: Added check if a reboot is pending before continue
		18.02.2015 MS: Added CLI switch -SupressPndReboot to supress a pending reboot
		14.04.2015 MS: Added NoSut CLI Switch to prevent Shutdown after BaseImage successfully build
		05.05.2015 MS: Added check for local execution
		18.05.2015 MS: Added CLI Switch VERYSILENT handling
		20.05.2015 MS: Stored CLI options in registry, add CLI switch ClearCLI to delete all
		10.08.2015 MS: Removed call for function Set-BISFCLIinReg, its currently buggy
		13.08.2015 MS: Added CLI Switch FSXRulesShare to define a central unc share for fsLogix rules and assignments
		21.08.2015 MS: Change Request 77 - remove all XX,XA,XD from al files and Scripts
		04.11.2015 MS: Added CLI option DelAllUsersStartmenu to delete all Objects in C:\ProgramData\Microsoft\Windows\Start Menu\*
		15.12.2015 MS: Added CLI option DisableIPv6 to disable IPv6 completly
		28.01.2016 MS: Added CLI option Sysprep to use them of No Image Management Software detected
		10.03.2016 MS: Added CLI switch DisableConcoleCheck to disable the check if preparation phase is running in console session
		17.03.2016 MS: Added CLI option TurboUpdate to update Turbo.net Supscription on system startup
		17.03.2016 MS: Added CLI option DelProf to delete unused profiles, delprof2.exe must be download first and save in the BIS-F Tools Folder
		04.10.2016 MS: Renamed folder names for global architectural re-design
		23.11.2016 MS: Added CLI option vmOSOT to run VMware OS Optimization Tool if installed in any folder on local drive (C:) only. Running with the default template
		23.11.2016 MS: Added CLI command 'WEMAgentBrokerName' to set the Citrix Workspace Environment Agent BrokerName if not configured via GPO
		10.01.2017 MS: Added CLI command 'XAImagePrepRemoval' during Prepare XenApp for Provisioning you can remove RemoveCurrentServer and ClearLocalDatabaseInformation, this would be set with this Parameter or prompted to administrator to choose
		11.01.2017 MS: Added Cli command 'RESWASdisableBaseImage' to disable RES ONE Automation Agent on Base Image only to prevent RES ONE License usage for your Base Iamges
		27.01.2017 MS: Bug fix 149; Added $Global:LIC_BISF_CLI_LSb="" to define the variable, required for the ADMX templates
		02.01.2017 MS: remove CLI parameters exclude -DebugMode and -Verbose, thi can be configured with the ADMX File
		14.08.2017 MS: add cli switch ExportSharedConfiguration to export BIS-F ADMX Reg Settings into an XML File
		11.09.2017 MS: Getting PersSate from BISF Registry to control running prep after pers is finished
		12.09.2017 MS: using progressbar during wait for the personlization is finished
		16.10.2017 MS: Bugfix detecting wrong POSH Version if running BIS-F remotly, using $PSVersionTable.PSVersion.Major, thx to Fabian Danner
		12.07.2018 MS: Bugfix 40: PendingReboot - give a empty value back
		13.08.2019 MS: ENH 121 - change filenameextension from bis to log
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		21.09.2019 MS: ENH 127 - Personalization is in Active State Override
		05.10.2019 MS: ENH 144 - Enable Powershell Transcript
		06.10.2019 MS: Removing call to Get-BISFScriptExecutionPath

	.LINK
		https://eucweb.com
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
	[switch]$DebugMode,
	[switch]$ExportSharedConfiguration
)


Begin {
	$error.Clear()
	If ( $TerminateScript -is [system.object] ) { Remove-Variable TerminateScript }
	Clear-Host
	$computer = gc env:computername
	$timestamp = Get-Date -Format yyyyMMdd-HHmmss

	## ENH 144 - Powershell Transcript
	$ERRORACTIONPREFERENCE = "STOP"
	try {
		$WPTEnabled = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Login Consultants\BISF" -Name "LIC_BISF_CLI_LOG_WPT").LIC_BISF_CLI_LOG_WPT
	}
	catch { }

	IF ($WPTEnabled -eq 1) {
		$Global:WPTlog = "C:\Windows\Logs\PREP_BISF_WPT_$($computer)_$timestamp.log"
		Start-Transcript $WPTLog | Out-Null
	}
	$ERRORACTIONPREFERENCE = "Continue"

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


	# define environment
	$Global:State = "Preparation"
	$Global:Main_Folder = $PSScriptRoot
	$Global:SubCall_Folder = $PSScriptRoot + "\SubCall\"
	$Global:LIB_Folder = $SubCall_Folder + "Global\"
	$Global:LogFileName = "PREP_BISF_$($computer)_$timestamp.log"
	$Global:LOGFile = "C:\Windows\Logs\$LogFileName"
	$Global:LOG = $LOGFile
	$Global:ExportSharedConfiguration = $ExportSharedConfiguration
	$Global:LIC_BISF_CLI_DB = $DebugMode #DB = debug
	$Global:LIC_BISF_CLI_DF = @() #DF = Defrag
	$Global:LIC_BISF_CLI_SD = @() #SD = SDelete
	$Global:LIC_BISF_CLI_OS = @() #OS = OSrearm
	$Global:LIC_BISF_CLI_OF = @() #OF = OFrearm
	$Global:LIC_BISF_CLI_AV = @() #AV = AntiVirusFullScan
	$Global:LIC_BISF_CLI_AV_VIE = @() #AV_VIE = VIETool - Symantec only
	$Global:LIC_BISF_CLI_PD = @() #PD = Citrix Personal vDisk
	$Global:LIC_BISF_CLI_PT = @() #PT = P2PVS
	$Global:LIC_BISF_CLI_CC = @() #CC = CCleaner
	$Global:LIC_BISF_CLI_PF = @() #PF = RstPerfCnt
	$Global:LIC_BISF_CLI_SB = @() #SB = Shutdown
	$Global:LIC_BISF_CLI_SR = @() #SR = SuppressPendingReboot
	$Global:LIC_BISF_CLI_VS = @() #VS = VerySilent
	$Global:LIC_BISF_CLI_FS = @() #FS = FS logix Delete Rules
	$Global:LIC_BISF_CLI_RS = @() #RS = Fs logix Rules Share
	$GLobal:LIC_BISF_CLI_SM = @() #SM = Delete All Users Start Menue
	$GLobal:LIC_BISF_CLI_V6 = @() #V6 = Disable IPV6
	$GLobal:LIC_BISF_CLI_SP = @() #SP = Sysprep
	$GLobal:LIC_BISF_CLI_DP = @() #DP = DelProf2
	$Global:LIC_BISF_CLI_ST = @() #ST = SessionType
	$Global:LIC_BISF_CLI_LS = @() #LS = BISF LogShare
	$Global:LIC_BISF_CLI_TB = @() #TB = Turbo.net Update
	$Global:LIC_BISF_CLI_OT = @() #OT = VMware OS Optimization Tool
	$Global:LIC_BISF_CLI_WB = @() #WB = Citrix Workspace Environment Agent
	$Global:LIC_BISF_CLI_RM = @() #RM = Remove XenApp Server from DSN and Farm
	$Global:LIC_BISF_CLI_AR = @() #AR = Remove app-V packages
	$Global:LIC_BISF_CLI_RA = @() #RA = RES Workspace Automation
	$Global:LIC_BISF_CLI_LSb = @()
	$Global:LIC_BISF_CLI_CTXOE = @() #CTXOE = Citrix System Optimizer Engine
}

Process {
	#check Powershell minimun version 3.0
	$PSverMin = "3"
	If (-not ($PSVersionTable.PSVersion.Major -ge $PSverMin)) {
		Write-Host "Powershell v$PSverMin or higher is required for BIS-F, detected version: $($PSVersionTable.PSVersion.Major)" -ForegroundColor white -BackgroundColor red
		Start-Sleep 999
		break
	}

	#load BISF Modules
	try {
		$Modules = @(Get-ChildItem -path $LIB_Folder -filter "*.psd1" -Force)
		ForEach ($module in $Modules) {
			$modulename = (Test-ModuleManifest $($Module.FullName) -Verbose:$false).Name
			$global:mainmodulename = $modulename
			$modulecompany = (Test-ModuleManifest $($Module.FullName) -Verbose:$false).CompanyName
			Write-Host "--- Importing Module $modulename ---" -ForegroundColor Green -BackgroundColor DarkGray
			Import-Module -Name $($Module.FullName) -Force
		}
	}
	catch {
		Throw "An error occured while loading modules. The error is: $_"
		Exit 1
	}

	# Initialize all variables used by BISF
	Initialize-BISFConfiguration


	#ENH 127 - Personalization is in Active State Override
	IF ($LIC_BISF_CLI_PersonalizationOverrideTimeOut -eq "") {
		[int]$MaximumExecutionMinutes = 60
		Write-BISFLog "Maximum execution time will internal override with the value of $MaximumExecutionTime minutes"
	}
 ELSE {
		[int]$MaximumExecutionMinutes = $LIC_BISF_CLI_PersonalizationOverrideTimeOut
		Write-BISFLog "Maximum execution time used the GPO value with $MaximumExecutionMinutes minutes"
	}
	$MaximumExecutionTime = (Get-Date).AddMinutes($MaximumExecutionMinutes)

	#running loop if Personalization State is not finished
	$a = 0

	DO {
		IF ($a -eq "99") { $a = 0 }
		# ENH 127 - Personalization is in Active State Override
		if ((Get-Date) -ge $MaximumExecutionTime) {
			Write-BISFLog -Msg "The operation has exceeded the maximum execution time of $MaximumExecutionMinutes Minutes." -Type W
			$PersState = $TaskStates[3]
			Write-BISFLog -Msg "Write PersState to registry location Path: $hklm_software_LIC_CTX_BISF_SCRIPTS -Name: LIC_BISF_PersState -Value: $PersState"
			Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_PersState" -value "$PersState" -Force
		}

		$PersState = (Get-ItemProperty "HKLM:\SOFTWARE\Login Consultants\BISF" -Name "LIC_BISF_PersState").LIC_BISF_PersState
		IF (($PersState -eq $($TaskStates[0])) -or ($PersState -eq $($TaskStates[3]))) {
			$a = 100
			Write-Progress -Activity "Personlization is in current ""$PersState"" state, go ahead the preparation task in 5 seconds" -PercentComplete $a -Status "Finish."
			Start-Sleep 5
			Write-Progress "Done" "Done" -completed
			break
		}
		ELSE {
			$a++
			Write-Progress -Activity "Personalization is in current ""$PersState"" state, waiting if finished..." -PercentComplete $a -Status "Please wait...$a %"

		}
		Start-Sleep -seconds 1
	} While ($a -ne 100)

	#Migrate Settings from older BISF versions
	Convert-BISFSettings

	# create RegHive if needed
	$BISFRegHive = Test-BISFRegHive -Verbose:$VerbosePreference


	# Set CLI Options in registry location
	#Set-BISFCLIinReg  ##<<< please do not active, currently buggy MS 10.08.2015

	#Load Global environment
	$psfolder = $LIB_Folder
	Invoke-BISFFolderScripts -Path "$psfolder" -Verbose:$VerbosePreference

	#Check pending reboot before continue
	$CheckPndReboot = Get-BISFPendingReboot
	IF (($CheckPndReboot -eq $true) -and (!($LIC_BISF_CLI_EX)) ) {
		IF (($LIC_BISF_CLI_SR -eq "NO") -or !($LIC_BISF_CLI_SR)) {
			$title = "Pending Reboot"
			$text = "A pending system reboot was detected, please reboot and run the script again !!!"
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
	Add-BISFFinishLine

	#Load custom scripts
	$psfolder = $SubCall_Folder + "Preparation\Custom"
	Invoke-BISFFolderScripts -Path "$psfolder" -Verbose:$VerbosePreference

	Add-BISFFinishLine

	#load Preparation Scripts
	$psfolder = $SubCall_Folder + "Preparation"
	Invoke-BISFFolderScripts -Path "$psfolder" -Verbose:$VerbosePreference

}

End {
	try {
		Write-BISFLog -Msg "- - - End Of Script - - - "
		#unload BISF Modules
		$Modules = @(Get-ChildItem -path $LIB_Folder -filter "*.psd1" -Force)
		ForEach ($module in $Modules) {
			$modulename = (Test-ModuleManifest $($Module.FullName)).Name
			$modulecompany = (Test-ModuleManifest $($Module.FullName)).CompanyName
			Write-Host "--- Removing Module $modulename ---" -ForegroundColor Green -BackgroundColor DarkGray
			Remove-Module -Name $modulename -Force -ErrorAction Stop
		}
	}
	catch {
		Throw "An error occured while unloading modules. The error is:`r`n$_"
		Exit 1
	}
	IF ($WPTEnabled -eq 1) { Stop-Transcript }
}