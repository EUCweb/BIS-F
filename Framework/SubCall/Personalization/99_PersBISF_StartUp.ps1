<#
	.SYNOPSIS
		Configure several System Startup Actions (SSA)
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Benjamin Ruoff
	  	Company: Login Consultants Germany GmbH
		
		History:
	  	11.08.2015 BR: Script created
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		22.03.2016 MS: Added SDelete to run on the WriteCacheDisk on PVS Target Devices only
		10.11.2016 MS: SDelete will no longer be ditributed by BISF, it must be installed in C:\Windows\system32
		12.03.2017 MS: get WCDrive from $LIC_BISF_CLI_WCD insted of PVSWriteCacheDisk System Variable, it can be configured via ADMX now
		01.08.2017 MS: change sdeletePath, it can be set to a custom value
		02.08.2017 MS: With DiskMode AppLayering in OS-Layer the WSUS Update Service would be start
		29.10.2017 MS: replace VDA instead of MCS in the DiskMode Test
		20.10.2018 MS: Bugfix 73: MCS Image in Private Mode does not start the Windows Update Service
	.LINK
		https://eucweb.com
#>

Begin {
	#sdelete
	IF ($LIC_BISF_CLI_SD_SF -eq "1") { $SDeletePath = "$($LIC_BISF_CLI_SD_SF_CUS)\sdelete.exe" } ELSE { $SDeletePath = "C:\Windows\system32\sdelete.exe" }
	
}

Process {
	# region functions
	function start-sdelete {
		$varSD = Get-Variable -Name LIC_BISF_SDeleteRun -ValueOnly
		Write-BISFLog -Msg "SDelete would be set to the value $($varSD) in the registry"
		IF ($varSD -eq $true) {
			$WCDrive = $LIC_BISF_CLI_WCD
			IF ($WCDrive -ne $env:SystemDrive) {
				IF ((Test-Path ("$SDeletePath") -PathType Leaf )) {
					Write-BISFLog -Msg "Running SDelete on PVS WriteCacheDisk Drive $WCDrive" -ShowConsole -Color DarkCyan -SubMsg
					Start-BISFProcWithProgBar -ProcPath "$SDeletePath" -Args "-accepteula -z $($WCDrive)" -ActText "SDelete is running to Zero Out Free Space on drive $WCDrive"
				}
				ELSE {
					Write-BISFLog -Msg "SDelete could not detected in Path $SDeletePath"
				}
			}
			ELSE {	
				Write-BISFLog -Msg "PVS WriteCacheDisk Drive $WCDrive is equal to System Drive $env:SystemDrive... SDelete will not be run" -Type W
			}	
		}
	}

	function start-WUAserv {
		Write-BISFLog -Msg "Activating Windows Update Service" -ShowConsole -Color DarkCyan -SubMsg
		Invoke-BISFService -ServiceName wuauserv -Action Start -StartType Automatic
	}

	#endregion

	Write-BISFLog -Msg "Running system startup actions if needed..." -ShowConsole -Color Cyan
	$DiskMode = Get-BISFDiskMode
	Switch ($Diskmode) {
		ReadWrite {	
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			start-WUAserv
		}
		ReadOnly {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			start-sdelete
		}
		Unmanaged { }
		VDAPrivate {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			start-WUAserv
		}
		VDAShared { }
		ReadWriteAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") { start-WUAserv }
		}
		ReadOnlyAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			start-sdelete
		}
		UnmanagedAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") { start-WUAserv }
		}
		VDAPrivateAppLayering {
			Write-BISFLog -Msg "Running Actions for $Diskmode DiskMode" -ShowConsole -Color DarkCyan -SubMsg
			IF ($CTXAppLayerName -eq "OS-Layer") { start-WUAserv }
		}
		VDASharedAppLayering { }
		
		Default { Write-BISFLog -Msg "Default Action selected, doing nothing" -ShowConsole -Color DarkCyan }
	
	}

}

End {
	Add-BISFFinishLine
}