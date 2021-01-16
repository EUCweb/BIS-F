<#
	.SYNOPSIS
		Initialize PVSWriteCacheDisk
	.DESCRIPTION
		Prerequisites:
		Configure the PVS WriteCacheDisk Driveletter in the ADMX

		Example: If you would like to set your PVSWriteCache Disk Label to Drive D:
		Name: PVSWriteCacheDisk
		Value: D:
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company:  EUCWeb.com

		History:
	  	24.09.2012 MS: Script created
		09.10.2012 MS: Set uniqueid disk ID=<uniqueID>
		10.10.2012 MS: Reboot if sucessfull format the PVSWriteCacheDisk only
		25.06.2013 MS: Changed location for temporary Diskpartfile to %TEMP%
		26.08.2013 MS: Read WriteCacheDrive from vDisk inside registry PVSAgent and check it with the hole environment to set the uniqueID of the disk
		18.09.2013 MS: Replaced $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		01.10.2013 MS: Added function GetRefSrv - Get Reference Server Hostname in registry to detect it and skip reboot
		01.10.2013 MS: Fixed syntax error
		05.06.2014 BR: Added WriteCache Option Check for PVS Device RAM with Overflow to Device HardDisk
		05.06.2014 BR: Use Write-BISFLog function for Logging
		30.06.2014 MS: Changed to $LOGfile = Set-Logfile
		13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script on1ly
		13.08.2014 MS: Check if $returnCheckPVSSysVariable exists, then set uniqueID for persitend drive
		13.08.2014 MS. Removed hardcoded Logpath D:\PVSLogs, change it to $LIC_PVS_LogPath
		14.08.2014 MS: Check PVSWriteCache environment variable to format Disk. Check SkipReboot, Remove Get-LogData funcrion
		15.08.2014 MS: Check if Citrix PVS software installed, before check and format the WriteCacheDisk
		19.08.2014 MS: Prevent reboot loop, check log file folder if exist and reboot
		20.08.2014 MS: Added line 104 and 114; get-LogContent -GetLogFile "$DiskpartFile"
		20.08.2014 MS: Removed line 142 to 146; folder could not be created if uniqueID changed before
		20.08.2014 MS: Line 115 and 134; "select disk 0" ... to define the right driveletter to prevent reboot loops
		31.10.2014 MB: Renamed function call; ChangeNetworkProviderOrder -> Set-NetworkProviderOrder
		31.10.2014 MB: Renamed variable; returnCheckPVSSysVariable -> returnTestPVSEnvVariable
		15.04.2015 MS: Added advanced commands to diskpartfile to bring the disk online if the WriteCacheDisk is not formatted
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		12.03.2017 MS: using $LIC_BISF_CLI_WCD insted of PVSWriteCacheDisk System Variable, it can be configured via ADMX now
		15.08.2017 MS: If Citrix AppLayering is installed, skip reboot
		14.09.2017 MS: after WriteCacheDisk would formatted, wait after reboot
		22.09.2017 MS: change reboot command to use shutdown /r instead of restart-computer
		25.08.2019 MS: ENH 128 - Disable any command if WriteCacheDisk is set to NONE
		25.08.2019 MS: HF 21 - endless Reboot with wrong count of Partitons
		03.10.2019 MS: ENH 126 - MCSIO with persistent drive
		05.10.2019 MS: HF 30 - Format CacheDisk on shared Images only, to prevent reboot loop on priavte images
		04.01.2020 MS: HF 170 - using wrong $variable -> $LIC_BISF_POL_MCSCfg insted of $LIC_BISF_CLI_MCSCfg
		07.01.2020 MS: HF 177 - typo in DiskMode
		15.01.2020 MS: HF 188 - Async WriteCacheType not detected for shared Images and ending up in a reboot loop
		27.01.2020 MS: HF 194 - format WriteCacheDisk didn't run if "skip PVS master image creation" enabled
		18.02.2020 JK: Fixed Log output spelling
		17.02.2020 MS: HF 206 - Reboot loop if central logshare is configured
		23.05.2020 MS: HF 232 - CacheDisk not formatted
		14.12.2020 MS: HF 297 - MCS CacheDisk is not right formatted
		25.12.2020 MS: HF 302 - manually configuration of the Cache Disk ID in GPO will override BIS-F automatic detection of the $CacheDiskID
		08.01.2021 MS: HF 302 - using $DiskIdentifier instead DiskID, DiskID is for another Global variable
		16.01.2021 MS: HF 302 - MCS: Test Volume DriveLetter before Proceed


	.LINK
		https://eucweb.com
#>

Begin {
	# define environment
	$SysDrive = gc env:systemdrive
	$TEMP = gc env:temp
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	$hklm_bnistack_pvsagent = "$hklm_system\CurrentControlSet\services\bnistack\PvsAgent"
	# $reg_value_WriteCacheDrive = "WriteCacheDrive" # 23.05.2020 MS: disabled, not used anymore !
	$DiskLabel = "CacheDisk"
	$CacheCheckFile = "$PVSDiskDrive\$computer.txt"
	$DiskpartFile = "$TEMP\$computer-DiskpartFile.txt"
	$PVSPersonality = "$SysDrive\Personality.ini"
	$SkipReboot = $false
}

Process {
	# Get uniqueID from MasterImage
	function Get-UniqueIDreg {
		#read UniqueID from registry
		Write-BISFLog -Msg "Reading uniqueID from registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
		$uniqueid_REG = Get-ItemProperty -path $hklm_software_LIC_CTX_BISF_SCRIPTS | % { $_.LIC_BISF_UniqueID_Disk }
		Write-BISFLog -Msg "Read uniqueID $uniqueid_REG"
		return $uniqueid_REG
	}

	function Test-OpticalDrive {
		<#
		.SYNOPSIS
		Test optical drive availablity

		.DESCRIPTION
		Test optical drive availablity and
		set the same driveletter as on the catptured masterimage
		Driveletter is stored in registry in variable LIC_BISF_OptDrive

		.EXAMPLE
		Test-OpticalDrive

		.NOTES
		Author: Matthias Schlimm
	  	Company:  EUCWeb.com

		History:
			04.03.2014 BR: Added function CheckCDRom
			13.03.2014 MS: Changed optical Driveletter a variable $OptDrive="B:"
			21.03.2014 MS: Read optical driveletter from registry that would be set with Base-Image during PVS preperation
			14.12.2020 JS: HF 303 - Updated CheckCDRom function to allow for builds where CDROM drive letter has already been removed.
			25.12.2020 MS: rename function to Test-OpticalDrive
		#>

		$CDrom = Get-CimInstance -ClassName Win32_volume -Filter "DriveType = 5"
		If ((!([String]::IsNullOrEmpty($CDrom.DriveLetter))) -and ($CDrom.DriveLetter -ne "$LIC_BISF_OptDrive")) {
			Set-CimInstance -InputObject $CDRom -Arguments @{DriveLetter = "$LIC_BISF_OptDrive" }
			Write-BISFLog -Msg "Set optical drive letter to $LIC_BISF_OptDrive"
		}
	}

	function Test-WriteableCacheDisk {
		$ErrorActionPreference = "Stop"
		$val = $true
		try {
			IF (!(Test-path $CacheCheckFile)) { new-item $CacheCheckFile }
		}

		catch {
			$val = $false
		}

		finally {
			IF (Test-path $CacheCheckFile) { remove-item $CacheCheckFile -Force }
		}
		$ErrorActionPreference = "Continue"
		return $val
	}

	# Check WriteCacheDrive Driveletter and Check UniqueID
	function Test-PVSCacheDisk {
		$CacheDiskID = "0" # for PVS it can be set hardcoded, but can be overwrite with GPO PVS
		# test checkfile on CacheDisk
		$TestCache = Test-WriteableCacheDisk
		if ($LIC_BISF_CLI_PVSCacheDiskIDb -eq "YES") {
			#HF 302
			$CacheDiskID = $LIC_BISF_CLI_PVSCacheDiskID
			Write-BISFLog -Msg "Cache Disk ID is manually configured through PVS GPO: $CacheDiskID" -ShowConsole -Color DarkCyan -SubMSg
		}
		if ([String]::IsNullOrEmpty($CacheDiskID)) {
			Write-BISFLog -Msg "Cache Disk ID can't retrieved from BIS-F, skipping Cache Disk configuration. Configure it manually with the PVS GPO." -ShowConsole -Color Yellow -SubMSg -Type W
		}
		else {
			Write-BISFLog -Msg "Using Cache Disk ID: $CacheDiskID" -ShowConsole -Color DarkCyan -SubMSg
			if ($TestCache -eq $false) {
				Write-BISFLog -Msg "Cache Disk partition is NOT properly configured" -Type W
				$WriteCacheType = Get-BISFPVSWriteCacheType
				if (($WriteCacheType -eq 4) -or ($WriteCacheType -eq 9) -or ($WriteCacheType -eq 12)) {
					# 4:Cache on Device Hard Disk // 9:Cache in Device RAM with Overflow on Hard Disk // 12:Cache in Device RAM with Overflow on Hard Disk async
					Write-BISFLog -Msg "vDisk is set to Cache on Device Hard Drive Mode"
					#grab the numbers of Partitions from the BIS-F ADMX
					Write-BISFLog -Msg "Number of Partitions from ADMX: $LIC_BISF_CLI_NumberOfPartitions"
					$SystemPartitions = (Get-CimInstance -ClassName Win32_Volume -filter "DriveType=3" | measure).count
					Write-BISFLog -Msg "Number of Partitions on current System: $SystemPartitions"
					If ($SystemPartitions -ne $LIC_BISF_CLI_NumberOfPartitions) {
						# CacheDisk not Formatted
						# Construct Diskpart File to Format CacheDisk

						Write-BISFLog -Msg "CacheDisk partition is not formatted"
						If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
						"select disk $CacheDiskID" | Out-File -filepath $DiskpartFile -encoding Default
						"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
						"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
						"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
						"create partition primary" | Out-File -filepath $DiskpartFile -encoding Default -append
						"assign letter $PVSDiskDrive" | Out-File -filepath $DiskpartFile -encoding Default -append
						"Format FS=NTFS LABEL=$DiskLabel QUICK" | Out-File -filepath $DiskpartFile -encoding Default -append
						Get-BISFLogContent -GetLogFile "$DiskpartFile"
						Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\diskpart.exe" -Args "/s $DiskpartFile" -ActText "Running Diskpart" | Out-Null
						Write-BISFLog -Msg "Cache Disk partition is now formatted and the drive letter $PVSDiskDrive assigned"

						# Get WriteCache Volume and Restore Unique ID
						If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
						"select disk $CacheDiskID" | Out-File -filepath $DiskpartFile -encoding Default
						"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
						Get-BISFLogContent -GetLogFile "$DiskpartFile"
						Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\diskpart.exe" -Args "/s $DiskpartFile" -ActText "Running Diskpart" | Out-Null
						Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
					}
					else {
						# CacheDisk Formatted, but No or Wrong Drive Letter Assigned
						Write-BISFLog -Msg "Cache Disk is formatted, but no drive letter or the wrong drive letter is assigned"  -Type W -SubMsg
						Write-BISFLog -Msg "Fixing drive letter assignemnt on Cache Disk"
						$WriteCache = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 3 and BootVolume = False"
						Set-CimInstance -InputObject $WriteCache  -Arguments @{DriveLetter = "$PVSDiskDrive" }
						If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
						"select disk $CacheDiskID" | Out-File -filepath $DiskpartFile -encoding Default
						"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
						"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
						"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
						"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
						Get-BISFLogContent -GetLogFile "$DiskpartFile"
						Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\diskpart.exe" -Args "/s $DiskpartFile" -ActText "Running Diskpart" | Out-Null
						Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
					}
				}
				else {
					Write-BISFLog -Msg "vDisk is not in Read Only Mode, skipping Cache Disk configuration."
					$SkipReboot = $true
				}

				IF (!($SkipReboot -eq $true)) {
					Write-BISFLog -Msg "Wait 60 seconds before system restart" -Type W
					Write-BISFLog -Msg "Reboot needed for config changes"
					Start-Process "$($env:windir)\system32\shutdown.exe" -ArgumentList "/r /t 60 /d p:2:4 /c ""BIS-F prepare Cache Disk - reboot in 60 seconds.."" " -Wait
					Start-Sleep 120
				}
				ELSE {
					Write-BISFLog -Msg "Skip Reboot is set to $SkipReboot"
				}
			}
			else {
				Write-BISFLog -Msg "Cache Disk partition is properly configured"
			}
		}
	}

	function Test-MCSIOCacheDisk {
		$CacheDiskID = $DiskIdentifier[1]
		# test checkfile on CacheDisk
		$TestCache = Test-WriteableCacheDisk
		if ($LIC_BISF_CLI_MCSCacheDiskIDb -eq "YES") {
			#HF 302
			$CacheDiskID = $LIC_BISF_CLI_MCSCacheDiskID
			Write-BISFLog -Msg "Cache Disk ID is manually configured through MCS GPO: $CacheDiskID" -ShowConsole -Color DarkCyan -SubMSg
		}
		if ([String]::IsNullOrEmpty($CacheDiskID)) {
			Write-BISFLog -Msg "Cache Disk ID can't retrieved from BIS-F, skipping Cache Disk configuration. Configure it manually with the MCS GPO." -ShowConsole -Color Yellow -SubMSg -Type W
		}
		else {
			Write-BISFLog -Msg "Using Cache Disk ID: $CacheDiskID" -ShowConsole -Color DarkCyan -SubMSg
			if ($TestCache -eq $false) {
				Write-BISFLog -Msg "Cache Disk partition is NOT properly configured" -Type W
				#grab the numbers of Partitions from the BIS-F ADMX
				Write-BISFLog -Msg "Number of Partitions from ADMX: $LIC_BISF_CLI_MCSIONumberOfPartitions"
				$SystemPartitions = (Get-CimInstance -ClassName Win32_volume).count
				Write-BISFLog -Msg "Number of Partitions on current System: $SystemPartitions"
				If ($SystemPartitions -eq $LIC_BISF_CLI_MCSIONumberOfPartitions) {
					# WriteCache Disk not Formatted
					# Construct Diskpart File to Format Disk

					Write-BISFLog -Msg "Cache Disk partition is not formatted"
					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					"select disk $CacheDiskID" | Out-File -filepath $DiskpartFile -encoding Default
					"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"create partition primary" | Out-File -filepath $DiskpartFile -encoding Default -append
					"assign letter $PVSDiskDrive" | Out-File -filepath $DiskpartFile -encoding Default -append
					"Format FS=NTFS LABEL=$DiskLabel QUICK" | Out-File -filepath $DiskpartFile -encoding Default -append
					Get-BISFLogContent -GetLogFile "$DiskpartFile"
					Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\diskpart.exe" -Args "/s $DiskpartFile" -ActText "Running Diskpart" | Out-Null
					Write-BISFLog -Msg "Cache Disk partition is now formatted and the drive letter $PVSDiskDrive assigned"

					##16.01.2021 HF 302: Test if the correct DriveLetter is assigned before proceeed
					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					"select disk $CacheDiskID" | Out-File -filepath $DiskpartFile -encoding Default
					"detail disk" | Out-File -filepath $DiskpartFile -encoding Default -append
					Get-BISFLogContent -GetLogFile "$DiskpartFile"
					$volumedata = diskpart.exe /S $DiskpartFile  | Where-Object { $_ -match 'Volume (\d+)\s+([a-z])\s+' }
					$volumedata = $volumedata | ForEach-Object {
						New-Object -Type PSObject -Property @{
							'DriveLetter' = $matches[2]
							'VolumeNumber' = [int]$matches[1]
						}
					}

					$VolumeDriveletter = $volumedata.DriveLetter + ":"
					$VolumeNumber = $volumedata.VolumeNumber
					Write-BISFLog -Msg "Cache Disk ID $CacheDiskID has DrivLetter $VolumeDriveletter assigned / Volume $VolumeNumber"
					IF ($VolumeDriveletter -ne $PVSDiskDrive) {
						Write-BISFLog -Msg "VolumeDriveLetter $VolumeDriveletter must be changed to $PVSDiskDrive" -Type W
						If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
						"select volume $VolumeNumber" | Out-File -filepath $DiskpartFile -encoding Default
						"assign letter $PVSDiskDrive" | Out-File -filepath $DiskpartFile -encoding Default -append
						Get-BISFLogContent -GetLogFile "$DiskpartFile"
						Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\diskpart.exe" -Args "/s $DiskpartFile" -ActText "Running Diskpart" | Out-Null
					}
					else {
						Write-BISFLog -Msg "VolumeDriveLetter $VolumeDriveletter is equal to your assigned configuration $PVSDiskDrive"
					}



					if (!([String]::IsNullOrEmpty($uniqueid_REG))) {
						# Get Cache Disk Volume and Restore Unique ID
						If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
						"select disk $CacheDiskID" | Out-File -filepath $DiskpartFile -encoding Default
						"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
						Get-BISFLogContent -GetLogFile "$DiskpartFile"
						Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\diskpart.exe" -Args "/s $DiskpartFile" -ActText "Running Diskpart" | Out-Null
						Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
					}
				}
				else {
					# WriteCache Formatted, but No or Wrong Drive Letter Assigned
					Write-BISFLog -Msg "Cache Disk is formatted, but no drive letter or the wrong drive letter is assigned"  -Type W -SubMsg

					if ([String]::IsNullOrEmpty($uniqueid_REG)) {
						Write-BISFLog -Msg "Fixing drive letter assignemnt on Cache Disk"
						$WriteCache = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 3 and BootVolume = False"
						Set-CimInstance -InputObject $WriteCache -Arguments @{DriveLetter = "$PVSDiskDrive" }
					}


					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					"select disk $CacheDiskID" | Out-File -filepath $DiskpartFile -encoding Default
					"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					if (!([String]::IsNullOrEmpty($uniqueid_REG))) {
						"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
						Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
					}
					Get-BISFLogContent-GetLogFile "$DiskpartFile"
					Start-BISFProcWithProgBar -ProcPath "$env:SystemRoot\system32\diskpart.exe" -Args "/s $DiskpartFile" -ActText "Running Diskpart" | Out-Null

				}

				IF (!($SkipReboot -eq $true)) {
					Write-BISFLog -Msg "Wait 60 seconds before system restart" -Type W
					Write-BISFLog -Msg "Reboot needed for config changes"
					Start-Process "$($env:windir)\system32\shutdown.exe" -ArgumentList "/r /t 60 /d p:2:4 /c ""BIS-F prepare Cache Disk - reboot in 60 seconds.."" " -Wait
					Start-Sleep 120
				}
				ELSE {
					Write-BISFLog -Msg "Skip Reboot is set to $SkipReboot"
				}
			}
			else {
				Write-BISFLog -Msg "Cache Disk partition is properly configured"
			}
		}
	}


	####################################################################

	###################################################################
	# Get Reference Server Hostname in registry to detect it and skip reboot
	function Get-RefSrv {
		IF ($CTXAppLayeringSW -eq $true) {
			$SkipReboot = $true
			Write-BISFLog -Msg "Citrix AppLayering is installed - set Skip Reboot = $SkipReboot"
		}
		ELSE {
			Write-BISFLog -Msg "Reading reference server hostname from registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
			$RefSrv_Hostname_REG = Get-ItemProperty -path $hklm_software_LIC_CTX_BISF_SCRIPTS | % { $_.LIC_BISF_RefSrv_Hostname }
			IF ($RefSrv_Hostname_REG -eq $computer) { $SkipReboot = $true }
			Write-BISFLog -Msg "Reference server hostname [$RefSrv_Hostname_REG] / hostname from this machine [$computer] - set Skip Reboot = $SkipReboot "
		}
		return $SkipReboot
	}
	####################################################################

	####################################################################
	$SkipReboot = Get-RefSrv
	Test-OpticalDrive
	$DiskMode = Get-BISFDiskMode
	IF ( ($DiskMode -match "ReadOnly*") -or ($DiskMode -match "VDAShared*") ) {
		Write-BISFLog -Msg "Cache Disk will be configured now for Disk Mode $DiskMode"
		IF ($LIC_BISF_CLI_PVSCfg -eq "YES") {
			IF (!($null -eq $LIC_BISF_CLI_WCD) -or (!($LIC_BISF_CLI_WCD -eq "NONE")) ) {
				IF ($returnTestPVSSoftware -eq $true) {
					$uniqueid_REG = Get-UniqueIDreg
					Test-PVSCacheDisk
				}
				ELSE {
					Write-BISFLog -Msg "PVS Cache Disk not checked or formatted, Citrix Provisioning Services software is not installed on this system!" -Type W
				}
			}
			ELSE {
				Write-BISFLog -Msg "PVS Cache Disk will NOT be configured or is set to 'NONE', skipping configuration"
			}
		}
		else {
			Write-BISFLog -Msg "PVS Cache Disk Configuration are not set in GPO"
		}

		IF ($LIC_BISF_CLI_MCSCfg -eq "YES") {
			IF (!($null -eq $LIC_BISF_CLI_MCSIODriveLetter) -or (!($LIC_BISF_CLI_MCSIODriveLetter -eq "NONE")) ) {
				IF ($MCSIO -eq $true) {
					$uniqueid_REG = Get-UniqueIDreg
					Test-MCSIOCacheDisk
				}
				ELSE {
					Write-BISFLog -Msg "MCSIO Cache Disk can't be used on this system!" -Type W
				}
			}
			ELSE {
				Write-BISFLog -Msg "MCSIO Cache Disk is not configured or is set to 'NONE', skipping configuration"
			}
		}
		else {
			Write-BISFLog -Msg "MCSIO Cache Disk Configuration are not set in GPO"
		}
	}
 ELSE {
		Write-BISFLog -Msg "Cache Disk will NOT be configured for DiskMode $DiskMode" -Type W
	}
}


End {
	Add-BISFFinishLine
}
