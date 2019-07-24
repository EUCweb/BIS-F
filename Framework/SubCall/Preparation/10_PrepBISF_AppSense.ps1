<#
    .Synopsis
     Prepare AppSense Agent for Image Management
    .Description
      lookup for the AppSense Client Communications Agent and prepare the Agent for Imaging
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Matthias Schlimm
      Editor: Matthias Schhlimm
      Company: Login Consultants Germany GmbH

      History
      Last Change: 22.03.2016 MS: Script created
	  Last Change: 28.06.2017 MS: Bugfix 186 - AppSense Product Path - thx to Matthias Kowalkowski
	  .Link
    #>

Begin{
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Product = "AppSense"
	$product_path = "${env:ProgramFiles}\AppSense\Management Center\Communications Agent"
	$PrepApp = "CcaCmd.exe"
	$servicename = "AppSense Client Communications Agent"
}

Process {
	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc -eq $true)
	{
		Write-BISFLog -Msg "Preperaring $Product for Imaging" -ShowConsole -Color DarkCyan -SubMsg
		IF (Test-Path ("$product_path\$PrepApp") -PathType Leaf )
		{
			Write-BISFLog -Msg "Preparing $Product for Imaging "
			& Start-Process -FilePath "$product_path\$PrepApp" -ArgumentList "/imageprep" -Wait
		} ELSE {
			Write-BISFLog -Msg "$product_path\$PrepApp not exists. Image Preparation could not be performed !!!" -Type E -SubMsg
		}

	}
}


End {
	Add-BISFFinishLine
}
