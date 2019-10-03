<#
	.SYNOPSIS
		Prepare uberAgent for Image Management
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company:  EUCWeb.com

		History:
		26.04.2016 MZ: Script created
		09.01.2017 MS: Implemented in BIS-F, thx to Marco Zimmermann (MZ)
		12.01.2017 MS: Added IF (Test-Path $reg_Product_Key) before continue
		18.01.2017 JP: Fixed typo in product variable
		28.01.2017 MS: typo in $PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)

	.LINK
		https://eucweb.com
#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)

	$Product = "uberAgent"
	$servicename = "uberAgentSvc"
	$reg_Product_Key = "$HKLM_sw\vast limits\uberAgent"
}

Process {

	$svc = Test-BISFService -ServiceName $servicename -ProductName $product
	IF ($svc) {
		Invoke-BISFService -ServiceName $servicename -Action Stop -StartType automatic
		Write-BISFLog -Msg Clear $Product config
		IF (Test-Path $reg_Product_Key) {
			& Remove-Item '$reg_Product_Key' -Recurse -Force
			Write-BISFLog -Msg "Clean $Product registry $reg_Product_Key deleted"
		}
	}
}

End {
	Add-BISFFinishLine
}