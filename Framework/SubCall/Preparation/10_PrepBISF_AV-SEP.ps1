<#
	.SYNOPSIS
		Prepare Symantec Endpoint Protection for Image Managemement
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

	  	History:
		26.09.2012 MS: Script created
		09.10.2012 MS: HostID-File only created if the $regHostID has an value -- IF ($regHostID -gt 0) {.... }
		18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		18.09.2013 MS: replace $PVsWriteCacheDisk to global environment variable $LIC_PVS_HostIDPath
		17.12.2013 MS: use smc stop to disable SMCService, is needed for V12 or higher, add [array]$search_path
		27.01.2014 MS: Set-Location $SEP_path
		28.01.2014 MS: $service_name = "cmd /c smc -stop"
		28.01.2014 MS: $regHostID = get-itemProperty -path $reg_SEP_string | % {$_.$ident}
		28.01.2014 MS: Change $ident ="HardwareID"
		14.02.2014 BR: Changed Function StopService
		05.03.2014 BR: revisited Script
		11.03.2014 MS: IF (Test-Path ("$SEP_path\smc.exe"))
		21.03.2014 MS: last code change before release to web
		01.04.2014 MS: change Console message
		06.08.2014 MS: change NetworkproviderOrder SnacNp and add Silentswitch -AVFullScan (YES|NO)
		11.08.2014 MS: remove Write-Host change to Write-BISFLog
		13.08.2014 MS: remove $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		17.08.2014 change line 44 to $SEP_path = "$ProgramFilesx86\Symantec\Symantec Endpoint Protection"
		17.09.2014 MS: Line 124: Applying Group Policies Fails After Symantec Endpoint Protection Client Installation from http://www.symantec.com/business/support/index?page=content&id=TECH200321
		09.02.2015 BR: added VIE Tool to improve scan performance on base image files.
		19.02.2015 MS: add progressBar to FullScan and VIETool
		20.02.2015 MS: get-LogContent from VIETool
		03.03.2015 MS: defined Variable $VIELog to set default logfile
		12.03.2015 MS: Fix syntax error on line 108
		20.04.2015 MS: Fix wrong variablename ($varCLIVIE) for CLImode line 107
		18.05.2015 MS: Bugfix 41 - VIETool is running a long time, seperated Log and ConsoleLog, deactive get-LogContent
		31.08.2015 MS: Bugfix 89 - symantec fixes the registry location for the SEP-Client to WOW6432Node, fix in line 48-50 and function deleteSEPData
		01.09.2015 MS: Bugfix 89 sucessfull tested
		01.10.2015 MS: rewritten script with standard .SYNOPSIS, central BISF function couldn't used for services, SEP Service must being stopped with smc.exe
		07.01.2016 MS: If No Image Management-Software would be detected, the Service Startup type would not changed to manual
		25.04.2016 BR: Review According https://support.symantec.com/en_US/article.HOWTO54706.html
		10.11.2016 MS: vietool.exe would not longer distributed by BIS-F, it must be installed from Customer
		06.03.2017 MS: Bugfix read Variable $varCLI = ...  and $varCLIVIE = ...
		29.07.2017 MS: Bugfix 187: Wrong search folders for the SEP vietool.exe
		31.07.2017 MS: typo Line 69 - search folders for the SEP vietool.exe
		15.10.2017 MS: VIETOOL - using custom searchfolder from ADMX if enabled
		24.11.2017 MS: Change Name in Log and Display from VIEtool.exe to $VIEProduct = "Symantec Virtual Image Exception (VIE) Tool"
		20.10.2018 MS: Bugfix 66: vietool.exe - custom searchpath not working correctly
		11.04.2019 MS: HF 87: Symantec Endpoint Protection 14.0 MP2 prevents graceful Citrix session logoff
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		03.10.2019 MS: ENH 51 - ADMX Extension: select AnitVirus full scan or custom Scan arguments
		11.10.2019 MS: fix typo in SearchProvOrder
		18.02.2020 JK: Fixed Log output spelling
		14.04.2023 TR: HF 371 - Support both 32 bit and 64 bit locations. Reduce usage of global variables in functions. Use approved verbs. Refactoring. Code cleanup.

	.LINK
		https://eucweb.com
#>

Begin {
	# define environment
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)

	####################################################################
	####### functions #####
	####################################################################
	function Get-SepPath
	{
		if(Test-Path -Path "C:\Program Files\Symantec\Symantec Endpoint Protection")
		{
			"C:\Program Files\Symantec\Symantec Endpoint Protection"
		}
		elseif (Test-Path -Path "C:\Program Files (x86)\Symantec\Symantec Endpoint Protection") {
			"C:\Program Files (x86)\Symantec\Symantec Endpoint Protection"
		}
		else {
			$null
		}
	}

	function Get-SepSmcExePath
	{
		$sepPath = Get-SepPath
		if($null -ne $sepPath)
		{
			"$sepPath\smc.exe"
		}
		else {
			$null
		}
	}

	function Get-SepDoScanExePath
	{
		$sepPath = Get-SepPath
		if($null -ne $sepPath)
		{
			"$sepPath\DoScan.exe"
		}
		else {
			$null
		}
	}

	function Get-SepRegPath
	{
		if(Test-Path -Path "HKLM:\SOFTWARE\$reg_SEP_string")
		{
			"HKLM:\SOFTWARE\$reg_SEP_string"
		}
		elseif (Test-Path -Path "HKLM:\WOW6432Node\$reg_SEP_string") {
			"HKLM:\WOW6432Node\$reg_SEP_string"
		}
		else
		{
			$null
		}		
	}

	function Test-SepIsInstalled
	{
		$regPath = Get-SepRegPath
		$regPathExists = ($null -ne $regPath)
		Write-Verbose "RegPathExists ('$regPath'): $regPathExists"
		$smcExe = Get-SepSmcExePath
		$smcExeExists = ($null -ne $smcExe) -and (Test-Path -Path $smcExe -PathType Leaf)
		Write-Verbose "smcExeExists ('$smcExe'): $smcExeExists"
		$regPathExists -and $smcExeExists
	}


	function Invoke-SepFullScan {
		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLI = $LIC_BISF_CLI_AV
		IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO Valuedata: $varCLI"
		}
		ELSE {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$AVScan = "YES"
		}

		If (($AVScan -eq "YES" ) -or ($varCLI -eq "YES")) {
			IF ($LIC_BISF_CLI_AV_VIE_CusScanArgsb -eq 1) {
				Write-BISFLog -Msg "Enable Custom Scan Arguments"
				$DoScanArguments = $LIC_BISF_CLI_AV_VIE_CusScanArgs
			}
			ELSE {
				$DoScanArguments = "/C /ScanDrive C"
			}

			Write-BISFLog -Msg "Running Scan with arguments: $DoScanArguments"
			Start-Process -FilePath "$(Get-SepDoScanExePath)" -ArgumentList $DoScanArguments -noNewWindow
			Show-BISFProgressBar -CheckProcess "DoScan" -ActivityText "$Product is scanning the system"
		}
		ELSE {
			Write-BISFLog -Msg "No Scan will be performed"
		}
	}
	<#
	TEST:
	$LIC_BISF_CLI_AV = "NO"
	$global:AVScan = "YES"
	$LIC_BISF_CLI_AV_VIE_CusScanArgsb = ""
	Invoke-SepFullScan
	#>

	function Test-SepIsX86
	{
		$sepPath = Get-SepPath
		if($sepPath -like "*x86*")
		{
			$true
		}
		else {
			$false
		}
	}

	function Get-VieToolExeName
	{
		if(Test-SepIsX86)
		{
			"vietool.exe"
		}
		else {
			"vietool64.exe"
		}
	}

	function Get-VieToolExeProcessName
	{
		if(Test-SepIsX86)
		{
			"vietool"
		}
		else {
			"vietool64"
		}
	}

	function Find-SepVieTool
	{
		param(
			[Parameter(Mandatory=$true)]
			[string[]]
			$SearchPaths
		)
		$vietoolExeFilter = Get-VieToolExeName		
		Write-BISFLog -Msg "Searching for $VIEProduct - $vietoolExeFilter"
		ForEach ($VIESearchFolder in $SearchPaths) 
		{			
			Write-BISFLog -Msg "Looking in $VIESearchFolder"
			$vieToolExe = Get-ChildItem -Path "$VIESearchFolder" -filter "$vietoolExeFilter" -ErrorAction SilentlyContinue | Foreach-Object { $_.FullName } | Select-Object -First 1			
			if ($null -ne $vieToolExe) {				
				Write-BISFLog -Msg "Product $VIEProduct installed : '$vieToolExe'" -ShowConsole -Color Cyan					
				return $vieToolExe
			}
		}
		#Vietool not found, return null
		return $null			
	}
	<#TEST
	#$VIESearchFolders = @("C:\Temp\SEP vietool")
	#Find-SepVieTool
	#>
	function Invoke-SepVieTool 
	{
		param(
			[Parameter(Mandatory=$true)]
			[string[]]
			$SearchPaths
		)
		$vieToolExe = Find-SepVieTool -SearchPaths $SearchPaths
		If ($null -ne $vieToolExe) {
			Write-BISFLog "Copy $vieToolExe to $VIEtmpFolder"
			Copy-Item "$vieToolExe" -Destination "$VIEtmpFolder" -Force | Out-Null
			$tempVietoolExe = "$VIEtmpFolder\$(Get-VieToolExeName)"

			Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
			$varCLIVIE = $LIC_BISF_CLI_AV_VIE
			IF (($varCLIVIE -eq "YES") -or ($varCLIVIE -eq "NO")) {
				Write-BISFLog -Msg "GPO Valuedata: $varCLIVIE"
			}
			ELSE {
				Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
				$MPVIE = "YES"
			}

			If (($MPVIE -eq "YES" ) -or ($varCLIVIE -eq "YES")) {
				Write-BISFLog -Msg "Running VIETool... please Wait"
				Start-Process -FilePath "$tempVietoolExe" -ArgumentList "c: --generate --log $VIELog" -RedirectStandardOutput "$VIEConsoleLog" -NoNewWindow				
				Show-BISFProgressBar -CheckProcess "$(Get-VieToolExeProcessName)" -ActivityText "$VIEProduct is flagging out the scanned files"
				Remove-Item -Path "$tempVietoolExe" -Force | Out-Null
				#Get-LogContent "$VIELog" # 18.05.2015 MS deactivate to see, VIETool is not running a long time
			}
			ELSE {
				Write-BISFLog -Msg "No VIE preparation performed"
			}
		}
		ELSE {
			Write-BISFLog -Msg "Product $VIEProduct is not installed, get it from the SEP iso and save it on your Image (Symantec KB TECH172218) and then configure the path in the BIS-F ADMX" -Type W -SubMsg
		}
	}
	<#TEST
	$global:logFile = "c:\temp\bisf.log"
	Import-Module ".\Framework\SubCall\Global\BISF.psd1"
	$LIC_BISF_CLI_AV_VIE = "YES"
	$MPVIE = "YES"
	Invoke-SepVieTool -SearchPath @("C:\Temp\SEP Vietool")
	#>

	function Remove-SepData {
		# Delete specified Data
		foreach ($path in $search_path) {
			if (Test-Path -Path $path) {
				Write-BISFLog -Msg "Search path $path"
				foreach ($file in $search_file) {
					Write-BISFLog -Msg "Search for file  $file"
					Get-ChildItem -Path $path -filter $file -ErrorAction SilentlyContinue | Foreach-Object ($_) { 
						Write-BISFLog -Msg "Remove file: '$($_.FullName)'"
						Remove-Item $_.FullName
					}
				}
			}
		}

		foreach ($path in $search_path_recursive) {
			if (Test-Path -Path $path) {
				Write-BISFLog -Msg "Search path $path"
				foreach ($file in $search_file) {
					Write-BISFLog -Msg "Search for file  $file"
					Get-ChildItem -Path $path -filter $file -Recurse -ErrorAction SilentlyContinue | Foreach-Object ($_) { 
						Write-BISFLog -Msg "Remove file: '$($_.FullName)'"
						Remove-Item $_.FullName -ErrorAction SilentlyContinue }
				}
			}
		}

		foreach ($RegHive in ("HKLM:\SOFTWARE", "HKLM:\SOFTWARE\Wow6432Node")) {
			foreach ($key in $reg_SEP_name) {
				if (Test-BISFRegistryValue -Path $RegHive\$reg_sep_string -Value $key) {
					Write-BISFLog -Msg "delete specified registry items in $RegHive\$reg_sep_string..."
					Write-BISFLog -Msg "delete $key"
					Try {
						Remove-ItemProperty -Path "$RegHive\$reg_sep_string" -Name $key -ErrorAction Stop
					}
					catch {
						Write-Bisflog -type "E" -Msg "Cannot Delete Registry Key $($Key)"
						Show-MessageBox -Title "Error" -Msg "Cannot Delete Registry Key $($Key)" -Critical
					}
				}
			}
		}
	}

	function Rename-SepFiles {
		#HF87: Symantec Endpoint Protection 14.0 MP2 prevents graceful Citrix session logoff

		if (Test-SepIsInstalled) {
			$sepPath = Get-SepPath
			Write-BISFLog -Msg "Search path '$sepPath'"
			foreach ($file in $rename_file) {
				Write-BISFLog -Msg "Search for file $file and rename it to $file.old"
				Get-ChildItem -Path $sepPath -filter $file -recurse -ErrorAction SilentlyContinue | Foreach-Object { Rename-Item -Path "$($_.fullname)" -NewName "$($_.fullname).old" }
			}
		}
		else {
			Write-BISFLog -Msg "Sep is not installed."
		}
	}

	function Stop-SepService {
		# Stop SEP
		Write-BISFLog -Msg "Preparing $product for Imaging" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "Stop $Product Service"
		& "$(Get-SepSmcExePath)" "-stop"
		$ServiceName = "SepMasterService"
		Test-BISFServiceState -ServiceName $ServiceName -Status "Stopped" | Out-Null
		IF ($ImageSW -eq $false) {
			write-BISFlog -Msg "No Image Management Software detected, Service $ServiceName would not be changed to StartupType $StartType" -Type W
		}
		ELSE {
			Write-BISFLog -Msg "Set SepMasterService Starttype to Manual"
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SepMasterService"  -Name "Start" -Value 3
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#product specified
	$Product = "Symantec Enterprise Protection"
	$reg_SEP_string = "Symantec\Symantec Endpoint Protection\SMC\SYLINK\SyLink"		
	$VIEProduct = "Symantec Virtual Image Exception (VIE) Tool"
	$VIELog = "$env:WinDir\Logs\VIEtool.log"
	$VIEtmpFolder = "C:\Windows\temp"
	$VIEConsoleLog = "$env:WinDir\Logs\VIEtoolConsole.log"	

	IF ($LIC_BISF_CLI_AV_VIE_SF -eq "1") {
		$VIESearchFolders = $LIC_BISF_CLI_AV_VIE_SF_CUS
	}
	ELSE {
		$VIESearchFolders = @("C:\Windows", "C:\Windows\system32", "$env:ProgramFiles", "$(${env:Programfiles(x86)})", "${env:Programfiles(x86)}\Symantec","${env:Programfiles}\Symantec" , "$(Get-SepPath)")
	}

	[array]$reg_SEP_name = "HardwareID"
	[array]$reg_SEP_name += "ForceHardwareKey"
	[array]$reg_SEP_name += "HostGUID"
	[array]$reg_SEP_name += "HostName"

	[array]$search_path = "C:\"
	[array]$search_path += "C:\Program Files\Common Files\Symantec Shared\HWID"
	#[array]$search_path += "C:\Documents and Settings\All Users\Application Data\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Config"
	#[array]$search_path += "C:\Documents and Settings\All Users\Application Data\Symantec\Symantec Endpoint Protection\PersistedData"
	[array]$search_path += "C:\ProgramData\Symantec\Symantec Endpoint Protection\PersistedData"
	[array]$search_path += "C:\Users\All Users\Symantec\Symantec Endpoint Protection\PersistedData"
	[array]$search_path	+= "C:\Windows\Temp"

	[array]$search_path_recursive = "C:\Users"
	#[array]$search_path_recursive += "C:\Documents and Settings"

	[array]$search_file = "sephwid.xml"
	[array]$search_file += "communicator.dat"

	[array]$rename_file = "sqsvc.dll"
	[array]$rename_file += "sqscr.dll"
	[array]$rename_file += "symerr.exe"

}

Process {
	#### Main Program

	If (Test-SepIsInstalled) {
		Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
		Invoke-SepFullScan
		Invoke-SepVieTool -SearchPaths $VIESearchFolders
		Rename-SepFiles
		Stop-SepService
		Remove-SepData
		Set-BISFNetworkProviderOrder -SearchProvOrder "SnacNp"
		Write-BISFLog -Msg "Write GpNetworkStartTimeoutPolicyValue to registry from http://www.symantec.com/business/support/index?page=content&id=TECH200321"
		New-ItemProperty -Path "$hklm_sw\Microsoft\Windows NT\CurrentVersion\Winlogon"-Name "GpNetworkStartTimeoutPolicyValue" -PropertyType DWORD -value 60 -ErrorAction SilentlyContinue | Out-Null
	}
	ELSE {
		Write-BISFLog -msg "Product $Product is not installed"
	}
}

End {
	Add-BISFFinishLine
}
