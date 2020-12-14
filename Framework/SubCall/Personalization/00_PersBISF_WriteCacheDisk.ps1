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
		04.03.2014 BR: Added function CheckCDRom
		13.03.2014 MS: Changed optical Driveletter a variable $OptDrive="B:"
		21.03.2014 MS: Read optical driveletter from registry that would be set with Base-Image during PVS preperation
		05.06.2014 BR: Added WriteCache Option Check for PVS Device RAM with Overflow to Device HardDisk
		05.06.2014 BR: Use Write-BISFLog function for Logging
		30.06.2014 MS: Changed to $LOGfile = Set-Logfile
		13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script on1ly
		13.08.2014 MS: Check if $returnCheckPVSSysVariable exists, then set uniqueID for persitend drive
		13.08.2014 MS. Removed hrdcoded Logpath D:\PVSLogs, change it to $LIC_PVS_LogPath
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
	function GetUniqueIDreg {
		#read UniqueID from registry
		Write-BISFLog -Msg "Reading uniqueID from registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
		$uniqueid_REG = Get-ItemProperty -path $hklm_software_LIC_CTX_BISF_SCRIPTS | % { $_.LIC_BISF_UniqueID_Disk }
		$uniqueid_REG
		Write-BISFLog -Msg "Read uniqueID $uniqueid_REG"
	}

	function CheckCDRom {
		$CDrom = Get-CimInstance -ClassName Win32_volume -Filter "DriveType = 5"
		If ($CDrom.DriveLetter -ne "$LIC_BISF_OptDrive") {
			Set-CimInstance -InputObject $CDRom -Arguments @{DriveLetter = "$LIC_BISF_OptDrive" }
			Write-BISFLog -Msg "Set optical drive letter to $LIC_BISF_OptDrive"
		}
	}

	function Test-WriteableCacheDisk {
		$ErrorActionPreference = "Stop"
		$val = $true
		try {
			IF (!(Test-path $CacheCheckFile)) {new-item $CacheCheckFile}
		}

		catch {
			$val = $false
		}

		finally {
			IF (Test-path $CacheCheckFile) {remove-item $CacheCheckFile -Force}
		}
		$ErrorActionPreference = "Continue"
		return $val
	}

	# Check WriteCacheDrive Driveletter and Check UniqueID
	function CheckWriteCacheDrive {
		# test checkfile on CacheDisk
		$TestCache = Test-WriteableCacheDisk
		if ($TestCache -eq $false) {
			Write-BISFLog -Msg "CacheDisk partition is NOT properly configured" -Type W
			$WriteCacheType = Get-BISFPVSWriteCacheType
			if (($WriteCacheType -eq 4) -or ($WriteCacheType -eq 9) -or ($WriteCacheType -eq 12)) {   # 4:Cache on Device Hard Disk // 9:Cache in Device RAM with Overflow on Hard Disk // 12:Cache in Device RAM with Overflow on Hard Disk async
				Write-BISFLog -Msg "vDisk is set to Cache on Device Hard Drive Mode"
				#grab the numbers of Partitions from the BIS-F ADMX
				Write-BISFLog -Msg "Number of Partitions from ADMX: $LIC_BISF_CLI_NumberOfPartitions"
				$SystemPartitions = (Get-CimInstance -ClassName Win32_Volume -filter "DriveType=3" | measure).count
				Write-BISFLog -Msg "Number of Partitions on current System: $SystemPartitions"
				If ($SystemPartitions -ne $LIC_BISF_CLI_NumberOfPartitions) {
					# CacheDisk not Formatted
					# Construct Diskpart File to Format CacheDisk

					Write-BISFLog -Msg "CacheDisk partition is not formatted"
					Write-BISFLog -Msg "BootDisk DiskID  $BootDiskID - CacheDisk DiskID $CachDiskID (Reporting only, not functional!)"

					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					"select disk 0" | Out-File -filepath $DiskpartFile -encoding Default
					"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"create partition primary" | Out-File -filepath $DiskpartFile -encoding Default -append
					"assign letter $PVSDiskDrive" | Out-File -filepath $DiskpartFile -encoding Default -append
					"Format FS=NTFS LABEL=$DiskLabel QUICK" | Out-File -filepath $DiskpartFile -encoding Default -append
					Get-BISFLogContent -GetLogFile "$DiskpartFile"
					diskpart.exe /s $DiskpartFile
					Write-BISFLog -Msg "CacheDisk partition is now formatted and the drive letter $PVSDiskDrive assigned"

					# Get WriteCache Volume and Restore Unique ID
					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					"select disk 0" | Out-File -filepath $DiskpartFile -encoding Default
					"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
					Get-BISFLogContent -GetLogFile "$DiskpartFile"
					diskpart.exe /s $DiskpartFile
					Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
				}
				else {
					# CacheDisk Formatted, but No or Wrong Drive Letter Assigned
					Write-BISFLog -Msg "CacheDisk is formatted, but no drive letter or the wrong drive letter is assigned"  -Type W -SubMsg

					Write-BISFLog -Msg "Fixing drive letter assignemnt on CacheDisk"
					$WriteCache = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 3 and BootVolume = False"
					Set-CimInstance -InputObject $WriteCache  -Arguments @{DriveLetter = "$PVSDiskDrive" }

					Write-BISFLog -Msg "BootDisk DiskID  $BootDiskID - CacheDisk DiskID $CachDiskID (Reporting only, not functional!)"
					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					"select disk 0" | Out-File -filepath $DiskpartFile -encoding Default
					"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
					Get-BISFLogContent -GetLogFile "$DiskpartFile"
					$result = diskpart.exe /s $DiskpartFile
					Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
				}
			}
			else {
				Write-BISFLog -Msg "vDisk is not in Read Only Mode, skipping CacheDisk preparation"
				$SkipReboot = $true
			}

			IF (!($SkipReboot -eq $true)) {
				Write-BISFLog -Msg "Wait 60 seconds before system restart" -Type W
				Write-BISFLog -Msg "Reboot needed for config changes"
				Start-Process "$($env:windir)\system32\shutdown.exe" -ArgumentList "/r /t 60 /d p:2:4 /c ""BIS-F prepare CacheDisk - reboot in 60 seconds.."" " -Wait
				Start-Sleep 120
			}
			ELSE {
				Write-BISFLog -Msg "Skip Reboot is set to $SkipReboot on this computer $computer"
			}
		}
		else {
			Write-BISFLog -Msg "CacheDisk partition is properly configured"
		}
	}

	function Test-MCSIOCacheDisk {
		# test checkfile on CacheDisk
		$TestCache = Test-WriteableCacheDisk
		if ($TestCache -eq $false) {
			Write-BISFLog -Msg "CacheDisk partition is NOT properly configured" -Type W
			#grab the numbers of Partitions from the BIS-F ADMX
			Write-BISFLog -Msg "Number of Partitions from ADMX: $LIC_BISF_CLI_MCSIONumberOfPartitions"
			$SystemPartitions = (Get-CimInstance -ClassName Win32_volume).count
			Write-BISFLog -Msg "Number of Partitions on current System: $SystemPartitions"
			If ($SystemPartitions -eq $LIC_BISF_CLI_MCSIONumberOfPartitions) {
				# WriteCache Disk not Formatted
				# Construct Diskpart File to Format Disk

				Write-BISFLog -Msg "CacheDisk partition is not formatted"
				Write-BISFLog -Msg "BootDisk DiskID  $BootDiskID - CacheDisk DiskID $CachDiskID"

				If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
				"select disk $CachDiskID" | Out-File -filepath $DiskpartFile -encoding Default
				"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
				"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
				"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
				"create partition primary" | Out-File -filepath $DiskpartFile -encoding Default -append
				"assign letter $PVSDiskDrive" | Out-File -filepath $DiskpartFile -encoding Default -append
				"Format FS=NTFS LABEL=$DiskLabel QUICK" | Out-File -filepath $DiskpartFile -encoding Default -append
				Get-BISFLogContent -GetLogFile "$DiskpartFile"
				diskpart.exe /s $DiskpartFile
				Write-BISFLog -Msg "CacheDisk partition is now formatted and the drive letter $PVSDiskDrive assigned"

				# Get CacheDisk Volume and Restore Unique ID
				If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
				"select disk 0" | Out-File -filepath $DiskpartFile -encoding Default
				"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
				Get-BISFLogContent -GetLogFile "$DiskpartFile"
				diskpart.exe /s $DiskpartFile
				Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
			}
			else {
				# WriteCache Formatted, but No or Wrong Drive Letter Assigned
				Write-BISFLog -Msg "CacheDisk is formatted, but no drive letter or the wrong drive letter is assigned"  -Type W -SubMsg

				# HF 297: removed the follwoing lines, this will be done with Diskpart and the $CachDiskID
				#Write-BISFLog -Msg "Fixing drive letter assignemnt on CacheDisk"
				#$WriteCache = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 3 and BootVolume = False"
				#Set-CimInstance -InputObject $WriteCache -Arguments @{DriveLetter = "$PVSDiskDrive" }
				Write-BISFLog -Msg "BootDisk DiskID  $BootDiskID - CacheDisk DiskID $CachDiskID"
				If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
				"select disk $CachDiskID" | Out-File -filepath $DiskpartFile -encoding Default
				"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
				"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
				"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
				"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
				Get-BISFLogContent-GetLogFile "$DiskpartFile"
				$null = diskpart.exe /s $DiskpartFile
				Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
			}

			IF (!($SkipReboot -eq $true)) {
				Write-BISFLog -Msg "Wait 60 seconds before system restart" -Type W
				Write-BISFLog -Msg "Reboot needed for config changes"
				Start-Process "$($env:windir)\system32\shutdown.exe" -ArgumentList "/r /t 60 /d p:2:4 /c ""BIS-F prepare CacheDisk - reboot in 60 seconds.."" " -Wait
				Start-Sleep 120
			}
			ELSE {
				Write-BISFLog -Msg "Skip Reboot is set to $SkipReboot on this computer $computer"
			}
		}
		else {
			Write-BISFLog -Msg "CacheDisk partition is properly configured"
		}
	}


	####################################################################

	###################################################################
	# Get Reference Server Hostname in registry to detect it and skip reboot
	function GetRefSrv {
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
	$SkipReboot = GetRefSrv
	CheckCDRom

	$DiskMode = Get-BISFDiskMode
	IF ( ($DiskMode -match "ReadOnly*") -or ($DiskMode -match "VDAShared*") ) {
		Write-BISFLog -Msg "CacheDisk will be configured now for Disk Mode $DiskMode"
		IF (!($LIC_BISF_CLI_WCD -eq $null) -or (!($LIC_BISF_CLI_WCD -eq "NONE")) ) {
			IF ($returnTestPVSSoftware -eq $true) {
				$uniqueid_REG = GetUniqueIDreg
				CheckWriteCacheDrive
			}
			ELSE {
				Write-BISFLog -Msg "CacheDisk not checked or formatted, Citrix Provisioning Services software is not installed on this system!" -Type W
			}
		}
		ELSE {
			Write-BISFLog -Msg "PVS CacheDisk is not configured or is set to 'NONE', skipping configuration"
		}

		IF ($LIC_BISF_CLI_MCSCfg -eq "YES") {
			IF (!($LIC_BISF_CLI_MCSIODriveLetter -eq $null) -or (!($LIC_BISF_CLI_MCSIODriveLetter -eq "NONE")) ) {
				IF ($MCSIO -eq $true) {
					$uniqueid_REG = GetUniqueIDreg
					Test-MCSIOCacheDisk
				}
				ELSE {
					Write-BISFLog -Msg "Citrix MCSIO with persistent Drive can't be used on this system!" -Type W
				}
			}
			ELSE {
				Write-BISFLog -Msg "MCSIO CacheDisk is not configured or is set to 'NONE', skipping configuration"
			}
		}
	}
 ELSE {
		Write-BISFLog -Msg "CacheDisk is NOT configured for DiskMode $DiskMode" -Type W
	}
}


End {
	Add-BISFFinishLine
}