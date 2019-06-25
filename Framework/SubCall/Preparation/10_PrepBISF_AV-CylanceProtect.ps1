<#
    .SYNOPSIS
        Prepare Cylance PROTECT Agent for Image Managemement
	.DESCRIPTION
      	Delete computer specific entries
    .EXAMPLE
    .NOTES
		Author:  Mathias Kowalkowski
		Company: SVA System Vertrieb Alexander GmbH

		History
        09.05.2019 MK: Script created
	.LINK
        https://eucweb.com
#>

Begin {
	$Script_Path = $MyInvocation.MyCommand.Path
	$Script_Dir = Split-Path -Parent $Script_Path
	$Script_Name = [System.IO.Path]::GetFileName($Script_Path)

	# Product specific parameters
    $ProductName = "Cylance PROTECT"
    $ProductPath = "${env:ProgramFiles}\Cylance\Desktop"
    $ServiceName= "CylanceSvc"
	[array]$ToDelete = @(
		[pscustomobject]@{type="REG";value="HKLM:\SOFTWARE\Cylance\Desktop";data="FP"},
		[pscustomobject]@{type="REG";value="HKLM:\SOFTWARE\Cylance\Desktop";data="FPMask"},
		[pscustomobject]@{type="REG";value="HKLM:\SOFTWARE\Cylance\Desktop";data="FPVersion"},
		[pscustomobject]@{type="REG";value="HKLM:\SOFTWARE\Cylance\Desktop";data="SelfProtectionLevel"}
	)
}

Process {

    ####################################################################
	####### Functions #####
	####################################################################

	function DeleteData
    {
		Write-BISFLog -Msg "Delete specified items "	
		Foreach ($DeleteItem in $ToDelete)
		{
			IF ($DeleteItem.type -eq "REG")
			{
				Write-BISFLog -Msg "Processing registry item to delete" -ShowConsole -SubMsg -color DarkCyan
				$VerifyRegistryItem = Test-BISFRegistryValue -Path $DeleteItem.value -Value $DeleteItem.data
				IF ($VerifyRegistryItem) {
					Write-BISFLog -Msg "Deleting registry item -Path($DeleteItem.value) -Name($DeleteItem.data)"
					Remove-ItemProperty -Path $DeleteItem.value -Name $DeleteItem.data -ErrorAction SilentlyContinue
				}
			}
			
			IF ($DeleteItem.type -eq "FILE")
			{
				Write-BISFLog -Msg "Processing file item to delete" -ShowConsole -SubMsg -color DarkCyan
				$FullFileName = "$DeleteItem.value\$DeleteItem.data"
				IF (Test-Path ($FullFileName) -PathType Leaf)
				{
					Write-BISFLog -Msg "Deleting File $FullFileName"
					Remove-Item $FullFileName | Out-Null
				}
			}
		}
	}
    function StopService
    {
        $svc = Test-BISFService -ServiceName "$ServiceName"
        IF ($svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop }
    }


	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program
    $svc = Test-BISFService -ServiceName $ServiceName -ProductName $ProductName
    If ($svc -eq $true) {
        Write-BISFLog -Msg "Product $ProductName installed" -ShowConsole -Color Cyan
        StopService
        DeleteData
	} Else {
		Write-BISFLog -Msg "Product $ProductName NOT installed"
	}
}

End {
	Add-BISFFinishLine
}