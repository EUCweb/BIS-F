[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		Prepare Base Image System
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)

		History:
		27.09.2012 MS: Script created
		10.10.2012 MS: Removed slmgr.vbs /rearm - write it into extra script
		17.10.2012 MS: Removed chkdsk /F - because it would like to run at next start
		04.02.2013 MS: Added Get-ChildItem -Path $CTX_SYS32_CACHE_PATH -filter * -Recurse | foreach ($_) {remove-item $_.fullname}
		18.09.2013 MS: Replaced $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		18.09.2013 MS: Added startup scheduled task to personalize system
		17.12.2013 MS: ARP Cache Changes – Windows 2008 / Vista / Windows 7, see http://support.citrix.com/article/ctx127549 for further details"
		28.01.2014 MS: Added ErrorAction to "Remove-Item -Path '$CTX_SYS32_CACHE_PATH' -Recurse -ErrorAction SilentlyContinue"
		28.01.2014 MS: Removed ipconfig /release
		28.01.2014 MS: Changed executionpoliy unrestricted for Line 36
		11.03.2014 MS: Read language specified adapter name to support mui installations for each customer, thanks to Benny Ruoff
		18.03.2014 BR: Revisited Script
		01.04.2014 MS: Added array to remove WindowsUpdateInformations
		02.04.2014 MS: [array]$PreMSG  = "N"   #<<-- display a messagebox to perform these step, set Y = YES or N = NO
		02.04.2014 MS: Added Question to run Defrag on Systemdisk
		02.04.2014 MS: Added Question to run Sysinternals SDelete to zero out empty vDisk areas and reduce storage
		13.05.2014 MS: Added multihoming support to read adaptername from each network,  see line 80
		13.05.2014 MS: Added PreCLI commands for silent action
		15.05.2014 MS: Changed console output to get-adaptername, line 91 -> Write-BISFLog -Msg  "Read AdapterName: $element"
		13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		14.08.2014 MS: Removed CLI-Command to show on console, send to logfile only
		13.10.2014 MS: Check WSUS Client-Side-Targeting to delete ClientID or set Service to manual
		09.02.2015 MS: Use NimbleFastReclaim instead of SDelete
		09.02.2015 JP/MS: Clear the Windows event logs
		09.02.2015 JP/MS: Added Question to run CCleaner
		12.12.2015 MS: Added question to run reset perfomance Counters
		14.04.2015 MS: Removed defrag, now it performed on the vDisk in the POST Script
		18.05.2015 MS: Added CLI Switch VERYSILENT handling
		20.05.2015 MS: Feature 45; W2012 R2 only - fix No remote Desktop Licence Server availible on RD Session Host server 2012
		08.06.2015 MS: Executing all queued .NET compilation jobs - Precompiling assemblies with Ngen.exe can improve the startup time for some applications.
		21.07.2015 BR: Edited Path $Dir_SwDistriPath, attended "Download"
		10.08.2015 MS: Bug 62; Added new function Write-ZeroesToFreeSpace instead of NimbleFastReclaim -> buggy on W2012R2
		11.08.2015 BR: Disable Windows Update Service
		11.08.2015 MS: Fixed code error at line 98 -> $NgenPath = Get-ChildItem -Path 'c:\windows\Microsoft.NET' -Recurse "ngen.exe" | % {$_.FullName}
		01.10.2015 MS: Rewritten script to use central BISF function
		04.11.2015 MS: Added CLI switch -DelAllUsersStartMenu to delete all Objects in C:\ProgramData\Microsoft\Windows\Start Menu\*
		25.11.2015 MS: Stop DHCP client Service, see https://www.citrix.com/blogs/2015/09/29/pvs-target-devices-the-blue-screen-of-death-rest-easy-we-can-fix-that/
		25.11.2015 MS: Added clear DHCP entries of Networkadapter, to prevent BlueScreen on some PVS Targetdevices https://www.citrix.com/blogs/2015/09/29/pvs-target-devices-the-blue-screen-of-death-rest-easy-we-can-fix-that/
		25.11.2015 MS: Reset Distributed Transaction Coordinator service if installed
		15.12.2015 MS: Feature 96; Added VMware Tools optimizations, thx to Ingmar Verheij - http://www.ingmarverheij.com
		16.12.2015 MS: Feature 99; Added Disable Task offload, thx to Ingmar Verheij - http://www.ingmarverheij.com
		16.12.2015 MS: Feature 99; Added increases the UDP packet size to 1500 bytes for FastSend - http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2040065, thx to Ingmar Verheij - http://www.ingmarverheij.com
		16.12.2015 MS: Feature 99; Added set multiplication factor to the default UDP scavenge value (MaxEndpointCountMult), http://support.microsoft.com/kb/2685007/en-us , thx to Ingmar Verheij - http://www.ingmarverheij.com
		16.12.2015 MS: Feature 99; Added disable Receive Side Scaling (RSS), http://support.microsoft.com/kb/951037/en-us , thx to Ingmar Verheij - http://www.ingmarverheij.com
		16.12.2015 MS: Feature 99; Added disable IPv6 completely , thx to Ingmar Verheij - http://www.ingmarverheij.com
		16.12 2015 MS: Feature 97; Added Hide PVS status icon, http://forums.citrix.com/thread.jspa?threadID=273278, , thx to Ingmar Verheij - http://www.ingmarverheij.com
		16.12.2015 MS: Feature 100; Disable Windows Services, thx to Thomas Krampe
		16.12.2015 MS: Feature 100; Disable useless Scheduled tasks, thx to Thomas Krampe
		16.12.2015 MS: Feature 100; Win8 only, run disk cleanup, thx to Thomas Krampe
		16.12.2015 MS: Feature 100; Added Disable Data Execution Prevention, Disable Startup Repair option, Disable New Network dialog, Set Power Saving Scheme to High Performance, , thx to Thomas Krampe
		07.01.2016 MS: Feature 79; Added Optimize-BISFWinSxs to cleanup and reduce WinSxs Folder
		20.01.2016 MS: Fix for Feature 99; Wrong Dword to completly disable IPv6 - 0x000000FF, thanks to Jonathan Pitre
		20.01.2016 MS: Fix for DelAllUsersStartMenu, typos in variable
		10.03.2016 MS: Issue 111; use nvspbind.exe to unbind IPV6 from AdapterGuid
		10.03.2016 MS: Added Delprof2.exe support
		22.03.2016 MS: Changed SDelete to run on the WriteCacheDisk on PVS Target Devices only
		24.03.2016 MS: Modified BIS-F scheduled task if even exist, thx to Valentino Pemoni
		10.11.2016 MS: Added Pre-Commands for Windows Server 2016 and Windows 10
		11.11.2016 MS: Create-BISFTask running in own function
		05.12.2016 MS: Bug fix: defrag not identify the right driveletter of the vDisk after P2PVS, if the Drivelabel is empty
		05.12.2016 MS: Variables must be cleared after each step, to not store the value in the variable and use them in the next $prepCommand
		01.13.2017 JP: Fixed the Disk Cleanup/WinSxS functions, added support for Windows 7 and 2008 R2
		21.02.2017 MS: Create BIS-F Adminshortcut on personal Desktop
		06.03.2017 MS: Bug Fix: Detecting WSUS TargetGroup
		06.03.2017 MS: Get FileVersion of Testpath for 3rd Party Apps
		07.03.2017 JP: Fixed typos and trailing space
		08.03.2017 MS: Syntax error Line 654: $varCLI = $($prepCommand.CLI)
		13.03.2017 MS: extend unneeded services for Win10 and Server 2016 to disable
		13.03.2017 MS: extend unneeded scheduled tasks for Win10 and Server 2016 to disable
		13.03.2017 MS: Disable Cortana for Win10 and Server 2016
		16.03.2017 FF: Bugfix for useless Service / Scheduled Task Disable
		11.04.2017 MS: Bugfix in Line 659 using $prepCommand insted of $PostCommand
		29.07.2017 MS: add schedule Task "ServerCeipAssistant" to disable, thx to Trentent Tye
		01.08.2017 MS: 3rd Party tools like sdelete, ccleaner, nvpsbind, delprof2, using custom searchfolder from ADMX if enabled
		01.08.2017 MS: add Progressbar for .NET Optimization
		02.08.2017 MS: delprof2 - get custom arguments from ADMX or use default value
		22.08.2017 MS: create or update BIS-F schedule Task to run with highest privileges, thx to Brandon Mitchgell
		22.08.2017 MS: clenup various directories, like temp, thx to Trentent Tye
		31.08.2017 MS: Clear all Eventlogs
		07.11.2017 MS: add $LIC_BISF_3RD_OPT = $false, if vmOSOT or CTXO is enabled and found, $LIC_BISF_3RD_OPT = $true and disable BIS-F own optimizations
		10.11.2017 MS: Feature: .NET Optimization to run if enabled or not configured in ADMX
		19.10.2018 MS: Bugfix 71: not to process ANY scheduled task disable actions
		20.10.2018 MS: Bugfix 56: Office click to run issue after BIS-F seal
		31.05.2019 MS: FRQ 92: Server 2019 Support
		31.05.2019 MS: ENH 105: Keep Windows Administrative Tools in Startmenu
		21.06.2019 MS: HF 116: During Preparation, BIS-F Shows Versionnumber instead of OSName
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		17.08.2019 MS: ENH 54: ADMX: Configure BIS-F Desktop Shortcut
		18.08.2019 MS: ENH 101: check sdelete Version 2.02 or newer, otherwise send out error
		25.08.2019 MS: FRQ 134: Removing Disable Cortana
		25.08.2019 MS: FRQ 133: Removing Disable scheduled Task
		03.10.2019 MS: ENH 102 - Use CCleaner64.exe on x64 system
		03.10.2019 MS: ENH 101 - Use sdelete64.exe on x64 system
		05.10.2019 MS: ENH 12 - Configure sDelete for different environments
		05.10.2019 MS: ENH 142 - Remove DirtyShutdown Flag
		05.10.2019 MS: HF 77 - Remvoing Wsus ClientSide Targeting and reset it during every sealing process
		05.10.2019 MS: ENH 16 - Add NVIDIA GRID Support for Citrix VDA
		05.10.2019 MS: ENH 143 - Add Intel Graphics Support for Citrix VDA
		27.12.2019 MS/MN: HF 159 - C:\Windows\temp not deleted
		27.12.2019 MS/MN: HF 162 - Note when logging on to a created VDisk (after ENH142)
		05.01.2020 MS: HF 173 - Remove DHCP Information if 3P Optimizer is configured
		13.01.2019 MS: HF 186 - deletion of C:\Windows\temp without GPO control is not possible
		18.02.2020 JK: Fixed Log output spelling
		23.05.2020 MS: HF 220 - fix typo for DirtyShutdown Flag
		31.07.2020 MS: HF 266 - fixing typo
		01.08.2020 MS: HF 252 - supporting new NVIDIA Drivers

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

	####################################################################
	# define environment
	$PreMSG = @()
	$PreTXT = @()
	$PreCMD = @()
	$PreCLI = @()
	$CTX_SYS32_CACHE_PATH = "C:\Program Files (x86)\Citrix\System32\Cache\*"
	$REG_hklm_WSUS = "$hklm_software\Microsoft\Windows\CurrentVersion\WindowsUpdate"
	$REG_HKLM_MS_CU = "$hklm_software\Microsoft\Windows\CurrentVersion"
	$REG_hklm_Pol_WSUS = "$hklm_software\Policies\Microsoft\Windows\WindowsUpdate"
	$REG_hku_HP = "$hku_software\Hewlett-Packard\"
	$Dir_SwDistriPath = "C:\Windows\SoftwareDistribution\Download\*"
	$File_WindowsUpdateLog = "C:\Windows\WindowsUpdate.log"
	$Dir_AllUsersStartMenu = "C:\ProgramData\Microsoft\Windows\Start Menu\*"
	$Global:BISFtask = "LIC_BISF_Device_Personalize"

	#Processing CLI commands to get 3rd Party custom searchfolders
	#ccleaner
	IF ($LIC_BISF_CLI_CC_SF -eq "1") { $SearchFoldersCC = $LIC_BISF_CLI_CC_SF_CUS } ELSE { $SearchFoldersCC = "$($env:ProgramFiles)\CCleaner" }
	#delprof2
	IF ($LIC_BISF_CLI_DP_SF -eq "1") { $SearchFoldersDP = $LIC_BISF_CLI_DP_SF_CUS } ELSE { $SearchFoldersDP = "C:\Windows\system32" }
	IF ($LIC_BISF_CLI_DP_Args -eq "1") { $DPargs = $LIC_BISF_CLI_DP_ARGS_CUS } ELSE { $DPargs = "/u /r" }

	#nvpsbind (IPV6)
	IF ($LIC_BISF_CLI_V6_SF -eq "1") { $SearchFoldersV6 = $LIC_BISF_CLI_V6_SF_CUS } ELSE { $SearchFoldersV6 = "C:\Windows\system32" }
	#sdelete
	IF ($LIC_BISF_CLI_SD_SF -eq "1") { $SearchFoldersSD = $LIC_BISF_CLI_SD_SF_CUS } ELSE { $SearchFoldersSD = "C:\Windows\system32" }

	Write-BISFLog -Msg "Preparing Array of PreCommands... please wait" -ShowConsole -Color Cyan
	# All commands that are used to prepare for building the vDisk
	$ordercnt = 10
	[array]$PrepCommands = @()

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Delete all Citrix Cached files $CTX_SYS32_CACHE_PATH";
		Command     = "Remove-Item -Path '$CTX_SYS32_CACHE_PATH' -Recurse -ErrorAction SilentlyContinue"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Delete SoftwareDistribution $Dir_SwDistriPath";
		Command     = "Remove-Item -Path '$Dir_SwDistriPath' -Recurse -ErrorAction SilentlyContinue"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Delete Windows Update Log $File_WindowsUpdateLog";
		Command     = "Remove-Item '$File_WindowsUpdateLog' -ErrorAction SilentlyContinue"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "Y";
		CLI         = "LIC_BISF_CLI_SM";
		TestPath    = "";
		Description = "Delete AllUsers Start Menu $Dir_AllUsersStartMenu ?";
		Command     = "Get-ChildItem -path '$Dir_AllUsersStartMenu' -Exclude 'Administrative Tools' | remove-item -Force -Recurse"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "Y";
		CLI         = "LIC_BISF_CLI_DP";
		TestPath    = "$($SearchFoldersDP)\delprof2.exe";
		Description = "Run Delprof2 to deletes inactive user profiles ?";
		Command     = "$($SearchFoldersDP)\delprof2.exe $($DPargs)"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Purge DNS resolver Cache";
		Command     = "ipconfig /flushdns"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Purge IP-to-Physical address translation tables Cache (ARP Table)";
		Command     = "arp -d *"
	};
	$ordercnt += 1

	# ENH 102 - Use CCleaner64.exe on x64 system
	IF ($OSBitness -eq "32-bit") {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "Y";
			CLI         = "LIC_BISF_CLI_CC";
			TestPath    = "$($SearchFoldersCC)\CCleaner.exe" ;
			Description = "Run CCleaner to clean temp files";
			Command     = "Start-BISFProcWithProgBar -ProcPath '$($SearchFoldersCC)\CCleaner.exe' -Args '/AUTO' -ActText 'CCleaner is running'"
		};
	}
 ELSE {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "Y";
			CLI         = "LIC_BISF_CLI_CC";
			TestPath    = "$($SearchFoldersCC)\CCleaner64.exe" ;
			Description = "Run CCleaner to clean temp files";
			Command     = "Start-BISFProcWithProgBar -ProcPath '$($SearchFoldersCC)\CCleaner64.exe' -Args '/AUTO' -ActText 'CCleaner is running'"
		};
	}
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "Y";
		CLI         = "LIC_BISF_CLI_PF";
		TestPath    = "";
		Description = "Reset Performance Counters";
		Command     = "lodctr.exe /r"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Clear all event logs";
		Command     = "'wevtutil el | Foreach-Object {wevtutil cl $_}'"
	};
	$ordercnt += 1
	IF ($LIC_BISF_3RD_OPT -eq $false) {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Disabling TCP/IP task offloading";
			Command     = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'DisableTaskOffload' -Value '1' -Type DWORD"
		};
		$ordercnt += 1
	}
	ELSE {
		Write-BISFLog -Msg "TCP/IP task offloading not optimized from BIS-F, because 3rd Party Optimization is configured" -Type W -ShowConsole -SubMsg
	}

	IF ($LIC_BISF_3RD_OPT -eq $false) {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Increases the UDP packet size to 1500 bytes for FastSend";
			Command     = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\afd\Parameters' -Name 'FastSendDatagramThreshold' -Value '1500' -Type DWORD"
		};
		$ordercnt += 1
	}
	ELSE {
		Write-BISFLog -Msg "Increases the UDP packet size to 1500 bytes for FastSend not optimized from BIS-F, because 3rd Party Optimization is configured" -Type W -ShowConsole -SubMsg
	}

	IF ($LIC_BISF_3RD_OPT -eq $false) {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Set multiplication factor to the default UDP scavenge value (MaxEndpointCountMult)";
			Command     = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\BFE\Parameters' -Name 'MaxEndpointCountMult' -Value '0x10' -Type DWORD"
		};
		$ordercnt += 1
	}
	ELSE {
		Write-BISFLog -Msg "Set multiplication factor to the default UDP scavenge value (MaxEndpointCountMult) not optimized from BIS-F, because 3rd Party Optimization is configured" -Type W -ShowConsole -SubMsg
	}

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Disable Receive Side Scaling (RSS)";
		Command     = "Start-Process -FilePath 'netsh.exe' -Argumentlist 'int tcp set global rss=disable' -Wait -WindowStyle Hidden"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "Y";
		CLI         = "LIC_BISF_CLI_V6";
		TestPath    = "";
		Description = "Disable IPv6 in registry ?";
		Command     = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\TcpIp6\Parameters' -Name 'DisabledComponents' -Value '0x000000FF' -Type DWORD"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Disable Data Execution Prevention";
		Command     = "Start-Process 'bcdedit.exe' -Verb runAs -ArgumentList '/set nx AlwaysOff' | Out-Null"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Disable Startup Repair option";
		Command     = "Start-Process 'bcdedit.exe' -Verb runAs -ArgumentList '/set {default} bootstatuspolicy ignoreallfailures' | Out-Null"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Disable New Network dialog";
		Command     = "Set-ItemProperty -Name NewNetworkWindowOff -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Network' -Type String -Value 0"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Set Power Saving Scheme to High Performance";
		Command     = "Start-Process 'powercfg.exe' -Verb runAs -ArgumentList '-s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'"
	};
	$ordercnt += 1

	# ENH 12: Running SDelete during preparation
	IF ($RunPrepSdelete -eq $true) {
		IF ($OSBitness -eq "32-bit") { $sdeleteversion = "sdelete.exe" } ELSE { $sdeleteversion = "sdelete64.exe" }
		IF ($LIC_BISF_CLI_SD_SF -eq "1") {
			$SDeletePath = "$($LIC_BISF_CLI_SD_SF_CUS)\$sdeleteversion"
		}
		ELSE {
			$SDeletePath = "C:\Windows\system32\$sdeleteversion"
		}
		$DiskType = Get-BISFDiskNameExtension

		#During sealing on the BaseImage
		IF ( ($LIC_BISF_CLI_SD_runBI -eq 1) -and ($CTXAppLayerName -ne "No-ELM") -and ($DiskType -eq "BaseDisk") -or ($DiskType -eq "NoVirtualDisk") ) {
			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "$SDeletePath";
				Description = "SDelete is running to Zero Out Free Space on the Base Image";
				Command     = "Start-BISFProcWithProgBar -ProcPath '$SDeletePath' -Args '-accepteula -z C:' -ActText 'SDelete is running to Zero Out Free Space on the Base Image'"
			};
			$ordercnt += 1
		}

		#During sealing on the PVS parent Disk (avhd or avhdx)
		IF ( ($LIC_BISF_CLI_SD_runPVSparentDisk -eq 1) -and ($DiskType -eq "ParentDisk") ) {
			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				cli         = "";
				TestPath    = "$SDeletePath";
				Description = "SDelete is running to Zero Out Free Space on the PVS parent Disk";
				Command     = "Start-BISFProcWithProgBar -ProcPath '$SDeletePath' -Args '-accepteula -z C:' -ActText 'SDelete is running to Zero Out Free Space on the PVS parent Disk'"
			};
			$ordercnt += 1
		}

		#During sealing with Citrix AppLayering outside ELM IF (!($CTXAppLayerName -eq "No-ELM")) {
		IF ( ($LIC_BISF_CLI_SD_runOutsideELM -eq 1) -and ($CTXAppLayerName -eq "No-ELM") ) {
			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				cli         = "";
				TestPath    = "$SDeletePath";
				Description = "SDelete is running to Zero Out Free Space with AppLayering Outside ELM";
				Command     = "Start-BISFProcWithProgBar -ProcPath '$SDeletePath' -Args '-accepteula -z C:' -ActText 'SDelete is running to Zero Out Free Space with AppLayering Outside ELM'"
			};
			$ordercnt += 1
		}
	}


	IF (!($LIC_BISF_CLI_DotNet -eq "NO")) {

		### Executing all queued .NET compilation jobs - Precompiling assemblies with Ngen.exe can improve the startup time for some applications.
		$NgenPath = Get-ChildItem -Path 'C:\Windows\Microsoft.NET' -Recurse "ngen.exe" | % { $_.FullName }
		foreach ($element in $NgenPath) {
			Write-BISFLog -Msg  "Read Ngen Path: $element"
			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "Executing all queued .NET compilation jobs for $element";
				Command     = "Start-BISFProcWithProgBar -ProcPath '$element' -Args 'ExecuteQueuedItems' -ActText 'Running .NET Optimization in $element'"
			};
			$ordercnt += 1
		}
	}
	ELSE {
		Write-BISFLog -Msg "Microsoft .NET Optimization is disabled in ADMX"
	}


		## Read language specified adapter name to support mui installations for each customer
		$adapter = get-BISFAdapterName
		foreach ($element in $adapter) {
			Write-BISFLog -Msg  "Read AdapterName: $element"
			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "ARP Cache Changes Adapter: $element ... (http://support.citrix.com/article/ctx127549)";
				Command     = "netsh interface ipv4 set interface ""$element"" basereachable=600000"
			};
			$ordercnt += 1

		}

		## Read GUID of DHCP Network Adapter and clear DHCP-option, see https://www.citrix.com/blogs/2015/09/29/pvs-target-devices-the-blue-screen-of-death-rest-easy-we-can-fix-that/
		$adapter = get-BISFAdapterGUID
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Stop DHCP Client Service";
			Command     = "Stop-Service -Name dhcp -ErrorAction SilentlyContinue"
		};
		$ordercnt += 1

		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Clear NameServer in Registry TCPIP\Parameters";
			Command     = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'NameServer' -value '' "
		};
		$ordercnt += 1

		foreach ($element in $adapter) {
			Write-BISFLog -Msg  "Read AdapterGUID: $element"
			$REG_HKLM_TCPIP_Interfaces_GUID = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$element"
			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "AdapterGUID: $element - clear NameServer";
				Command     = "Set-ItemProperty -Path '$REG_HKLM_TCPIP_Interfaces_GUID' -Name 'NameServer' -value '' "
			};
			$ordercnt += 1

			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "AdapterGUID: $element - clear Domain";
				Command     = "Set-ItemProperty -Path '$REG_HKLM_TCPIP_Interfaces_GUID' -Name 'Domain' -value '' "
			};
			$ordercnt += 1

			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "AdapterGUID: $element - clear DhcpIPAddress";
				Command     = "Set-ItemProperty -Path '$REG_HKLM_TCPIP_Interfaces_GUID' -Name 'DHCPIPAddress' -value '' "
			};
			$ordercnt += 1

			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "AdapterGUID: $element - clear DhcpSubnetmask";
				Command     = "Set-ItemProperty -Path '$REG_HKLM_TCPIP_Interfaces_GUID' -Name 'DhcpSubnetmask' -value '' "
			};
			$ordercnt += 1

			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "AdapterGUID: $element - clear DhcpServer";
				Command     = "Set-ItemProperty -Path '$REG_HKLM_TCPIP_Interfaces_GUID' -Name 'DhcpServer' -value '' "
			};
			$ordercnt += 1

			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "AdapterGUID: $element - clear DhcpNameServer";
				Command     = "Set-ItemProperty -Path '$REG_HKLM_TCPIP_Interfaces_GUID' -Name 'DhcpNameServer' -value '' "
			};
			$ordercnt += 1

			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "";
				Description = "AdapterGUID: $element - clear DhcpDefaultGateway";
				Command     = "Set-ItemProperty -Path '$REG_HKLM_TCPIP_Interfaces_GUID' -Name 'DhcpDefaultGateway' -value '' "
			};
			$ordercnt += 1

			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "Y";
				CLI         = "LIC_BISF_CLI_V6";
				TestPath    = "$($SearchFoldersV6)\nvspbind.exe";
				Description = "Disable IPv6 on AdapterGUID: $element ?";
				Command     = "$($SearchFoldersV6)\nvspbind.exe /d ""$element"" ms_tcpip6"
			};
			$ordercnt += 1
		}

	## reset Distributed Transaction Coordinator service if installed
	$svc = Test-BISFService -ServiceName "MSDTC"
	IF ($svc -eq $true) {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Reset Microsoft Distributed Transaction Service ";
			Command     = "msdtc.exe -reset"
		};
		$ordercnt += 1
	}


	## vmware tools optimizations
	$svc = Test-BISFService -ServiceName "vmtools"
	IF ($svc -eq $true) {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Hide Vmware Tools icon in systray";
			Command     = "Set-ItemProperty -Path 'HKLM:\SOFTWARE\VMware, Inc.\VMware Tools' -Name 'ShowTray' -Value '0' -Type DWORD"
		};
		$ordercnt += 1
	}

	$svc = Test-BISFService -ServiceName "vmdebug"
	IF ($svc -eq $true) {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Disable VMware debug driver";
			Command     = "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\services\vmdebug' -Name 'Start' -Value '4' -Type DWORD"
		};
		$ordercnt += 1
	}


	## hide PVS status icon
	IF ($returnTestPVSSoftware -eq "true") {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Hide PVS Status icon in systray";
			Command     = "New-Item -Path 'HKLM:\SOFTWARE\CITRIX\ProvisioningServices\Status' -Force | out-null; Set-ItemProperty -Path 'HKLM:\SOFTWARE\CITRIX\ProvisioningServices\Status' -Name 'ShowIcon' -Value '0' -Type DWORD"
		};
		$ordercnt += 1

	}

	## Rmove WSUS ID

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Delete WSUS - SusClientId in $REG_hklm_WSUS";
		Command     = "Remove-ItemProperty -Path '$REG_hklm_WSUS' -Name 'SusClientId' -ErrorAction SilentlyContinue"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Delete WSUS - SusClientIdValidation in $REG_hklm_WSUS";
		Command     = "Remove-ItemProperty -Path '$REG_hklm_WSUS' -Name 'SusClientIdValidation' -ErrorAction SilentlyContinue"
	};
	$ordercnt += 1


	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Set Windows Update Service to Disabled";
		Command     = "Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue"
	};
	$ordercnt += 1

<# 13.01.2019 MS: HF 186 - deletion of C:\Windows\temp without GPO control is not possible
	$paths = @( "$env:windir\Temp", "$env:temp")

	foreach ($path in $paths) {
		$PrepCommands += [pscustomobject]@{
			Order       = "$ordercnt";
			Enabled     = "$true";
			showmessage = "N";
			CLI         = "";
			TestPath    = "";
			Description = "Cleaning directory: $path";
			Command     = "Remove-BISFFolderAndContents -folder_path $path"
		};
		$ordercnt += 1
	}
#>

	$PrepCommands += [pscustomobject]@{
		Order       = "$ordercnt";
		Enabled     = "$true";
		showmessage = "N";
		CLI         = "";
		TestPath    = "";
		Description = "Remove DirtyShutdown to prevent not correct shutdown after reboot";
		Command     = "Remove-ItemProperty -Path '$REG_HKLM_MS_CU' -Name 'DirtyShutdown' -ErrorAction SilentlyContinue"
	};
	$ordercnt += 1

	$PrepCommands += [pscustomobject]@{
            Order       = "$ordercnt";
            Enabled     = "$true";
            showmessage = "N";
            CLI         = "";
            TestPath    = "";
            Description = "Remove LastAliveStamp to prevent shutdown tracker after reboot";
            Command     = "Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability' -Name 'LastAliveStamp' -ErrorAction SilentlyContinue"
      };
      $ordercnt += 1

	IF (($LIC_BISF_CLI_VDA_NVDIAGRID -eq 1) -and ($LIC_BISF_CLI_VDA_INTELGRFX -eq 1)) {
		Write-BISFLog -Msg "NVIDIA GRID and Intel Graphic can't be enabled at the same time, please check the ADMX configuration!" -ShowConsole -Type E
		Start-Sleep -Seconds 20
	}
 ELSE {
		IF ($LIC_BISF_CLI_VDA_NVDIAGRID -eq 1) {
			$NvidiaServiceName = @("nvsvc","NVWMI")
			Foreach ($ServiceName in $NvidiaServiceName) {
				$ServiceDisplayName = $(Get-Service -Name $ServiceName).DisplayName
				$svc = Test-BISFService -ServiceName $ServiceName -ProductName $ServiceDisplayName
				IF ($svc -eq $true) {
					Write-BISFLog -Msg "VDA Version $VDAVersion" -ShowConsole
					IF ($VDAVersion -le "7.11") {
						$cmd = "$glbSVCImagePath\bin\Montereyenable.exe" # $glbSVCImagePath is getting from Test-BISFService
						$args = "-enable -noreset"
					}

					IF ($VDAVersion -ge "7.12") {
						$cmd = "$glbSVCImagePath\bin\NVFBCEnable.exe" # $glbSVCImagePath is getting from Test-BISFService
						$args = "-enable -noreset"
					}

					$PrepCommands += [pscustomobject]@{
						Order       = "$ordercnt";
						Enabled     = "$true";
						showmessage = "N";
						CLI         = "";
						TestPath    = "$cmd";
						Description = "Enable NVIDIA GRID with command $cmd $args";
						Command     = "Start-BISFProcWithProgBar -ProcPath '$cmd' -Args '$args' -ActText 'Enable NVIDIA GRID for VDA Version $VDAVersion'"
					};
					$ordercnt += 1
				}
				ELSE {
					Write-BISFLog -Msg "$ServiceDisplayName is not installed and can't be enabled" -ShowConsole -Type W
				}
			}
		}

		IF ($LIC_BISF_CLI_VDA_INTELGRFX -eq 1) {
			$cmd = "$env:ProgramFiles\Citrix\ICAServices\IntelVirtualDisplayTool.exe"
			$args = "-vd enable"

			$PrepCommands += [pscustomobject]@{
				Order       = "$ordercnt";
				Enabled     = "$true";
				showmessage = "N";
				CLI         = "";
				TestPath    = "$cmd";
				Description = "Enable Intel graphics with command $cmd $args";
				Command     = "Start-BISFProcWithProgBar -ProcPath '$cmd' -Args '$args' -ActText 'Enable Intel graphics  for VDA Version $VDAVersion'"
			};
			$ordercnt += 1
		}
	}

	####################################################################

	####################################################################
	####### functions #####

	# Prepare System
	function PreCommand {
		Write-BISFLog -Msg "Running PreCommands on your Base-Image" -ShowConsole -Color Cyan
		Foreach ($prepCommand in ($PrepCommands | Sort-Object -Property "Order")) {
			Write-BISFLog -Msg "Processing Order-Nbr $($prepCommand.Order): $($prepCommand.Description)"
			#write-host "TestPath: $($prepCommand.TestPath)" -ForegroundColor White -BackgroundColor Red  #<<< enable for debug only
			IF ( ($prepCommand.TestPath -eq "" ) -or (Test-Path $($prepCommand.TestPath)) ) {

				IF ($($prepCommand.TestPath) -ne "" ) {
					$Productname = (Get-Item $($prepCommand.TestPath)).Basename
					$ProductFileVersion = (Get-Item $($prepCommand.TestPath)).VersionInfo.FileVersion
					Write-BISFLog -Msg "Product $Productname $ProductFileVersion installed" -ShowConsole -Color Cyan
					IF (($Productname -eq "sdelete") -and ($ProductFileVersion -lt "2.02")) {
						Write-BISFLog -Msg "WARNING: $Productname $ProductFileVersion is not supported, Please use Version 2.02 or newer !!" -ShowConsole -Type E
						Start-Sleep 20
					}

				}
				Write-BISFLog -Msg "Configure $($prepCommand.Description)" -ShowConsole -Color DarkCyan -SubMsg
				# write-host "MessageBox: $($prepCommand.showmessage)" -ForegroundColor White -BackgroundColor Red  #<<< enable for debug only
				IF ($($prepCommand.showmessage) -eq "N") {
					# Write-BISFLog -Msg "$($prepCommand.Command)" -ShowConsole
					Invoke-Expression $($prepCommand.Command)
				}
				ELSE {
					Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
					$varCLI = Get-Variable -Name $($prepCommand.CLI) -ValueOnly
					If (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
						Write-BISFLog -Msg "GPO Valuedata: $varCLI"
					}
					ELSE {

						Write-BISFLog -Msg "GPO not configured.. using default setting" -ShowConsole -SubMsg -Color DarkCyan
						$DefaultValue = "No"
					}
					if (($DefaultValue -eq "YES") -or ($varCLI -eq "YES")) {
						Write-BISFLog -Msg "Running Command $($prepCommand.Command)"
						Invoke-Expression $($prepCommand.Command)
					}
					ELSE {
						Write-BISFLog -Msg " Skipping Command $($prepCommand.Description)" -ShowConsole -Color DarkCyan -SubMsg
					}
				}
				# these 2 variables must be cleared after each step, to not store the value in the variable and use them in the next $prepCommand
				$varCLI = @()
				$PreMsgBox = @()
			}
			ELSE {
				Write-BISFLog -Msg "Product $($prepCommand.TestPath) is NOT installed, neccessary for Order-Nbr $($prepCommand.Order): $($prepCommand.Description)"

			}
		}

	}

	function Create-BISFTask {
		# searching for BISF scheduled task and if from different BIS-F version delete them

		$testBISFtask = schtasks.exe /query /v /FO CSV | ConvertFrom-Csv | where { $_.TaskName -eq "\$BISFtask" }
		IF (!($testBISFtask)) {
			Write-BISFLog -Msg "Create startup task $BISFtask to personalize System" -ShowConsole -Color Cyan
			schtasks.exe /create /sc ONSTART /TN "$BISFtask" /IT /RU 'System' /RL HIGHEST /tr "powershell.exe -Executionpolicy unrestricted -file '$LIC_BISF_MAIN_PersScript'" /f | Out-Null
		}
		ELSE {
			Write-BISFLog -Msg "Task already exists, modify startup task $BISFtask to personalize System" -ShowConsole -Color Cyan
			schtasks.exe /change /TN "$BISFtask" /RL HIGHEST /tr "powershell.exe -Executionpolicy unrestricted -file '$LIC_BISF_MAIN_PersScript'" | Out-Null
		}

	}

	function Test-DrvLabel {
		$SysDrive = $env:SystemDrive
		$Sysdrvlabel = Get-CimInstance -ClassName Win32_Volume -Filter "Driveletter = '$SysDrive' " | % { $_.Label }
		$DriveLabel = "OSDisk"
		IF ($Sysdrvlabel -eq $null) {
			Write-BISFLog -Msg "DriveLabel for $SysDrive would be set to $DriveLabel" -ShowConsole -Color Cyan
			$drive = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$SysDrive'"
			$drive.Label = "$DriveLabel"
			$drive.put() | Ou-Null
		}


	}


	function Invoke-DesktopShortcut {
		IF ($LIC_BISF_CLI_DesktopShortcut -eq "YES") {
			Write-BISFLog -Msg "Create BIS-F Shortcut on your Desktop" -ShowConsole -Color Cyan
			$DisplayIcon = $InstallLocation + "Framework\SubCall\Global\BISF.ico"
			$WshShell = New-Object -comObject WScript.Shell
			$Shortcut = $WshShell.CreateShortcut("$Home\Desktop\PrepareBaseImage (BIS-F) Admin Only.lnk")
			$Shortcut.TargetPath = "$InstallLocation\PrepareBaseImage.cmd"
			$Shortcut.IconLocation = "$DisplayIcon"
			$Shortcut.Description = "Run Base Image Script Framework (Admin Only)"
			$Shortcut.WorkingDirectory = "$InstallLocation"
			$Shortcut.Save()
		}

		IF ($LIC_BISF_CLI_DesktopShortcut -eq "NO") {
			Write-BISFLog -Msg "Removing BIS-F Shortcut on your Desktop" -ShowConsole -Color Cyan
			Remove-Item "$Home\Desktop\PrepareBaseImage (BIS-F) Admin Only.lnk" -Force
		}
	}

	function Clear-EventLog {
		wevtutil.exe el | ForEach-Object {
			Write-BISFLog -Msg  "Clearing Event-Log $_" -ShowConsole -Color DarkCyan -Submsg
			wevtutil.exe cl "$_"
		}
	}

	function Create-AllusersStartmenuPrograms {
		#bugfix 56: recreate "$Dir_AllUsersStartMenu\Programs" that is necassary for to start Office C2R or other AppX after delete $Dir_AllUsersStartMenu
		$StartMenuProgramsPath = $Dir_AllUsersStartMenu.Substring(0, $Dir_AllUsersStartMenu.Length - 2) + "\Programs"
		IF (!(Test-Path "$StartMenuProgramsPath")) {
			Write-BISFLog -Msg "Create Directory $StartMenuProgramsPath" -ShowConsole -Color Cyan
			New-Item -ItemType Directory -Path "$StartMenuProgramsPath" | Out-Null
		}
	}

	function Pre-Win7 {

	}

	function Pre-Win2008R2 {

	}

	function Pre-Win8 {

		Optimize-BISFWinSxs
	}

	function Pre-Win2012R2 {

		Optimize-BISFWinSxs
	}

	function Pre-Win2016 {
		Optimize-BISFWinSxs

	}

	function Pre-Win10 {
		Optimize-BISFWinSxs
	}



	####################################################################
}

Process {

	#### Main Program


	## OS Windows 7
	IF ($OSName -contains '*Windows 7*') {
		Write-BISFLog -Msg "Running PreCommands for $OSName" -ShowConsole -Color Cyan
		Pre-Win7
	}

	## OS Windows 2008 R2
	IF (($OSVersion -like "6.1*") -and ($ProductType -eq "3")) {
		Write-BISFLog -Msg "Running PreCommands for $OSName" -ShowConsole -Color Cyan
		Pre-Win2008R2
	}

	## OS Windows 8
	IF ($OSName -contains '*Windows 8*') {
		Write-BISFLog -Msg "Running PreCommands for $OSName" -ShowConsole -Color Cyan
		Pre-Win8
	}

	## OS Windows 2012 R2
	IF (($OSVersion -like "6.3*") -and ($ProductType -eq "3")) {
		Write-BISFLog -Msg "Running PreCommands for $OSName ($OSVersion)" -ShowConsole -Color Cyan
		Pre-Win2012R2
	}

	## OS Windows Server 2016 and higher
	IF (($OSVersion -like "10*") -and ($ProductType -eq "3")) {
		Write-BISFLog -Msg "Running PreCommands for $OSName ($OSVersion)" -ShowConsole -Color Cyan
		Pre-Win2016
	}

	## OS Windows 10
	IF (($OSVersion -like "10*") -and ($ProductType -eq "1")) {
		Write-BISFLog -Msg "Running PreCommands for $OSName ($OSVersion)" -ShowConsole -Color Cyan
		Pre-Win10
	}

	PreCommand
	Clear-EventLog
	Test-DrvLabel
	Create-AllusersStartmenuPrograms
	Create-BISFTask
	Invoke-DesktopShortcut

}
End {
	Add-BISFFinishLine
}