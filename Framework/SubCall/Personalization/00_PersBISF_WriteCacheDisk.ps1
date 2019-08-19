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
	  	Company: Login Consultants Germany GmbH

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
	$reg_value_WriteCacheDrive = "WriteCacheDrive"
	$PVSDiskLabel = "WriteCache"
	$PVSCheckFile = "$PVSDiskDrive\$computer-$PSScriptName.txt"
	$DiskpartFile = "$TEMP\$computer-DiskpartFile.txt"
	$PVSPersonality = "$SysDrive\Personality.ini"
	$SkipReboot = "FALSE"
}

Process {
	# Get uniqueID from MasterImage
	function GetUniqueIDreg {
		#read UniqueID from registry
		Write-BISFLog -Msg "Read uniqueID from registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
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

	# Check WriteCacheDrive Driveletter and Check UniqueID
	function CheckWriteCacheDrive {
		# Check for PVSLogs Folder on WriteCache Partition
		if ((Test-Path -Path "$LIC_BISF_LogPath") -eq $false) {
			Write-BISFLog -Msg "LogFolder $LIC_BISF_LogPath does not exist" -Type W -SubMsg
			# Check for Cache on Device HardDrive Mode
			if ((Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\bnistack\PVSAgent).WriteCacheType -eq 4 -or (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\bnistack\PVSAgent).WriteCacheType -eq 9) {
				Write-BISFLog -Msg "vDisk is set to Cache on Device Hard Drive Mode"
				If ((Get-CimInstance -ClassName Win32_volume).count -lt 3) {
					# WriteCache Disk not Formatted
					# Construct Diskpart File to Format Disk

					Write-BISFLog -Msg "WriteCache partition is not formatted"

					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					"select disk 0" | Out-File -filepath $DiskpartFile -encoding Default
					"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"create partition primary" | Out-File -filepath $DiskpartFile -encoding Default -append
					"assign letter $PVSDiskDrive" | Out-File -filepath $DiskpartFile -encoding Default -append
					"Format FS=NTFS LABEL=$PVSDiskLabel QUICK" | Out-File -filepath $DiskpartFile -encoding Default -append
					get-LogContent -GetLogFile "$DiskpartFile"
					diskpart /s $DiskpartFile
					Write-BISFLog -Msg "WriteCache partition is now formatted and the drive letter $PVSDiskDrive assigned"

					# Get WriteCache Volume and Restore Unique ID
					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					#$Searchvol = "list volume" | diskpart | select-string -pattern "Volume" | select-string -pattern "$PVSDiskDrive.substring(0,1)" -casesensitive | select-string -pattern NTFS | out-string
					#$getvolNbr    = $Searchvol.substring(11,1)   # get Volumenumber from DiskLabel
					#"select volume $getvolNbr" | out-file -filepath $DiskpartFile -encoding Default
					"select disk 0" | Out-File -filepath $DiskpartFile -encoding Default
					"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
					get-LogContent -GetLogFile "$DiskpartFile"
					diskpart /s $DiskpartFile
					Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
				}
				else {
					# WriteCache Formatted, but No or Wrong Drive Letter Assigned
					Write-BISFLog -Msg "WriteCache disk is formatted, but no or the wrong drive letter is assigned"  -Type W -SubMsg

					Write-BISFLog -Msg "Fixing drive letter assignemnt on WriteCache disk"
					$WriteCache = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 3 and BootVolume = False"
					Set-CimInstance -InputObject $WriteCache  -Arguments @{DriveLetter = "$PVSDiskDrive" }

					If (Test-Path $DiskpartFile) { Remove-Item $DiskpartFile -Force }
					#$Searchvol = "list volume" | diskpart | select-string -pattern $PVSDiskLabel | out-string
					#$getvolNbr = $Searchvol.substring(11,1)   # get Volumenumber from DiskLabel
					#"select volume $getvolNbr" | out-file -filepath $DiskpartFile -encoding Default
					"select disk 0" | Out-File -filepath $DiskpartFile -encoding Default
					"online disk noerr" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"rescan" | Out-File -filepath $DiskpartFile -encoding Default -append
					"uniqueid disk ID=$uniqueid_REG" | Out-File -filepath $DiskpartFile -encoding Default -append
					get-LogContent -GetLogFile "$DiskpartFile"
					$result = diskpart /s $DiskpartFile
					Write-BISFLog -Msg "Disk ID $uniqueid_REG is set on $PVSDiskDrive"
				}
			}
			else {
				Write-BISFLog -Msg "vDisk is not in Read Only Mode, skipping WriteCache preparation"
			}

			IF (!($SkipReboot -eq "TRUE")) {
				Write-BISFLog -Msg "Wait 60 seconds before system restart" -Type W
				Write-BISFLog -Msg "Reboot needed for config changes"
				Start-Process "$($env:windir)\system32\shutdown.exe" -ArgumentList "/r /t 60 /d p:2:4 /c ""BIS-F prepare WriteCacheDisk - reboot in 60 seconds.."" " -Wait
				Start-Sleep 120
			}
			ELSE {
				Write-BISFLog -Msg "SkipReboot is set to $SkipReboot on this computer $computer"
			}
		}
		else {
			Write-BISFLog -Msg "WriteCache partition is properly configured"
		}
	}


	####################################################################

	###################################################################
	# Get Reference Server Hostname in registry to detect it and skip reboot
	function GetRefSrv {
		IF ($CTXAppLayeringSW -eq $true) {
			$SkipReboot = "TRUE"
			Write-BISFLog -Msg "Citrix AppLayering is installed - set SkipReboot = $SkipReboot"
		}
		ELSE {
			Write-BISFLog -Msg "Read reference server hostname from registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
			$RefSrv_Hostname_REG = Get-ItemProperty -path $hklm_software_LIC_CTX_BISF_SCRIPTS | % { $_.LIC_BISF_RefSrv_Hostname }
			IF ($RefSrv_Hostname_REG -eq "$computer")
			{ $SkipReboot = "TRUE" }
			Write-BISFLog -Msg "Reference server hostname [$RefSrv_Hostname_REG] / hostname from this machine [$computer] - set SkipReboot = $SkipReboot "
		}
		return $SkipReboot
	}
	####################################################################

	####################################################################
	$SkipReboot = GetRefSrv
	CheckCDRom

	IF (!($LIC_BISF_CLI_WCD -eq $null)) {
		IF ("$returnTestPVSSoftware" -eq $true) {
			$uniqueid_REG = GetUniqueIDreg
			CheckWriteCacheDrive
		}
		ELSE {
			Write-BISFLog -Msg "WriteCache Disk would not be checked or formatted, beacuse the Citrix Provisioning Services software is not installed on this system!" -Type W
		}
	}
	ELSE {
		Write-BISFLog -Msg "PVSWriteCacheDisk not configured with the ADMX, skip function to set uniqueID from persistent drive"
	}
}


End {
	Add-BISFFinishLine
}