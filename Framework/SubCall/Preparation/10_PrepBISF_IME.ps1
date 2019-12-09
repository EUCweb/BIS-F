[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<<<<<<< HEAD
<#
	.SYNOPSIS
		Delete Office 2010 IME Keyboards from Autorun
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Benjamin Ruoff
		Company:  EUCWeb.com

		History
		26.10.2015 MS: Script created

	.LINK
		https://eucweb.com
#>

Begin {

	####################################################################
	# define environment

=======
    <#
    .Synopsis
      Delete Office 2010 IME Keyboards from Autorun
    .Description
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Benjamin Ruoff
      Edittor: Benjamin Ruoff
	  Company: Login Consultants Germany GmbH
      
      Date: 26.10.2015
      
      History
      Last Change: 26.10.2015 MS: Script created
      Last Change:

    .Link
    #>

Begin {

    ####################################################################
    # define environment
  
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

	# Product specified
	$Product = "Office IME Languages Clean-up"
	[array]$reg_IME_string = "$hklm_software\Microsoft\Windows\CurrentVersion\Run"
	[array]$reg_IME_string += "$hklm_software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"

	[array]$reg_IME_name = "IME14 JPN Setup"
	[array]$reg_IME_name += "IME14 KOR Setup"
	[array]$reg_IME_name += "IME14 CHS Setup"
	[array]$reg_IME_name += "IME14 CHT Setup"
<<<<<<< HEAD

	####################################################################

	function deleteOfficeIME {
		# Delete specified Data
		foreach ($path in $reg_IME_string) {
			foreach ($key in $reg_IME_name) {
=======
	

	
    ####################################################################
	
	function deleteOfficeIME
    {
        # Delete specified Data
	foreach ($path in $reg_IME_string) 
		{
			foreach ($key in $reg_IME_name)
			{
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
				Write-BISFLog -Msg "delete specified registry items in $($path)..."
				Write-BISFLog -Msg "delete $key"
				Remove-ItemProperty -Path $path -Name $key -ErrorAction SilentlyContinue
			}

		}

<<<<<<< HEAD
	}

=======
	} 
	
	
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
	####################################################################
}

Process {
<<<<<<< HEAD

	#### Main Program
=======
    #### Main Program
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
	deleteOfficeIME

}

End {
<<<<<<< HEAD
	Add-BISFFinishLine
=======
    Add-BISFFinishLine	
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
}