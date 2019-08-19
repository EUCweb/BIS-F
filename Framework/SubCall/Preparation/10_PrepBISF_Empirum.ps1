<#
	.SYNOPSIS
		Prepare Matrix 42 Empirum Agent for Image Management
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company: Login Consultants Germany GmbH

		History:
	  	16.09.2014 MS: Script created
		27.10.2014 MS: Fix wrong $cachelocation from XML-File (thx to David Rosenthal)
		12.12.2014 MS: syntax error at line 33
		30.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		28.05.2019 MK: added a more stable verification for the empirum services and $cachelocation\Packages\* to file removal

	.LINK
		https://eucweb.com
#>

Begin {
	$Empirum_path = "C:\Windows\System32\Empirum"
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$ServiceNames = @("Eris", "MATRIXAUT")
	$product = "Matrix42 Empirum"
}

Process {

	function StopService {
		ForEach ($ServiceName in $ServiceNames) {
			$svc = Test-BISFService -ServiceName "$ServiceName"
			IF ($svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop }
		}
	}
	function deleteAgentData {
		[xml]$xmlfile = Get-Content "$Empirum_path\AgentConfig.xml"
		$cachelocation = Select-Xml "//Transport/Protocols/CommonParameters/LocalCache[@Platform='Windows']" $xmlfile | % { $_.Node.'#text' }
		Write-Log -Msg "get cachelocation from XML-File $xmlfile $cachelocation"
		if ($cachelocation -match "(%.*%)\\") {
			$cachelocation = $cachelocation -replace "%(.*%)\\", "$(cmd /C echo $matches[0])"
		}
		Write-Log -Msg "remove Empirum Agent LocalCache in path $cachelocation" -Color Cyan
		Remove-Item "$cachelocation\DDC\Machine\*" -Force -Recurse
		Remove-Item "$cachelocation\DDC\User\*" -Force -Recurse
		Remove-Item "$cachelocation\DDS\*" -Force -Recurse
		Remove-Item "$cachelocation\Values\MachineValues\*" -Force -Recurse
		Remove-Item "$cachelocation\Values\UserValues\*" -Force -Recurse
		Remove-Item "$cachelocation\Packages\*" -Force -Recurse

		Write-Log -Msg "remove Empirum Agent specified registry entries" -Color Cyan
		Remove-Item "$hklm_sw\MATRIX42\AGENT" -Force -ErrorAction SilentlyContinue
		Remove-Item "$hklm_sw\MATRIX42\ApplicationUsageTracking" -Force -ErrorAction SilentlyContinue
		Remove-Item "$hklm_sw\MATRIX42\ComManager\CACHE\Items" -Force -ErrorAction SilentlyContinue
		Remove-Item "$hklm_sw\MATRIX42\EmpInv" -Force -ErrorAction SilentlyContinue
		Remove-Item "$hklm_sw\MATRIX42\Empirum Installer" -Force -ErrorAction SilentlyContinue
		Remove-Item "$hklm_sw\MATRIX42\RebootPackagesPending" -Force -ErrorAction SilentlyContinue
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	$svc = Test-BISFService -ServiceName $ServiceNames[0] -ProductName "$product"
	if ($svc -eq $true) {
		StopService
		DeleteAgentData
	}
}

End {
	Add-BISFFinishLine
}