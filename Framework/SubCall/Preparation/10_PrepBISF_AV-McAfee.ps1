<#
	.SYNOPSIS
		Prepare McAfee Agent for Image Managemement
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History
		10.12.2014 JP: Script created
		15.12.2014 JP: Added automatic virus definitions updates
		06.02.2015 MS: Reviewed script
		19.02.2015 MS: Fixed some errors and add progress bar for running scan
		01.10.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		05.01.2017 JP: Added maconfig.exe See https://community.mcafee.com/external-link.jspa?url=https%3A%2F%2Fkc.mcafee.com%2Fresources%2Fsites%2FMCAFEE%2Fcontent%2Flive%2FPRODUCT_DOCUMENTATION%2F25000%2FPD25187%2Fen_US%2Fma_500_pg_en-us.pdf
		& https://kc.mcafee.com/corporate/index?page=content&id=KB84087
		10.01.2017 MS: Added Script to BIS-F for McAfee 5.0 Support, thx to Jonathan Pitre
		11.01.0217 MS: $reg_agent_version = move (Get-ItemProperty "$reg_agent_string").AgentVersion after Product Installation check, otherwise error in POSH Output RegKey does not exist
		13.01.2017 FF: Search for maconfig.exe under x86 and x64 Program Files
		01.18.2017 JP: Added the detected agent version in the log message
		06.03.2017 MS: Bugfix read Variable $varCLI = ...
		08.01.2017 JP: Fixed typos
		15.10.2018 MS: Bugfix 58 - remove hardcoded maconfig.exe path
		28.03.2019 MS: FRQ 83 - Supporting McAfee Move integration (thanks to Torsten Witsch)
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		15.08.2019 MS: FRQ 88 - Supporting McAfee Endpoint Security (thanks to Wing2005)
		15.08.2019 MS: Added .SYNOPSIS to all functions and using recommended POSH Verbs for functions too
		03.10.2019 MS: ENH 51 - ADMX Extension: select AnitVirus full scan or custom Scan arguments
		23.05.2020 MS: HF 214 - McAfee MOVE Self Protection blocks the modification of the registry


	.LINK
		https://eucweb.com
#>

Begin {
	$Script_Path = $MyInvocation.MyCommand.Path
	$Script_Dir = Split-Path -Parent $Script_Path
	$Script_Name = [System.IO.Path]::GetFileName($Script_Path)

	# Product specified
	$Product = "McAfee VirusScan Enterprise"
	$Product2 = "McAfee Agent"
	$reg_product_string = "$hklm_sw_x86\Network Associates\ePolicy Orchestrator\Agent"
	$reg_agent_string = "$hklm_sw_x86\McAfee\Agent"
	$Product_Path = "$ProgramFilesx86\McAfee\VirusScan Enterprise"
	$ServiceName1 = "McAfeeFramework"
	$ServiceName2 = "McShield"
	$ServiceName3 = "McTaskManager"
	$PrepApp = "maconfig.exe"

	#Wing2005 - added 2 new paths to check
	$PrepAppSearchFolder = @("${env:ProgramFiles}\McAfee\Common Framework", "${env:ProgramFiles(x86)}\McAfee\Common Framework", "${env:ProgramFiles}\McAfee\Agent", "${env:ProgramFiles(x86)}\McAfee\Agent")

	[array]$reg_product_name = "AgentGUID"
	[array]$reg_product_name += "MacAddress"
	[array]$reg_product_name += "ComputerName"
	[array]$reg_product_name += "IPAddress"
	[array]$reg_product_name += "LastASCTime"
	[array]$reg_product_name += "SequenceNumber"
	[array]$reg_product_name += "SubnetMask"

	#McAfee MOVE with installed agent
	$ServiceName10 = "mvagtsvc"
	$Product10 = "McAfee MOVE"
	$HKLMAgent10path1 = "$HKLM_sw_x86\Network Associates\ePolicy Orchestrator\Agent"
	$HKLMAgent10key1 = "AgentGUID"
	$HKLMAgent10path2 = "HKLM:\SYSTEM\CurrentControlSet\Services\mvagtdrv\Parameters"
	$HKLMAgent10key2_1 = "ServerAddress1"
	$HKLMAgent10key2_2 = "ServerAddress2"
	$HKLMAgent10key2_3 = "ODSUniqueId"

	## McAfee Endpoint Security Detection
	$Product20 = "McAfee Endpoint Security"
	$Product_Path20_1 = "$env:ProgramFiles\McAfee\Endpoint Security\Endpoint Security Platform"
	$Product_Path20_2 = "$env:ProgramFiles\McAfee\Endpoint Security\Threat Prevention"

}

Process {

	####################################################################
	####### Functions #####
	####################################################################

	Function Start-DefUpdates {
		<#
		.SYNOPSIS
		Update McAfee AV pattern Files

		.DESCRIPTION
		Long description

		.PARAMETER engine
		Parameter description

		.EXAMPLE
		Update Pattern Files for McAfee Virus Scan Enterprise (VSE)
		Start-DefUpdates -engine $product

		.EXAMPLE
		Update Pattern Files for McAfee Endpoint Security (ENS)
		Start-DefUpdates -engine $product20

		.NOTES
		Author: Matthias Schlimm

		History:
			15.12.2014 JP: Added automatic virus definitions updates
			28.04.2019 wing2005: Added Parameter - due to change in update mchanism
			18.02.2020 JK: Fixed Log output spelling

		#>


		param(
			[parameter(Mandatory = $true)]$engine
		)
		Invoke-BISFService -ServiceName "$ServiceName1" -Action Start
		Write-BISFLog -Msg "Updating virus definitions...please wait"
		switch ($engine) {
			$Product {
				Start-Process -FilePath "$Product_Path\mcupdate.exe" -ArgumentList "/update /quiet"
				Show-BISFProgressBar -CheckProcess "mcupdate" -ActivityText "$engine is updating the virus definitions...please wait"
				Start-Sleep -s 3
			}
			$Product20 {
				#ENS
				Start-Process -FilePath "$Product_Path20_2\amcfg.exe" -ArgumentList "/update"
				Show-BISFProgressBar -CheckProcess "amcfg" -ActivityText "$engine is updating the virus definitions...please wait"
				Start-Sleep -s 3
			}
		}
	}

	Function Start-AVScan {
		<#
		.SYNOPSIS
		Starting a AV Scan on the system

		.DESCRIPTION
		before image sealing it's vendor beste practices to start a full scan
		to prevent performance bottlenecks and got a full scanned image

		.EXAMPLE
		Start-AVScan

		.NOTES
		Author: Matthias Schlimm

		History:
			10.12.2014 MS: script created
			14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
			03.10.2019 MS: ENH 51 - ADMX Extension: select AnitVirus full scan or custom Scan arguments

		#>


		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLI = $LIC_BISF_CLI_AV
		If (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
			Write-BISFLog -Msg "GPO Valuedata: $varCLI"
		}
		Else {
			Write-BISFLog -Msg "GPO not configured.. using default setting" -SubMsg -Color DarkCyan
			$AVScan = "YES"
		}
		If (($AVScan -eq "YES" ) -or ($varCLI -eq "YES")) {
			IF ($LIC_BISF_CLI_AV_VIE_CusScanArgsb -eq 1) {
				Write-BISFLog -Msg "Enable Custom Scan Arguments"
				$args = $LIC_BISF_CLI_AV_VIE_CusScanArgs
			}
			ELSE {
				$args = "c:\"
			}

			Write-BISFLog -Msg "Running Scan with arguments: $args"
			Start-Process -FilePath "$Product_Path\Scan32.exe" -ArgumentList $args
			If ($OSBitness -eq "32-bit") { $ScanProcess = "Scan32" } Else { $ScanProcess = "Scan64" }
			Show-BISFProgressBar -CheckProcess "$ScanProcess" -ActivityText "$Product is scanning the system...please wait"
		}
		Else {
			Write-BISFLog -Msg "No Scan will be performed"
		}

	}

	Function Remove-VSEData {
		<#
		.SYNOPSIS
		Remvoving MacAfee VirusScan Enterprise Agent Data

		.DESCRIPTION
		For Image sealing it's necassary to delete vendor recommended files, registryitems

		.EXAMPLE
		Remove-VSEData

		.NOTES
		Author: Matthias Schlimm

		History:
			10.12.2014 MS: script created

		#>

		If ($reg_agent_version -lt "5.0") {
			Invoke-BISFService -ServiceName "$ServiceName1" -Action Stop
			Invoke-BISFService -ServiceName "$ServiceName2" -Action Stop
			Invoke-BISFService -ServiceName "$ServiceName3" -Action Stop
			ForEach ($key in $reg_product_name) {
				Write-BISFLog -Msg "Delete specIfied registry items in $reg_product_string..."
				Write-BISFLog -Msg "Delete $key"
				Remove-ItemProperty -Path $reg_product_string -Name $key -ErrorAction SilentlyContinue
			}
		}
		If ($reg_agent_version -ge "5.0") {

			$found = $false
			Write-BISFLog -Msg "Searching for $PrepApp on the system" -ShowConsole -Color DarkCyan -SubMsg

			# Wing2005 - FIX: -Path parameter (was with quotes)
			$PrepAppExists = Get-ChildItem -Path $PrepAppSearchFolder -filter "$PrepApp" -ErrorAction SilentlyContinue | % { $_.FullName }

			IF (($PrepAppExists -ne $null) -and ($found -ne $true)) {

				If (Test-Path ("$PrepAppExists") -PathType Leaf ) {
					Write-BISFLog -Msg "$PrepApp found in $PrepAppExists" -ShowConsole -Color DarkCyan -SubMsg
					Write-BISFLog -Msg "Removed $Product GUID"
					$found = $true
					& Start-Process -FilePath "$PrepAppExists" -ArgumentList "-enforce -noguid" -Wait
				}
			}
		}
	}

	Function Remove-Agent10Data {
		<#
		.SYNOPSIS
		Remove MCAfee Move Agent data

		.DESCRIPTION
		For Image sealing it's necassary to delete vendor recommended files, registryitems

		.EXAMPLE
		Remove-Agent10Data

		.NOTES
		Author: Matthias Schlimm

		History:
			28.03.2019 MS: script created
			23.05.2020 MS: HF 214 - McAfee MOVE Self Protection blocks the modification of the registry
		#>

		powershell -command "mvadm config set IntegrityEnabled=0"

		Write-BISFLog -Msg "Remove Registry $HKLMAgent10path1 - Key $HKLMAgent10key1" -ShowConsole -Color DarkCyan -SubMsg
		Remove-ItemProperty -Path $HKLMAgent10path1 -Name $HKLMAgent10key1 -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "Update Registry $HKLMAgent10path2 - Key $HKLMAgent10key2_1"
		Set-ItemProperty -Path $HKLMAgent10path2 -Name $HKLMAgent10key2_1 -value "" -Force

		Write-BISFLog -Msg "Update Registry $HKLMAgent10path2 - Key $HKLMAgent10key2_2"
		Set-ItemProperty -Path $HKLMAgent10path2 -Name $HKLMAgent10key2_2 -value "" -Force

		Write-BISFLog -Msg "Update Registry $HKLMAgent10path2 - Key $HKLMAgent10key2_3"
		Set-ItemProperty -Path $HKLMAgent10path2 -Name $HKLMAgent10key2_3 -value "" -Force

		powershell -command "mvadm config set IntegrityEnabled=7"

	}

	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program

	# Discovering McAfee Virus Scan Enterprise (VSE)
	If (Test-Path ("$Product_Path\shstat.exe") -PathType Leaf) {
		Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
		$reg_agent_version = (Get-ItemProperty "$reg_agent_string").AgentVersion
		Write-BISFLog -Msg "Product $Product2 $reg_agent_version installed" -ShowConsole -Color Cyan
		Start-DefUpdates -engine $Product
		Start-AVScan
		Remove-VSEData
	}
	Else {
		Write-BISFLog -Msg "Product $Product NOT installed"
	}

	#Discovering McAfee Move
	$svc = Test-BISFService -ServiceName $servicename10 -ProductName "$product10"
	IF ($svc -eq $true) {
		Write-BISFLog -Msg "Information only: Unselect 'Enable Selfprotection' on the McAfee Management Server and/or in the Policy for MOVE AV Common" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "Perform an On Demand Scan (ODS) before you run this script to build up the cache"
		Remove-Agent10Data
	}

	#Discovering McAfee Endpoint Security (ENS)
	IF (Test-Path ("$Product_Path20_1\mfeesp.exe") -PathType Leaf) {
		Write-BISFLog -Msg "Product $Product20 installed" -ShowConsole -Color Cyan
		$reg_agent_version = (Get-ItemProperty "$reg_agent_string").AgentVersion
		Write-BISFLog -Msg "Product $Product20 $reg_agent_version installed" -ShowConsole -Color Cyan
		Start-DefUpdates -engine $Product20
		#wing2005 - Disabled Scan From Commandline not supported yet (will be in ENS 10.7)
		#Start-AVScan
		Remove-VSEData
	}
	Else {
		Write-BISFLog -Msg "Product $Product20 is NOT installed"
	}

}

End {
	Add-BISFFinishLine
}