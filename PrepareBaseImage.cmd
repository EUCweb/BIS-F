@echo off
REM *********************************************
REM *                                           *
REM *        Prepare your BaseImage             *
REM *                                           *
REM *                                           *
REM *        Created : 27.02.2013               *
REM *        Author: Matthias Schlimm           *
REM *        Website: EUCweb.com                *
REM *********************************************
REM Comments:
REM Prepare your Base Image for Microsoft, VMware and Citrix Environments

PushD "%~dp0"
color 17
mode con: cols=190 lines=60
echo initialize script environment... please wait
SET Files.PT=%~dp0framework
Powershell.exe -command "set-executionpolicy bypass" >NUL
echo Administrative permissions required. Detecting permissions...
net session >nul 2>&1
if %errorLevel% == 0 (
	echo Success: Administrative permissions confirmed.
	Powershell.exe -WindowStyle Maximize -file "%Files.PT%\PrepBISF_Start.ps1"
	REM Note: For silent automation please use the additional ADMX template in the BIS-F installation folder and copy them to your PolicyDefintions folder
) else (
				color 4F
		echo Failure: Current permissions inadequate.
		echo Close this window and run with aministrative permissions again !!
		pause >nul
		)

	PopD

REM History:   
REM 27.02.2013 MS: Script created
REM 17.09.2013 MS: @echo off and set Windows Title
REM 10.03.2014 MS: Changed Console Windows Size mode con: cols=120 lines=60
REM 19.03.2014 MS: Changed Console Windows Size mode con: cols=160 lines=60
REM 21.03.2014 MS: Changed Console Windows Size mode con: cols=190 lines=80
REM 26.03.2014 MS: Changed Console Windows Size mode con: cols=190 lines=60
REM 01.04.2014 MS:	Removed title
REM 13.05.2014 MS: Added silent mode parameters
REM 11.06.2014 MS: Changed ExecutionPolicy from unrestricted to RemoteSigned
REM 06.08.2014 MS: Supressed message for set-executionpolicy remoteSigned
REM 14.08.2014 MS: Changed name from PrepareXAforPVS.cmd to PrepareBaseImage.cmd
REM 17.08.2014 MS: Added CLI command for Citrix Personal vDisk
REM 10.02.2015 MS: Added CLI command for CCleaner to clean temp files
REM 10.02.2015 MS: Added Smanytec Endpoint Protection VIEScan silent option to flag the scanned files
REM 13.02.2015 MS: Added CLI command Reset Performance Counters 'RstPerfCnt''
REM 15.04.2015 MS: Added CLI command to shutdown or not the Base Image after successfull convert -shutdown NO (if script running from MDT or SCCM shutdown would be suppressed)
REM 28.05.2015 MS: Added CLI command 'VerySilent' to suppress all MessageBoxes
REM 03.06.2015 MS: Added CLI command 'FSXdelRules' to purge the FSLogix Rules from CLI
REM 13.08.2015 MS: Added CLI command 'FSXRulesShare' to define fsLogix central rules share, to copy frx and fra files on computerstartup
REM 21.08.2015 MS: Change Request 77 - remove all XX,XA,XD from al files and Scripts
REM 04.11.2015 MS: Added CLI command 'delAllUsersStartmenu' to delete all Objects in C:\ProgramData\Microsoft\Windows\Start Menu\*
REM 16.12.2015 MS: Added CLI command 'DisableIPv6' to disable IPv6 completly
REM 07.01.2016 MS: Changed ExecutionPolicy from unrestricted to Bypass
REM 10.03.2016 MS: Added CLI Switch 'DisableConsoleCheck' to disable the check of the Sessiontype
REM 16.03.2016 MS: Added CLI command 'LogShare' to set Central LogShare
REM 17.03.2016 MS: Added CLI command 'TurboUpdate' to update Turbo.net Supscription on system startup
REM 17.03.2016 MS: Added CLI command 'DelProf' to delete unused profiles, delprof2.exe must be download first and save in the BIS-F Tools Folder
REM 06.10.2016 MS: Change 10_MAIN_PrepBISF.ps1 to PrepBISF_Start.ps1, global architectural change
REM 23.11.2016 MS: Added CLI command 'vmOSOT' to run Vmware OS Optimization Tool with default template, if detected in any folder on the local system (drive c: only)
REM 23.11.2016 MS: Added CLI command 'WEMAgentBrokerName' to set the Citrix Workspace Environment Agent BrokerName if not configured via GPO
REM 06.12.2016 MS: WindowStyle Maximize
REM 10.01.2017 MS: Added CLI command 'XAImagePrepRemoval' during Prepare XenApp for Provisioning/Image Management you can choose RemoveCurrentServer and ClearLocalDatabaseInformation, this would be set with this Parameter or prompted to administrator to choose
REM 10.01.2017 MS: Added CLI command 'AppVPckRemoval' to delete PreCached App-V packages
REM 11.01.2017 MS: Added Cli command 'RESWASdisableBaseImage' to disable RES ONE Automation Agent on Base Image only to prevent RES ONE License usage for your Base Iamges
REM 02.02.2017 MS: Remove CLI command, using ADMX ADMX-File in the BIS-F installation folder and copy them to your PolicyDefintions
REM 21.02.2017 MS: checking admin privileges before run script
REM *********************************************