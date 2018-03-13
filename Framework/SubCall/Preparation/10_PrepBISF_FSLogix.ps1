<#
.SYNOPSIS
  prepare FSLogix Apps for Image Management

.DESCRIPTION
  If the preperation ist starting, the script detects the installationn of FsLogix installation and ask to purge the Fslogix Rules on the Master Image 

.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES
  Version:        1.0
  Author:         Matthias Schlimm
  Creation Date:  03.06.2015
  Purpose/Change: 03.06.2015 MS: Initial script development
  Purpose/Change: 13.08.2015 MS: central rules share would be defined and stored in registry location to use it at computer startup
  Purpose/Change: 21.08.2015 MS: remove to set fsLogix service to manual, stopped service only.
  Purpose/Change: 30.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
  Purpose/Change: 06.03.2017 MS: Bugfix read Variable $varCLI = ...
  Purpose/Change: 15.02.2017 MS: Bugfix 237: When in the GPO specify "Configure FSLogix central rule share" to Disabled, the script still prompt for the path when is executed.

  
  
.EXAMPLE
 
#>

Begin {
	$ErrorActionPreference = "SilentlyContinue"
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Product = "FsLogix Apps"
	$product_path = "${env:ProgramFiles}\FSLogix\Apps"
	$servicename = "FSLogix Apps Services"
}

Process {
	function ClearConfig
    {
		Write-BISFLog -Msg "Check Silentswitch..."
	    $varCLIFS = $LIC_BISF_CLI_FS
	    IF (($varCLIFS -eq "YES") -or ($varCLIFS -eq "NO")) 
	    {
		    Write-BISFLog -Msg "Silentswitch would be set to $varCLIFS"
	    } ELSE {
       	    Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
		    $MPFS = Show-BISFMessageBox -Msg "Would you like to purge the FsLogix Rules folder ? Note: You must copied the $Product Rules via GPP or your prefered method to your cloned devices !" -Title "$Product" -YesNo -Question
    	    Write-BISFLog -Msg "$MPFS was selected [YES = purge FsLogix Rules] [NO = Skip rules deletion]"
	    }
        
		if (($MPFS -eq "YES" ) -or ($varCLIFS -eq "YES"))
	    {
		    Write-BISFLog -Msg "delete $product Rules" -ShowConsole -Color DarkCyan -SubMsg
		    Remove-Item -Path "$product_path\Rules\*" -Recurse
	    } ELSE {
		    Write-BISFLog -Msg "Skipping $product Rules deletion"
	    }
	}

    function Set-RulesShare
    {
        #set the fsLogix central rules share in the BIS-F registry location, to get on BIS-F personalisation on each device
        Write-BISFLog -Msg "Check Silentswitch..."
	    $varCLIRS = $LIC_BISF_CLI_RSb
	    IF ($varCLIRS -ne "")
	    {
		    Write-BISFLog -Msg "Silentswitch would be set to $varCLIRS"
            $fslogixRulesShare = $LIC_BISF_CLI_RS
	    } ELSE {
       	    Write-BISFLog -Msg "Silentswitch not defined, show Inputprompt to define UNC-Path, where the fslogix Rules (frx) and Assignments (fxa) would be stored"
            $MPRS = Show-BISFCustomInputBox -title "Fslogix Central Rules Share" -message "Please enter a central rules share, where do you stored the fsLogix Rules (frx) and Assignment (fxa) files. Enter a valid UNC-Path, that be accessible at computer startup with system account" ""
            $fslogixRulesShare = $MPRS
        }

        if ($fslogixRulesShare -ne "") 
	    {
		    Write-BISFLog -Msg "The fsLogix Central Rules Share would be set to $fslogixRulesShare" -ShowConsole -Color DarkCyan -SubMsg
            Write-BISFLog -Msg "set fsLogix Central Rules Share in the registry $hklm_software_LIC_CTX_BISF_SCRIPTS, Name LIC_BISF_FSXRulesShare, value $fslogixRulesShare"
            Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_FSXRulesShare" -value "$fslogixRulesShare" -Force
		    
	    } ELSE {
		    Write-BISFLog -Msg "No fsLogix Central Rules Share defined"
	    }
    }



	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc -eq $true)
	{
		Invoke-BISFService -ServiceName "$servicename" -Action Stop
		ClearConfig
		Set-RulesShare
	}
}

End {
	Add-BISFFinishLine
}