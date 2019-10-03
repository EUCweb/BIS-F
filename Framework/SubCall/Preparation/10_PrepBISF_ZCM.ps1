[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		Prepare ZCM Agent for Imaging on Base Image
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Company:  EUCWeb.com

		History:
		27.05.2015 MS: Script created
		01.10.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		12.03.2017 MS: Change $tmparray=$LIC_BISF_ZCM_CFG to $tmparray=$LIC_BISF_CLI_ZCM to configure ZCM with ADMX


	.LINK
		https://eucweb.com
#>

Begin {

	####################################################################
	# define environment

	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

	# Product specified
	$Product = "Novell ZCM Agent"
	$product_path = $env:zenworks_home
	$servicename1 = "Novell ZENworks Agent Service"
	$servicename2 = "Novell Identity Store"
	$servicename3 = "nzwinvnc"
	$file1 = "$product_path\logs\preboot\novell-zisdservice.log"
	$file2 = "DeviceData", "DeviceGUID", "*.sav", "Guid.txt"
	$file3 = "initial-web-service"
	$folder1 = "$product_path\cache\zmd\"
	$reg_string1 = "$hklm_software\Wow6432Node\Novell\ZCM\PreAgent"
	$reg_string2 = "$hklm_software\Wow6432Node\Novell\ZCM\Remote Management\Agent"
}

Process {

	####################################################################

	function PrepareAgent {

		If ($servicename1.Status -eq 'Running') {
			Write-BISFLog -Msg "$Product Service is running, execute specified zac commands"
			$tmparray = $LIC_BISF_ZCM_CFG
			Write-BISFLog -Msg "get username and password from configuration URL"
			$tmparray = $tmparray.split(" ")
			$cnt = 0
			ForEach ($tmp in $tmparray) {
				IF ($tmp -eq "-u") {
					$ZCMusrCmd = $tmparray[$cnt]
					$ZCMusrVal = $tmparray[$cnt + 1]
					$ZCMusr = $ZCMusrCmd + " " + $ZCMusrVal
					Write-BISFLog -Msg "ZCM User for CLI command $ZCMusr"
				}

				IF ($tmp -eq "-p") {
					$ZCMpwdCmd = $tmparray[$cnt]
					$ZCMpwdVal = $tmparray[$cnt + 1]
					$ZCMpwd = $ZCMpwdCmd + " " + $ZCMpwdVal
					Write-BISFLog -Msg "ZCM Password for CLI command ********"
				}
				$cnt++
			}


			Start-Process "zac" -argumentlist "fsg -d"
			Start-Process "zac" -argumentlist "unr -f $ZCMusr $ZCMpwd"
			Start-Process "zac" -argumentlist "cc"

		}
		## stop Novell services
		Invoke-BISFService -ServiceName "$servicename1" -Action Stop
		Invoke-BISFService -ServiceName "$servicename2" -Action Stop
		Invoke-BISFService -ServiceName "$servicename3" -Action Stop


		#delete needed files and registry entries
		if (Test-Path -Path $file1 -PathType Leaf) {
			Write-BISFLog -Msg "delete file $file1"
			Remove-Item -path "$file1" -force
		}
		ELSE {
			Write-BISFLog -Msg "file $file1 NOT exist"
		}

		foreach ($file in $file2) {
			if (Test-Path -Path "$product_path\conf\$file" -PathType Leaf) {
				Write-BISFLog -Msg "delete file $product_path\conf\$file"
				Remove-Item -path "$product_path\conf\$file" -force
			}
			ELSE {
				Write-BISFLog -Msg "file $product_path\conf\$file NOT exist"
			}

		}
		Write-BISFLog -Msg "remove GUID from $reg_string1"
		Remove-ItemProperty -Path $reg_string1 -Name "GUID" -force -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "remove all custom entries from $reg_string2"
		Remove-Item -Path $reg_string2 -Exclude *Default*, *Device* -Recurse -Force -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "remove all items in folder $folder1"
		Remove-Item -Path $folder1 -Recurse -Force -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "Wipes the ZISD data including the ZISD header, see https://www.novell.com/support/kb/doc.php?id=7007665"
		& "$product_path\bin\preboot\ZISWin.exe" "-w"

		if (Test-Path -Path "$product_path\conf\$file3.bak" -PathType Leaf) {

			if (Test-Path -Path "$product_path\conf\$file3" -PathType Leaf) {
				Write-BISFLog -Msg "remove file $product_path\conf\$file3"
				Remove-Item -path "$product_path\conf\$file3" -force
			}
			Write-BISFLog -Msg "rename file $product_path\conf\$file3.bak"
			Rename-Item -path "$product_path\conf\$file3.bak" -newname "$product_path\conf\$file3" -Force
		}
		ELSE {
			Write-BISFLog -Msg "file $product_path\conf\$file3.bak NOT exist"
		}


	}

	#### Main Program

	$svc = Test-BISFService -ServiceName "$servicename1" -ProductName "$product"
	IF ($svc -eq $true) {
		PrepareAgent
	}

}

End {
	Add-BISFFinishLine
}