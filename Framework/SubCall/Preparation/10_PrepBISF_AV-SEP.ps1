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
	$Product = "Symantec Enterprise Protection"
	$reg_SEP_string = "Symantec\Symantec Endpoint Protection\SMC\SYLINK\SyLink"
	$HKLM_reg_SEP_string = "$HKLM_sw_x86\$reg_SEP_string"
	$SEP_path = "$ProgramFilesx86\Symantec\Symantec Endpoint Protection"
	$ident = "HardwareID"
	$VIEApp = "vietool.exe"
	$VIEProduct = "Symantec Virtual Image Exception (VIE) Tool"
	$VIELog = "$env:WinDir\Logs\VIEtool.log"
	$VIEtmpFolder = "C:\Windows\temp"
	$VIEConsoleLog = "$env:WinDir\Logs\VIEtoolConsole.log"
	$found = $false

	IF ($LIC_BISF_CLI_AV_VIE_SF -eq "1") {
		$VIESearchFolders = $LIC_BISF_CLI_AV_VIE_SF_CUS
	}
	ELSE {
		$VIESearchFolders = @("C:\Windows", "C:\Windows\system32", "$env:ProgramFiles", "$(${env:Programfiles(x86)})", "$SEP_path")
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
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$MPFullScan = "YES"
		}

		If (($MPFullScan -eq "YES" ) -or ($varCLI -eq "YES")) {
			Write-BISFLog -Msg "Running Fullscan... please Wait"
			Start-Process -FilePath "$SEP_path\DoScan.exe" -ArgumentList "/C /ScanDrive C" -noNewWindow
			Show-BISFProgressBar -CheckProcess "DoScan" -ActivityText "$Product is scanning the system"
		}
		ELSE {
			Write-BISFLog -Msg "No Full Scan would be performed"
		}
	}

	function RunVIE {
		Write-BISFLog -Msg "Searching for $VIEProduct - $VIEApp "
		ForEach ($VIESearchFolder in $VIESearchFolders) {
			If ($found -eq $false) {
				Write-BISFLog -Msg "Looking in $VIESearchFolder"
				$VIEExists = Get-ChildItem -Path "$VIESearchFolder" -filter "$VIEApp" -ErrorAction SilentlyContinue | % { $_.FullName }
			}
			IF (($VIEExists -ne $null) -and ($found -ne $true)) {
				$VIEappDestination = $VIEExists
				Write-BISFLog -Msg "Product $VIEProduct installed" -ShowConsole -Color Cyan
				$found = $true
				Write-BISFLog "Copy $VIEappDestination to $VIEtmpFolder"
				Copy-Item "$VIEappDestination" -Destination "$VIEtmpFolder" -Force | Out-Null
				$VIEappDestination = "$VIEtmpFolder\$VIEApp"

			}
		}

		If ($found -eq $true) {

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
				Start-Process -FilePath "$VIEappDestination" -ArgumentList "c: --generate --log $VIELog" -RedirectStandardOutput "$VIEConsoleLog" -NoNewWindow
				Show-BISFProgressBar -CheckProcess "VIETool" -ActivityText "$VIEProduct is flagging out the scanned files"
				Remove-Item -Path "$VIEappDestination" -Force | Out-Null
				#get-LogContent "$VIELog" # 18.05.2015 MS deactivate to see, VIETool is not running a long time
			}
			ELSE {
				Write-BISFLog -Msg "No VIE preparation performed"
			}
		}
		ELSE {
			Write-BISFLog -Msg "Product $VIEProduct not installed, get it from the SEP iso and save them on your Image (Symantec KB TECH172218) and configure the path in the BIS-F ADMX" -Type W -SubMsg
		}
	}

	function deleteSEPData {
		# Delete specified Data
		foreach ($path in $search_path) {
			if (Test-Path -Path $path) {
				Write-BISFLog -Msg "Search path $path"
				foreach ($file in $search_file) {
					Write-BISFLog -Msg "Search for file  $file"
					Get-ChildItem -Path $path -filter $file -ErrorAction SilentlyContinue | foreach ($_) { Remove-Item $_.fullname }
				}
			}
		}

		foreach ($path in $search_path_recursive) {
			if (Test-Path -Path $path) {
				Write-BISFLog -Msg "Search path $path"
				foreach ($file in $search_file) {
					Write-BISFLog -Msg "Search for file  $file"
					Get-ChildItem -Path $path -filter $file -Recurse -ErrorAction SilentlyContinue | foreach ($_) { Remove-Item $_.fullname -ErrorAction SilentlyContinue }
				}
			}
		}

		foreach ($RegHive in ("HKLM:\SOFTWARE", "HKLM:\SOFTWARE\Wow6432Node")) {
			foreach ($key in $reg_SEP_name) {
				if (Test-BISFRegistryValue -Path $RegHive\$reg_sep_string -Value $key) {
					Write-BISFLog -Msg "delete specified registry items in $HKLM_reg_SEP_string..."
					Write-BISFLog -Msg "delete $key"
					Try {
						Remove-ItemProperty -Path $HKLM_reg_SEP_string -Name $key -ErrorAction Stop
					}
					catch {
						Write-Bisflog -type "E" -Msg "Cannot Delete Registry Key $($Key)"
						Show-MessageBox -Title "Error" -Msg "Cannot Delete Registry Key $($Key)" -Critical
					}
				}
			}
		}
	}

	function Rename-SEPFiles {
		#HF87: Symantec Endpoint Protection 14.0 MP2 prevents graceful Citrix session logoff

		if (Test-Path -Path $SEP_path) {
			Write-BISFLog -Msg "Search path $SEP_path"
			foreach ($file in $rename_file) {
				Write-BISFLog -Msg "Search for file $file and rename it to $file.old"
				Get-ChildItem -Path $SEP_path -filter $file -recurse -ErrorAction SilentlyContinue | % { Rename-Item -Path "$($_.fullname)" -NewName "$($_.fullname).old" }
			}
		}
	}

	function Configure-SepService {
		# Stop SEP
		Write-BISFLog -Msg "Preparing $product for Imaging" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "Stop $Product Service"
		& $ProgramFilesx86'\Symantec\Symantec Endpoint Protection\smc.exe' "-stop"
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

	#### Main Program

	If (Test-Path ("$SEP_path\smc.exe") -PathType Leaf) {
		Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
		RunFullScan
		RunVIE
		Rename-SEPFiles
		Configure-SepService
		deleteSEPData
		Set-BISFNetworkProviderOrder -SaerchProvOrder "SnacNp"
		Write-BISFLog -Msg "Write GpNetworkStartTimeoutPolicyValue to registry from http://www.symantec.com/business/support/index?page=content&id=TECH200321"
		New-ItemProperty -Path "$hklm_sw\Microsoft\Windows NT\CurrentVersion\Winlogon"-Name "GpNetworkStartTimeoutPolicyValue" -PropertyType DWORD -value 60 -ErrorAction SilentlyContinue | Out-Null
	}
	ELSE {
		Write-BISFLog -msg "Product $Product not installed"
	}
}

End {
	Add-BISFFinishLine
}