[CmdletBinding(SupportsShouldProcess = $true)]
param( 
)
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
	

	
    ####################################################################
	
	function deleteOfficeIME
    {
        # Delete specified Data
	foreach ($path in $reg_IME_string) 
		{
			foreach ($key in $reg_IME_name)
			{
				Write-BISFLog -Msg "delete specified registry items in $($path)..."
				Write-BISFLog -Msg "delete $key"
				Remove-ItemProperty -Path $path -Name $key -ErrorAction SilentlyContinue
			}

		}

	} 
	
	
	####################################################################
}

Process {
    #### Main Program
	deleteOfficeIME

}

End {
    Add-BISFFinishLine	
}