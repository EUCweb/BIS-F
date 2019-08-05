﻿Function Initialize-Configuration {
	<#
    .SYNOPSIS
        define global environment
	.Description
      	defines the global variables for using in the script framework
		use get-help <functionname> -full to see full help
    .EXAMPLE
		Initialize-BISFConfiguration

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 07.09.2015 MS: Added .SYNOPSIS to this function
		Last Change: 03.11.2015 MS: Removed function NimbleFastReclaim would be replaced with Write-ZeroesToFreeSpace
	    Last Change: 25.11.2015 MS: Changed WindowTitle from 2015 to 2016
	    Last Change: 16.12.2015 MS: Fixed code error 1133 Write-Progress "Done" "Done" -completed
		Last Change: 17.12.2015 MS: Bugfix :$ImageSW=$false would be set to false, wrong order
		Last Change: 07.01.2016 MS: Added Optimize-WinSxs
		Last Change: 07.01.2016 MS: Added Test-VMwareHorizonViewSoftware
		Last Change: 07.01.2016 MS: Function Invoke-Service: If No Image Management-Software would be detected, the Service Startup type would not changed to manual
	    Last Change: 20.01.2016 MS: Fixed wrong syntax to check if Image Management Software like VDA, PVS Target Device Driver or VMware View Agent is installed
		Last Change: 21.01.2016 MS: Added function Get-OSCSessionType to run BIS-F from console session only
        Last Change: 04.03.2016 MS: Fixed important bug in function invoke-service, servies would not started if needed
	    Last Change: 04.10.2016 MS: Changed $Global:CTX_BISF_SCRIPTS = "Citrix BISF Scripts" to $Global:CTX_BISF_SCRIPTS = "Login BIS-F"
		Last Change: 09.01.2017 MS: Created function Get-MacAddress
		Last Change: 19.01.2017 JP: Line 1898; Added -Wait parameter for Start-Process
		Last Change: 12.03.2017 MS: add $Global:Wait1= "10"  #global time in seconds
		Last Change: 05.09.2017 TT: added "MaximumExecutionTime" to Show-ProgressBar
		Last Change: 11.09.2017 MS: add $TaskStates to control the Preparation is running after Personlization first
	.Link
#>

    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	Write-BISFLog -Msg "Checking Prerequisites" -ShowConsole -color Cyan
    $Global:computer = gc env:computername
    $Global:cu_user = $env:username
    $Global:Domain = (Get-WmiObject -Class Win32_ComputerSystem).domain
    $Global:hklm_software = "HKLM:\SOFTWARE"
    $Global:hklm_system = "HKLM:\SYSTEM"
    $Global:hkcu_software= "HKCU:\Software"
	$Global:hku_software= "HKU:\.DEFAULT\Software"
	$Global:hklm_sw_pol = "HKLM:\SOFTWARE\Policies"
    $Global:LIC = "Login Consultants"
    $Global:CTX_BISF_SCRIPTS = "BISF"
    $Global:LogFolderName = "BISFLogs"
    $Global:FirstRun = $true
	$Global:hklm_software_LIC_CTX_BISF_SCRIPTS = "$hklm_software\$LIC\$CTX_BISF_SCRIPTS"
    $Global:FrameworkName = "Base Image Script Framework ($CTX_BISF_SCRIPTS)"
    $Global:BISFtitle = "$FrameworkName @ $LIC and EUCweb.com"
	$Host.UI.RawUI.WindowTitle = "$BISFtitle"
	$Global:Wait1= "10"  #global time in seconds
	$Global:Reg_LIC_Policies = "$hklm_sw_pol\$LIC\$CTX_BISF_SCRIPTS"
	$AppGuid="{A59AF8D7-4374-46DC-A0CD-8B9B50AFC32E}_is1"
	$HKLM_Uninstall="HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
	$Global:HKLM_Full_Uninsstall="$HKLM_Uninstall\$AppGuid"
	$Global:InstallLocation=(Get-ItemProperty "$HKLM_Full_Uninsstall" -Name "InstallLocation").InstallLocation
	Write-Log -Msg "Install location ""$InstallLocation"" " -ShowConsole -Color DarkCyan -SubMsg
    Import-BISFSharedConfiguration -Verbose:$VerbosePreference
	Get-BISFCLIcmd -Verbose:$VerbosePreference #must be running before the $Global:PVSDiskDrive = $LIC_BISF_CLI_WCD is set
	$Global:PVSDiskDrive = $LIC_BISF_CLI_WCD
	$Global:TaskStates= @("AfterInst","AfterPrep","Active","Finished")
}

	function Get-RegistryValues($key)
	{
		Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
        $values = (Get-Item $key).GetValueNames()
        [array]$result = @()
        Foreach ($value in $values) {
            $result += [pscustomobject]@{value="$value";data="$((Get-ItemProperty $key $value).$value)"}
        }
        return $result
    }


    function New-GlobalVariable {
            param (
            [string]$Name,
            [string]$Value
            )
			Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
            ## define new global variable
            New-Variable -Name $Name -Value $Value -option AllScope -Scope Global -Force
            Write-BISFLog -Msg "Define new global variable $Name=$Value"

        }


function Get-Adaptername {
	<#
    .SYNOPSIS
        read network name lice LAN-Connection, etc.
	.Description
      	read all dhcp networkadapter and give their names back
		use get-help <functionname> -full to see full help
    .EXAMPLE
		Get-BISFAdaptername

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 07.09.2015 MS: add .SYNOPSIS to this function

	.Link
#>
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$AdapterIndex = Get-WmiObject -Query "select * from win32_networkadapterconfiguration where DHCPEnabled = ""True"" and DNSHostName = ""$env:computername"" "
    IF (!($AdapterIndex -eq $null)) {
		foreach ($Adapter in $AdapterIndex) {
			$AdapterNr = $Adapter.Index
			$AdapterName = Get-WmiObject -Query "select NetConnectionID from win32_networkadapter where Index = ""$AdapterNr"" "
			[array]$AdapterNames += $AdapterName.NetConnectionID
		}
	} Else {
		write-BISFlog -Msg "No DHCP Networkadapter found. DHCP Networkadapter would be optimized only !" -Type W
		$AdapterNames = $null
	}
    return $AdapterNames

}

function Show-MessageBox {
	<#
    .SYNOPSIS
        Show messagebox
	.Description
      	Show mesaagebox inside the POSH framework for different scenarios
		use get-help <functionname> -full to see full help
    .EXAMPLE
		$MsgBox = Show-BISFMessageBox -Msg "your Question " -Title "Title" -YesNo -Question
		if ($MsgBox -eq "YES")
		{
			#YEs answer
		} ELSE {
			# No answer
		}

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 07.09.2015 MS: add .SYNOPSIS to this function

	.Link
		http://msdn.microsoft.com/en-us/library/system.windows.forms.messagebox.aspx
#>
	Param(
		[Parameter(Mandatory=$True)][Alias('M')][String]$Msg,
		[Parameter(Mandatory=$False)][Alias('T')][String]$Title = "",
		[Parameter(Mandatory=$False)][Alias('OC')][Switch]$OkCancel,
		[Parameter(Mandatory=$False)][Alias('OCI')][Switch]$AbortRetryIgnore,
		[Parameter(Mandatory=$False)][Alias('YNC')][Switch]$YesNoCancel,
		[Parameter(Mandatory=$False)][Alias('YN')][Switch]$YesNo,
		[Parameter(Mandatory=$False)][Alias('RC')][Switch]$RetryCancel,
		[Parameter(Mandatory=$False)][Alias('C')][Switch]$Critical,
		[Parameter(Mandatory=$False)][Alias('Q')][Switch]$Question,
		[Parameter(Mandatory=$False)][Alias('W')][Switch]$Warning,
		[Parameter(Mandatory=$False)][Alias('I')][Switch]$Informational
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	#Set Message Box Style
	IF($OkCancel){$Type = 1}
	Elseif($AbortRetryIgnore){$Type = 2}
	Elseif($YesNoCancel){$Type = 3}
	Elseif($YesNo){$Type = 4}
	Elseif($RetryCancel){$Type = 5}
	Else{$Type = 0}

	#Set Message box Icon
	If($Critical){$Icon = 16}
	ElseIf($Question){$Icon = 32}
	Elseif($Warning){$Icon = 48}
	Elseif($Informational){$Icon = 64}
	Else{$Icon = 0}

	If (!($LIC_BISF_CLI_VS) -or ($LIC_BISF_CLI_VS -eq $false))   #detect CLI switch 'verysilent' to suppress any messageboxes
	{
		#Loads the WinForm Assembly, Out-Null hides the message while loading.
		[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

		#Display the message with input
		$Answer = [System.Windows.Forms.MessageBox]::Show($MSG , $TITLE, $Type, $Icon)
	} ELSE {
		$Answer = "VerySilent"
	}
	#Return Answer
	Return $Answer

}

function Write-Log {
    <#
    .SYNOPSIS
        Write the Logfile
	.Description
      	Helper Function to Write Log Messages to Console Output and corresponding Logfile
		use get-help <functionname> -full to see full help
    .EXAMPLE
		write-BISFLog -Msg "Warining Text" -Type W
	.EXAMPLE
		write-BISFLog -Msg "Text would be shown on Console" -ShowConsole
	.EXAMPLE
		write-BISFLog -Msg "Text would be shown on Console in Cyan Color, information status" -ShowConsole -Color Cyan
	.EXAMPLE
		write-BISFLog -Msg "Error text, script would be existing automaticaly after this message" -Type E
	.EXAMPLE
		write-BISFLog -Msg "External log contenct" -Type L
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 07.09.2015 MS: add .SYNOPSIS to this function
        Last Change: 29.09.2015 MS: add switch -SubMSg to define PreMsg string on each console line
		Last Change: 21.11.2017 MS: if Error appears, exit script with Exit 1
	.Link
#>

	Param(
	    [Parameter(Mandatory=$True)][Alias('M')][String]$Msg,
        [Parameter(Mandatory=$False)][Alias('S')][switch]$ShowConsole,
	    [Parameter(Mandatory=$False)][Alias('C')][String]$Color = "",
        [Parameter(Mandatory=$False)][Alias('T')][String]$Type = "",
		[Parameter(Mandatory=$False)][Alias('B')][switch]$SubMsg
	)


	                     $LogType = "INFORMATION..."
    IF ($Type -eq "W" ) {$LogType = "WARNING........."; $Color ="Yellow"}
    IF ($Type -eq "L" ) {$LogType = "EXTERNAL LOG...."; $Color ="DarkYellow"}
    IF ($Type -eq "E" ) {$LogType = "ERROR..............."; $Color ="Red"}

	IF (!($SubMsg))
	{
		$PreMsg = "+"
	} ELSE {
		$PreMsg = "`t>"
	}

    $date = get-date -Format G
	Out-File -Append -Filepath $logfile -inputobject "$date | $env:username | $LogType | $Msg" -Encoding default

	IF ($LIC_BISF_CLI_DB -eq $true)
	{
		#Debug mode is enabled
        Write-Host "- - - DebugMode enabled: Press any key to continue - - -" -ForegroundColor White
        $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $VerbosePreference="Continue"
	}

	If (!($ShowConsole))
     {
        IF (($Type -eq "W") -or ($Type -eq "E" ))
        {
            IF ($VerbosePreference -eq 'SilentlyContinue')
            {
                Write-Host "$PreMsg $Msg" -ForegroundColor $Color
                $Color = $null
            }
        } ELSE {
			Write-Verbose -Message "$PreMsg $Msg"
			$Color = $null
        }

	} ELSE {
	    if ($Color -ne "")
        {
			IF ($VerbosePreference -eq 'SilentlyContinue')
            {
                Write-Host "$PreMsg $Msg" -ForegroundColor $Color
			    $Color = $null
		    }
        } else {
			Write-Host "$PreMsg $Msg"
		}
	}
    IF ($Type -eq "E" ) {$Global:TerminateScript = $true;start-sleep 30;Exit 1}
}


Function Invoke-FolderScripts {
    [CmdletBinding(SupportsShouldProcess = $true)]
	PARAM(
		[parameter(Mandatory=$True)][string]$Path,
		[parameter(Mandatory=$False)][switch]$Errorhandling
	)
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    write-BISFlog -Msg "Loading Scripts from $Path"
	$scripts = @(Get-ChildItem -Path $Path -Filter "*.ps1")
    write-verbose -message "$scripts"
	IF ($scripts -ne $null) {
		Foreach ($item in $scripts) {
			IF ($TerminateScript -eq $true) {
                write-BISFlog -Msg "Check Logfile $logfile for further informations !!" -Type W
                write-BISFlog -Msg "Script exiting !!" -Color Red
                start-sleep 5
                break
			} ELSE {
			write-BISFlog -Msg "Start script $($item.name)"
			}
            $rescode = . $item.FullName
            if ($Errorhandling) {
                If ($rescode -ne "Success") {
                   write-BISFlog -Msg "Error: $rescode in Script Execution, Check $item.log"  -Type E
                } else {
                   write-BISFlog -Msg "Script execution successfull"
                }
            }
		}
	}
}

function Test-WriteCacheDiskDriveLetter {
	<#
    .SYNOPSIS
        Test if the PVS WriteCacheDisk driveletter is configured
	.Description
      	Test if the PVS WriteCacheDisk driveletter is configured via ADMX
		use get-help <functionname> -full to see full help
    .EXAMPLE


    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 12.03.2017 MS: add .SYNOPSIS to this function
		Last Change: 12.03.2017 MS: configure WriteCacheDisk driveletter with ADMX or show error if PVS Target Device Driver is installed

	.Link
#>

    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function

	IF ($LIC_BISF_CLI_WCD -eq $null)
	{
		$title="Fatal Error !!!"
		$text="PVSWriteCacheDisk not configured with ADMX, configure it and run this script again..!! "
		Show-MessageBox -Title $title -Msg $text -Critical
		write-BISFlog -Msg $Text -Type E -SubMsg
		return $false
		break
	} ELSE {
        $Global:PVSDiskDrive = $LIC_BISF_CLI_WCD
		write-BISFlog -Msg "PVSWriteCacheDisk configured: $PVSDiskDrive" -ShowConsole -Color DarkCyan -SubMsg
		return $true
	}
}

function Get-PSVersion{
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$PShostMajor = $PSVersionTable.PSVersion.Major
	 write-BISFlog -Msg "Powershell Version $PShostMajor" -ShowConsole -Color DarkCyan -SubMsg
}

function Test-RegHive {
    # check RegHive if exist
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	IF (!(Test-Path $hklm_software\$LIC\$CTX_BISF_SCRIPTS)) {
	    New-Item -Path $hklm_software -Name $LIC -Force | Out-Null
	    New-Item -Path $hklm_software"\"$LIC -Name $CTX_BISF_SCRIPTS -Force | Out-Null
	    write-BISFlog -Msg "create RegHive $hklm_software\$LIC\$CTX_BISF_SCRIPTS"
	    return $true
    }
    ELSE {
	    write-BISFlog -Msg "Check RegHive $hklm_software\$LIC\$CTX_BISF_SCRIPTS"
	    return $false
    }
    write-BISFlog -Msg "Initialize $CTX_BISF_SCRIPTS ...$FirstRun"

}

function Test-WriteCacheDisk{
	<#
    .SYNOPSIS
        check PVSDiskDrive, if not abort script
	.Description
      	check PVSDiskDrive, if not abort script
		use get-help <functionname> -full to see full help
    .EXAMPLE


    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 12.03.2017 MS: add .SYNOPSIS to this function
	.Link
#>
    $Global:PVSDiskDrive = $LIC_BISF_CLI_WCD
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    $CacheDisk = Get-WmiObject -Query "SELECT * from win32_logicaldisk where DriveType = 3 and DeviceID = ""$PVSDiskDrive"""
    IF ($CacheDisk -eq $null) {
	    $title="Fatal Error !!!"
        $text="Disk $PVSDiskDrive not exist. Please create a local new harddrive with enough space, assign driveletter $PVSDiskDrive and run this script again..!!"
        Show-MessageBox -Title $title -Msg $text -Critical
		write-BISFlog -Msg $Text -Type E -SubMsg
        return $false
    } ELSE {
	    write-BISFlog -Msg "Check WriteCache Disk $PVSDiskDrive"
        return $true
    }

}

function Get-Version{
	<#
    .SYNOPSIS
        read the version number from the Manifest BISF.psd1
		and get the BuildNmber from the registry, that would be set from the installer
	.Description
      	Test if the PVS WriteCacheDisk driveletter is configured via ADMX
		use get-help <functionname> -full to see full help
    .EXAMPLE


    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 25.07.2017 MS: add .SYNOPSIS to this function
		Last Change: 25.07.2017 MS: replace $ReleaseType (that is manual change in the script to set Alpha, beta or prod release) with $LIC_BISF_BuildNumber.substring(0,2) to get the right DTAP Stage
		Last Change:

	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function

	$rootfolder = Split-Path -Path $Main_Folder -Parent
    IF ($mainmodulename -ne $null) {
		$ver = (Get-Module $mainmodulename).Version.ToString()
		$Global:BISFversion = "$ver build $LIC_BISF_BuildNumber"
		IF ($ExportSharedConfiguration) {$Host.UI.RawUI.WindowTitle = "$BISFtitle [2018 - $BISFversion] - ExportSharedConfiguration"} ELSE {$Host.UI.RawUI.WindowTitle = "$BISFtitle [2018 - $BISFversion]"}

	} ELSE {
		write-BISFlog -Msg "$FrameworkName Version could not get from Manifest" -Type W -SubMsg
	}

	$BuildNbr = $LIC_BISF_BuildNumber.substring(1,1)
	switch ($BuildNbr)
	{
		4 {Write-BISFLog -Msg "WARNING: This running version $BISFVersion is an DEVELOPER Release, not for production use !!" -Type W -SubMsg ; Start-Sleep $Wait1}
		3 {Write-BISFLog -Msg "WARNING: This running version $BISFVersion is an TEST Release, not for production use !!" -Type W -SubMsg ; Start-Sleep $Wait1}
		2 {Write-BISFLog -Msg "WARNING: This running version $BISFVersion is an BETA Release, User Acceptance Test only !!" -Type W -SubMsg ; Start-Sleep $Wait1}
		1 {Write-BISFLog -Msg "Running Version $BISFVersion" -ShowConsole -SubMsg -Color DarkCyan}
		default {Write-BISFLog -Msg "WARNING: BuildNumber could not be determined !!" -Type W -SubMsg ; Start-Sleep $Wait1}
	}

	$BuildDate_DD=$LIC_BISF_BuildDate.substring(0,2)
	$BuildDate_MM=$LIC_BISF_BuildDate.substring(2,2)
	$BuildDate_YY=$LIC_BISF_BuildDate.substring(4,2)
	$BuildDate_th=$LIC_BISF_BuildDate.substring(6,2)
	$BuildDate_tm=$LIC_BISF_BuildDate.substring(8,2)
	write-BISFlog -Msg "$FrameworkName $BISFversion | Date $($BuildDate_DD).$($BuildDate_MM).$($BuildDate_YY) | Time $($BuildDate_th):$($BuildDate_tm)"

}

function Set-NetworkProviderOrder {
	PARAM(
		[parameter(Mandatory=$True)][string]$SaerchProvOrder
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	#search for the entered ProviderOrder and set this to the last one
	$newproder = @()
	$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order'
	$value = 'ProviderOrder'
	$proder = (Get-ItemProperty $key $value).$value | % {$_.split(",")}
	$searchPrOrder = $SaerchProvOrder
	$SaveIndex = 0
	$Foundproder = 0

	write-BISFlog -Msg "Change the NetworkProviderOrder, look for entry $searchPrOrder"

	for ($i=0; $i -lt $proder.length; $i++) {
		IF ($proder[$i] -eq $searchPrOrder) {
        	$SaveIndex = $i
        	write-BISFlog -Msg "SearchString $searchPrOrder would be found in index $SaveIndex"
        	$Foundproder = 1
    	}
	}

	IF ($Foundproder -eq 0) {
		write-BISFlog -Msg "Warning: SearchString $searchPrOrder not found..."
		return $false
		break
	}

	for ($i=$SaveIndex; $i -lt $proder.length; $i++) {
    	$getarray = $i+1
    	IF ($getarray -eq $proder.count) {
        	$proder[$i] = $searchPrOrder
        	write-BISFlog -Msg "Set $searchPrOrder to the last index [$i]"
	    } ELSE {
   			$proder[$i] =  $proder[$getarray]
   			write-BISFlog -Msg "replace array index [$i] with index [$getarray]"
		}
 	}
	$writereg = ($proder | Select -Unique) -join ","

	Set-ItemProperty $key $value $writereg
	write-BISFlog -Msg "change the NetworkProviderOrder to $writereg"

}

function Test-PVSSoftware {
	<#
    .SYNOPSIS
        check if the PVS Target Device Driver installed
	.Description
      	if the PVS Target Device Driver installed they will send a true or false value and will set the global variable ImageSW to true or false
		use get-help <functionname> -full to see full help

	.EXAMPLE
		Test-BISFPVSSoftware
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 07.09.2015 MS: add .SYNOPSIS to this function

	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$svc = Test-BISFService -ServiceName "BNDevice" -ProductName "Citrix Provisioning Services Target Device Driver (PVS)"
	IF (($ImageSW -eq $false) -or ($ImageSW -eq $Null)) {IF ($svc -eq $true) { $Global:ImageSW=$true } }
	return $svc

}

function Test-XDSoftware{
	<#
    .SYNOPSIS
        check if the XenDesktop VDA installed
	.Description
      	if the XenDesktop VDA installed they will send a true or false value and will set the global variable ImageSW to true or false
		use get-help <functionname> -full to see full help

	.EXAMPLE
		Test-XDSoftware
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 07.09.2015 MS: add .SYNOPSIS to this function

	.Link
#>
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$svc = Test-BISFService -ServiceName "BrokerAgent" -ProductName "Citrix XenDesktop Virtual Desktop Agent (VDA)"
	IF (($ImageSW -eq $false) -or ($ImageSW -eq $Null)) {IF ($svc -eq $true) { $Global:ImageSW=$true } }
	return $svc

}

function Get-OSinfo{
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    $win32OS = Get-WmiObject Win32_OperatingSystem
    $Global:OSName = $win32OS.caption
    $Global:OSBitness = $win32OS.OSArchitecture
    $Global:OSVersion = $win32OS.version
    $Global:Muilang = $win32OS.MUILanguages
    $Global:ProductType = $win32OS.ProductType
    write-BISFlog -Msg "Operating System: $OSName"
    write-BISFlog -Msg "Architecture: $OSBitness"
    write-BISFlog -Msg "Version: $OSversion"
    write-BISFlog -Msg "ProductType: $ProductType [1=Client, 2=DomainController, 3=MemberServer]"
    write-BISFlog -Msg "Language: $MUIlang"

    IF ($OSBitness -eq "32-bit") {
        $Global:ProgramFilesx86 = "${env:ProgramFiles}"
        $Global:CommonProgramFilesx86 = "${env:CommonProgramFiles}"
		$Global:HKLM_sw_x86 = "$hklm_software"
    } ELSE {
        $Global:ProgramFilesx86 = "${env:ProgramFiles(x86)}"
        $Global:CommonProgramFilesx86 = "${env:CommonProgramFiles(x86)}"
		$Global:HKLM_sw_x86 = "$hklm_software\Wow6432Node"
    }
    write-BISFlog -Msg "ProgramFiles X86 Path would be set: $ProgramFilesx86"
    write-BISFlog -Msg "CommonProgramFiles X86 would be set to: $CommonProgramFilesx86"
	write-BISFlog -Msg "HKLM_sw_x86 would be set to: $HKLM_sw_x86"

}

function Show-ProgressBar{
	<#
    .SYNOPSIS
        show Powershell ProgressBar
	.Description
      	Show Powershell Progressbar to see something is working in the background, it checks an active process
		use get-help <functionname> -full to see full help
	.PARAMETER CheckProcess
        A process object to pass to the function. This can be retrieved with "Get-Process" and stored as a variable
    .PARAMETER CheckProcessId
        A process ID that the function will check against.
    .PARAMETER ActivityText
        Text that describes what the progress bar is waiting on.
    .PARAMETER MaximumExecutionMinutes
        The amount of time in minutes that the function will wait before continuing.
    .PARAMETER TerminateRunawayProcess
        If the maximum execution time is exceeded this switch will foricbly terminate the process.
	.EXAMPLE
		Show-BISFProgressbar
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 28.06.2017 MS: add .SYNOPSIS to this function
		Last Change: 22.06.2017 FF: add ProgressID to this function to use it instead of ProgressName only
	    Last Change: 31.08.2017 MS: POSH Progressbar, sleep time during preparation only
		Last Change: 05.09.2017 TT: Added Maximum Execution Minutes and Terminate Runaway Process parameters
	.Link
#>
    PARAM(
		[parameter()][string]$CheckProcess,
        [parameter()][int]$CheckProcessId,
		[parameter(Mandatory=$True)][string]$ActivityText,
		[parameter()][int]$MaximumExecutionMinutes,
        [parameter()][switch]$TerminateRunawayProcess
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    $a=0
	if ($MaximumExecutionMinutes) {
		$MaximumExecutionTime = (Get-Date).AddMinutes($MaximumExecutionMinutes)
	} ELSE {
        $MaximumExecutionMinutes = 60
        $MaximumExecutionTime = (Get-Date).AddMinutes($MaximumExecutionMinutes)
    }
	Start-Sleep 5
    for ($a=0; $a -lt 100; $a++) {
		IF ($a -eq "99") {$a=0}
		If ($CheckProcessId)
		{
			$ProcessActive = Get-Process -Id $CheckProcessId -ErrorAction SilentlyContinue
		} else {
			$ProcessActive = Get-Process $CheckProcess -ErrorAction SilentlyContinue
		}
		#$ProcessActive = Get-Process $CheckProcess -ErrorAction SilentlyContinue  #26.07.2017 MS: comment-out:

        if ((Get-Date) -ge $MaximumExecutionTime) {
			Write-BISFLog -Msg "The operation has exceeded the maximum execution time of $MaximumExecutionMinutes Minutes." -Type W
            if ($TerminateRunawayProcess) {
                Write-BISFLog -Msg "Forcibly terminating process. $($ProcessActive.Name)" -Type W
			    Stop-Process $ProcessActive -Force -ErrorAction SilentlyContinue
                Clear-Variable -Name "ProcessActive"
            }
            else {
                Clear-Variable -Name "ProcessActive" #this nulls out the variable allowing the "finish" bar
            }
		}

	   	if($ProcessActive -eq $null) {
           	$a=100
           	Write-Progress -Activity "Finish...wait for next operation in 5 seconds" -PercentComplete $a -Status "Finish."
           	IF ($State -eq "Preparation") {Start-Sleep 5}
            Write-Progress "Done" "Done" -completed
            break
       	} else {
            Start-Sleep 1
            $display= "{0:N2}" -f $a #reduce display to 2 digits on the right side of the numeric
            Write-Progress -Activity "$ActivityText" -PercentComplete $a -Status "Please wait..."
       	}
    }
}

function Get-LogContent {
    PARAM(
		[parameter(Mandatory=$True)][string]$GetLogFile
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    write-BISFlog -Msg "Get content from file $GetLogFile...please wait"
    write-BISFlog -Msg "-----snip-----"
		$content = Get-Content "$GetLogFile" -ErrorAction SilentlyContinue
		foreach ($line in $content) {IF (!($line -eq "")) {write-BISFlog -Msg "$line" -Type L }}
    write-BISFlog -Msg "-----snap-----"

}

function Test-Log {
  PARAM(
	[parameter(Mandatory=$True)][string]$CheckLogFile,
    [parameter(Mandatory=$True)][string]$SearchString
	)
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
   write-BISFlog -Msg "Check $CheckLogFile"
   IF (Test-Path ($CheckLogFile) -PathType Leaf)
   {
    	write-BISFlog -Msg "Check $CheckLogFile for $SearchString"
    	$searchP2PVS = select-string -path "$CheckLogFile" -pattern "$SearchString" | out-string
    	IF ($searchP2PVS) {return $True} else {return $false}
    } ELSE {
    	write-BISFlog -Msg "File $CheckLogFile not exist" -Type E
    	$searchP2PVS = ""
    }
return $searchP2PVS

}

function Add-FinishLine {
	write-BISFlog -Msg "------- FINISH SCRIPT -------"
}

Function Get-SoftwareInfo {
    <#
    .Synopsis
      Gets all installed software info about package(s)
    .Description
      The script will return an array of objects based on registrykey values.
      When the criteria are specific enough the return value should contain one object. This can
      be achieved by combining multiple parameters with specific names.

      The parameters are seached for on a wildcard base. So it is possible that one parameter will result in multiple objects. TIP: be more specific and/or use multiple properties of the software.
    .PARAMETER Name
      This is the DisplayName registry value within the subkeys of HKLM\SOFTWARE(\Wow6432Node)\Microsoft\Windows\CurrentVersion\Uninstall
    .PARAMETER Version
      This is the DisplayVersion registry value within the subkeys of HKLM\SOFTWARE(\Wow6432Node)\Microsoft\Windows\CurrentVersion\Uninstall
    .PARAMETER Publisher
      This is the Publisher registry value within the subkeys of HKLM\SOFTWARE(\Wow6432Node)\Microsoft\Windows\CurrentVersion\Uninstall
    .PARAMETER InstallLocation
      This is the InstallLocation registry value within the subkeys of HKLM\SOFTWARE(\Wow6432Node)\Microsoft\Windows\CurrentVersion\Uninstall
    .EXAMPLE Resolve Installation Location
      $package = Get-SoftwareInfo -Name "Citrix Provision Services Target Device" -Publisher "Citrix"
      $installationpath = $package.GetEnumerator().InstallLocation
    .Inputs
    .Outputs
      [System.Array]
    .NOTES
      Author: Mike Bijl
      Company: Login Consultants

      History
      Last Change: 2014-11-07T12:24:59 : Initial writing of the function.
    .Link
    #>
    param(
        [string]$Name = "",
        [string]$Version = "",
        [string]$Publisher = "",
        [string]$InstallLocation = ""
    )
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    $info = @()

    # Get Uninstall registry keys x64 on a x64 system or the x86 on a x86 system
    $Keys = @(get-childitem -path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Where { ((Get-ItemProperty -Path $_.PsPath).displayname -like "*$Name*") -and ((Get-ItemProperty -Path $_.PsPath).displayVersion -like "*$Version*") -and ((Get-ItemProperty -Path $_.PsPath).Publisher -like "*$Publisher*") -and ((Get-ItemProperty -Path $_.PsPath).InstallLocation -like "*$InstallLocation*")})
    # Get Uninstall registry keys x86 on a x64 system or skip this step on a x86 system
    If ((Test-path "Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") -eq $true) {
        $Keys += @(get-childitem -path "Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | Where { ((Get-ItemProperty -Path $_.PsPath).displayname -like "*$Name*") -and ((Get-ItemProperty -Path $_.PsPath).displayVersion -like "*$Version*") -and ((Get-ItemProperty -Path $_.PsPath).Publisher -like "*$Publisher*") -and ((Get-ItemProperty -Path $_.PsPath).InstallLocation -like "*$InstallLocation*")})
    }

    # Get the values from the registry keys which hold the info.
    Foreach ($Key in $Keys) {
        $info += (Get-ItemProperty -Path $Key.PSPath)
    }

    # The comma is in the return to force the object that is returned, is always an array.
    return ,$info

}

Function Get-PendingReboot {
<#
.SYNOPSIS
    Gets the pending reboot status on a local computer

.DESCRIPTION

.EXAMPLE
   Get-BISFPendingReboot

.NOTES
   #Adapted from https://gist.github.com/altrive/5329377
	#Based on <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>
	Author: Matthias Schlimm
      Company: EUCweb

      History
	  Last Change: dd.mm.yyy MS: script created
	  Last Change: 27.05.2018 MS: Hotfix 40: new Script to get pending reboot state
#>

	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function


If (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
If (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
If (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
 try {
		$util = [wmiclass]"\.\root\ccm\clientsdk:CCM_ClientUtilities"
		$status = $util.DetermineIfRebootPending()
		if(($status -ne $null) -and $status.RebootPending) {
			return $true
		}
 }
	catch {}
	return $false
}


function Convert-Settings
{
   Write-BISFFunctionName2Log  -FunctionName ($MyInvocation.MyCommand | % {$_.Name}) #must be added at the begin to each function
	 # Migrate Registry settings from Citrix BISF Scripts to BISF

   $OldTask="LIC_PVS_Device_Personalize"
   $querytask = schtasks /query /v /fo csv | ConvertFrom-Csv | % {$_.TaskName}
   Foreach ($task in  $querytask)
   {
        IF ($task -eq "\LIC_PVS_Device_Personalize")
        {
            write-BISFlog -Msg "Migrate BISF Settings: delete old Task $OldTask" -ShowConsole -Color DarkCyan -SubMsg
            & schtasks.exe /delete /TN $OldTask /F | out-null
        }
   }
   $NewRegKey = Test-Path $hklm_software\$LIC\$CTX_BISF_SCRIPTS
   $oldRegKey = Test-Path "$hklm_software\$LIC\Citrix BISF Scripts"
   IF (($NewRegKey -eq $false) -and ($NewRegKey -eq $true))
   {
        rename-item "$oldRegKey" -NewName "BISF"
        write-BISFlog -Msg "Migrate $CTX_BISF_SCRIPTS Registry Settings" -ShowConsole -Color DarkCyan -SubMsg

    }
}

Function Get-TaskSequence() {
  # This code was taken from a discussion on the CodePlex PowerShell
  # App Deployment Toolkit site. It was posted by mmashwani.
  Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	Try {
      [__ComObject]$SMSTSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction 'SilentlyContinue' -ErrorVariable SMSTSEnvironmentErr
  }
  Catch {
  }
  If ($SMSTSEnvironmentErr) {
    write-BISFlog -Msg "Unable to load ComObject [Microsoft.SMS.TSEnvironment]."
    write-BISFlog -Msg "The script is not currently running from an MDT or SCCM Task Sequence."
    Return $false
  }
  ElseIf ($null -ne $SMSTSEnvironment) {
    write-BISFlog -Msg "Successfully loaded ComObject [Microsoft.SMS.TSEnvironment]."
    write-BISFlog -Msg "The script is currently running from an MDT or SCCM Task Sequence."
	$Global:LIC_BISF_CLI_SB="NO"
	write-BISFlog -Msg "A system shutdown after successfully build would be suppressed, it must be performed from tasksequence !!" -Type W
    Return $true
  }

}

function Get-vDiskDrive
{
	<#
    .SYNOPSIS
        get the Driveletter of the attached vDisk
	.Description
      	Checks the Driveletter of the PVS Disk and give them back als returnvalue
		if the Citrix AppLayering is installed, everytime the Systemdrive will give it back
		use get-help <functionname> -full to see full help

	.EXAMPLE
		Get-BISFvDiskDrive
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 31.07.2017 MS: add Microsoft SYNPOSIS to this function
		Last Change: 31.07.2017 MS: IF Citrix AppLayering is installed, give SystemDrive back
		Last Change:
	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    $PVSDestDrive="FALSE"
	$SysDrive = $env:SystemDrive
    $array = @()
    $Sysdrvlabel = gwmi -Class win32_volume -Filter "Driveletter = '$SysDrive' "| % {$_.Label}
    $Sysdrv=gwmi -Class win32_volume -Filter "Label = '$Sysdrvlabel'" | % {$_.DriveLetter}
    $array += $Sysdrv
	IF (!($CTXAppLayeringSW))
	{

		# search for the pvs destination disk
		Foreach ($DrvInArray in $array)
		{
			if ("$DrvInArray" -eq "$SysDrive")
			{
				$PVSDestDrive = $DrvInArray
				write-BISFlog -Msg "identify vDisk destination drive $PVSDestDrive.. booting up from vdisk"
			} ELSE {
				$PVSDestDrive = $DrvInArray
				write-BISFlog -Msg "identify vDisk destination drive $PVSDestDrive.. booting up from harddisk"
				break
			}
		}
	} ELSE {
		$PVSDestDrive = $SysDrive
		write-BISFlog -Msg "Citrix AppLayering installed - identified Disk $PVSDestDrive - running $CTXAppLayerName"
	}
	Return $PVSDestDrive


}

function Get-ScriptExecutionPath
{
	# 05.05.2015 MS: running BIS-F from local drives only
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$scriptdrive = $Main_Folder.Substring(0,2)
	$locadrives = get-wmiobject win32_volume | ? { $_.DriveType -eq 3 } | % {$_.Driveletter}
	Foreach ($localdrive in $locadrives)
	{
    	IF ($localdrive -eq $scriptdrive)
   	 	{
    		write-BISFlog -Msg "Script would be started from drive $localdrive"
			return $true
    		break
    	}
	}

}

function Enable-Privilege {
 param(
  # 20.05.2015 MS: feature 45 - added function
  ## The privilege to adjust. This set is taken from
  ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
  [ValidateSet(
   "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
   "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
   "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
   "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
   "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
   "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
   "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
   "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
   "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
   "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
   "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
  $Privilege,
  ## The process on which to adjust the privilege. Defaults to the current process.
  $ProcessId = $pid,
  ## Switch to disable the privilege, rather than enable it.
  [Switch] $Disable
 )
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
 ## Taken from P/Invoke.NET with minor adjustments.
 $definition = @'
 using System;
 using System.Runtime.InteropServices;

 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }

  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
    tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
    tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@

 $processHandle = (Get-Process -id $ProcessId).Handle
 $type = Add-Type $definition -PassThru
 $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)

}

function Get-CLIcmd
{
	<#
    .SYNOPSIS
        write the CLI names and their values to the BIS-F Logfile
	.Description
      	write all used CLI values to the logfile
		use get-help <functionname> -full to see full help

	.EXAMPLE
		get-BISFCLIcmd
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 10.03.2016 MS: function created
		Last Change: 01.08.2017 MS: define global variable for each CLI command
		Last Change:

	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	IF (Test-Path $Reg_LIC_Policies -ErrorAction SilentlyContinue)
	{
		write-BISFlog -Msg "The following CLI commands would set:"
		$regvalues = Get-BISFRegistryValues $Reg_LIC_Policies
		Foreach ($regvalue in $regvalues) {
			New-BISFGlobalVariable -Name $($regvalue.value) -Value $($regvalue.data)
			}
	} ELSE {
		Write-BISFLog -Msg "No configuration via ADMX or Shared Configuration detected" -SubMsg -Type W -ShowConsole
        #IF ($State -eq "Preparation") {$return_admx = Show-BISFMessageBox -Msg "$FrameworkName can be configured with ADMX for complete automation. Please copy the ADMX and the ADML files from the BIS-F installation folder to your PolicyDefinitions folder and configure them via group policy for your Base Images" -Title "ADMX Configuration" -Information}

	}

}

function Get-DiskMode {
	<#
    .SYNOPSIS
        get DiskMode from PVS or MCS
	.Description
      	get DiskMode from PVS or MCS back as follows:
			ReadWrite
			ReadOnly
			Unmanaged
			VDAPrivate
			VDAShared
			ReadWriteAppLayering
			ReadOnlyAppLayering
			VDAPrivateAppLayering
			VDASharedAppLayering
			UNC-Path
		use get-help <functionname> -full to see full help
    .EXAMPLE
		$DiskMode = Get-BISFDiskMode

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy BR: function created
		Last Change: 07.09.2015 MS: add .SYNOPSIS to this function
		Last Change: 30.09.2015 MS: Change $returnValue =  "Writeable" to $returnValue =  "ReadWrite"
		Last Change: 28.07.2017 MS: If Citrix AppLayerLayering is installed get back DiskMode $returnValue = "AppLayering"
		Last Change: 04.08.2017 MS: If Custom UNC-Path in ADMX is enabled, get back 'UNC-Path' as $returnvalue
		Last Change: 06.08.2017 MS: Bugfix -if Custom UNC-Path in ADMX is enabled, during "Personalization" the wrong $returnvalue like MCSPrivate is given back, instead of "UNC-Path"
		Last Change: 15.08.2017 MS: get additional DiskMode with AppLayering back, like ReadWriteAppLayering, ReadOnlyAppLayering
		Last Change: 29.10.2017 MS: get VDA back instead of MCS
		.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$ErrorActionPreference = "Stop"
	try {
		$WriteCacheMode = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\bnistack\PVSAgent).WriteCacheType

      	if ($WriteCacheMode -eq "0") {
			$returnValue =  "ReadWrite"
		}
		else {
			$returnValue =  "ReadOnly"
        }
	}
	catch [System.Management.Automation.ItemNotFoundException]
	{
		if (Test-Path -Path "C:\Personality.ini" -PathType Leaf) {
            $Personality = Get-Content -Path "C:\Personality.ini"
            foreach ($line in $Personality) {
                if ($line -like '*DiskMode=*') {
                    $Line = $Line.split("=")
                    $returnValue =  "VDA" + $Line[1]
                }
            }
			IF ($LIC_BISF_CLI_P2V_PT -eq "1") {$returnValue =  $ReturnValue + "UNC-Path"}
		}
        else {
            $returnValue =  "Unmanaged"
			IF ($LIC_BISF_CLI_P2V_PT -eq "1") {$returnValue =  $ReturnValue + "UNC-Path"}
			IF ($LIC_BISF_CLI_P2V_SKIP_IMG -eq "1") {$returnValue =  $ReturnValue + "AndSkipImaging"}
        }
	}
    Finally { $ErrorActionPreference = "Continue" }
	IF ($CTXAppLayeringSW -eq $true) {$ReturnValue = $ReturnValue + "AppLayering"}
	write-BISFlog -Msg "DiskMode is $($ReturnValue)"
	return $returnValue

}

function Show-CustomInputBox([string] $title, [string] $message, [string] $defaultText) {
	<#
    .SYNOPSIS
        Show input box popup
	.Description
      	show a input box, where user can enter an value

    .EXAMPLE
		Show-BISFCustomInputBox -title "Windows title" -message "your message" -defaultText "this text would be used, in the input boy as default text"
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
		Company: Login Consultants Germany GmbH

		History
      	Last Change: dd.mm.yyyy MS: function created
		Last Change: 07.09.2015 MS: add .SYNOPSIS to this function
	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    Add-Type -AssemblyName Microsoft.VisualBasic
    $inputText = [Microsoft.VisualBasic.Interaction]::InputBox("$message", "$title", "$defaultText")
    return $inputText

 }

function Test-RegistryValue {
	<#
    .SYNOPSIS
        Test-BISFRegistryValue
	.Description
      	test regsitry value if exists and returns a true or false value

    .EXAMPLE
		Test-BISFRegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -Value "CommonFilesDir"
		returns true if the value exist
		returns false if the value not exist
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
		Company: Login Consultants Germany GmbH

		History
      	Last Change: 01.09.2015 MS: added function
		Last Change: 06.08.2017 MS: remove Warning if Registrypath not exists
	.Link
#>
		param (
		# defines the registry Path
	 	[parameter(Mandatory=$true)]
	 	[ValidateNotNullOrEmpty()]$Path,

	 # defines the registry Value
		[parameter(Mandatory=$true)]
	 	[ValidateNotNullOrEmpty()]$Value
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$ErrorActionPreference = "Stop"
	try
	{
		Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value | Out-Null
 		write-BISFlog -Msg "Registrypath $($Path), Value $($Value) exists"
		return $true
 	}
	catch
	{
		write-BISFlog -Msg "Registrypath $($Path), Value $($Value) NOT exists !!"
		return $false
	}
	Finally { $ErrorActionPreference = "Continue" }

}

function Get-DiskNameExtension {
	<#
    .SYNOPSIS
        Get-BISFDisknameExtension
	.Description
      	using with Citrix PVS Environment only. as result give back the last 4 strings from the attached PVS vDisk
		use get-help <functionname> -full to see full help
    .EXAMPLE
		Get-BISFDiskNameExtension
		IF you have attached a vDisk with Name vDISK-STD-V01.vhd
		retuns BaseDisk

	.EXAMPLE
		Get-BISFDiskNameExtension
		IF you have attached a vDisk with Name vDISK-STD-V01.avhd
		retuns ParentDisk

	.EXAMPLE
		Get-BISFDiskNameExtension
		IF you haven't any vDisk attached
		retuns NoVirtualDisk

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
		Company: Login Consultants Germany GmbH

		History
      	Last Change: 01.09.2015 MS: added function, defrag would be performed on BaseDisk and HardDrive only
		Last Change: 15.03.2017 MS: Change to $vDiskName = $vDiskName.split(".")[-1] # get corect vDiskExtension
	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$ErrorActionPreference = "Stop"
	try {
		$vDiskName = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\bnistack\PVSAgent).DiskName
		$vDiskName = $vDiskName.split(".")[-1] # get vDiskExtension

		if (($vDiskName -eq "vhd") -or ($vDiskName -eq "vhdx")) {
			$returnValue =  "BaseDisk"
		}
		else {
			$returnValue =  "ParentDisk"
        }
	}
	catch [System.Management.Automation.ItemNotFoundException]
	{
		$returnValue =  "NoVirtualDisk"
    }

    Finally { $ErrorActionPreference = "Continue" }
	write-BISFlog -Msg "vDisk Extension is $($ReturnValue)"
	return $returnValue

}

function Test-Service {
	<#
    .SYNOPSIS
        test service if exist
	.Description
      	check if a service exists and send back a true or false value, Optional you can use the paramter Productname to set the name of the Product
		use get-help <functionname> -full to see full help
    .EXAMPLE
		Test-BISFService -ServiceName CcmExec
	.EXAMPLE
		Test-BISFService -ServiceName CcmExec -ProductName "Microsoft SCCM Agent"
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 02.09.2015 MS: function created
		Last Change: 06.03.2017 MS: get FileVersion from ImagePath
		Last Change: 28.02.2018 MS: Bugfix get Fileversion from Imagepath, without arguments of the service
		Last Change: 20.10.2018 MS: Bugfix 74: The Version from the Service could not extracted
	.Link
#>

	param (
		# Specifies the ServiceName
	 	[parameter(Mandatory=$true)]
	 	[ValidateNotNullOrEmpty()]$ServiceName,

		# specifies the Productname / Software
	 	[parameter(Mandatory=$false)]
	 	[ValidateNotNullOrEmpty()]$ProductName
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    IF (Get-Service $Servicename -ErrorAction SilentlyContinue)
	{
 		write-BISFlog -Msg "Service $($ServiceName) exists"
		IF ($ProductName) {
			$SVCFileVersion = $null
			$service = gwmi -class Win32_Service | ? {$_.Name -eq $($ServiceName)}
			$SVCImagePath = ($service | Select -Expand PathName) -split "-|/"
			$SVCImagePath= $SVCImagePath[0]
			$SVCImagePath = $SVCImagePath -replace ('"','')
			$Global:glbSVCImagePath = "$SVCImagePath"
			$SVCFileVersion = (Get-Item $($SVCImagePath) -ErrorAction SilentlyContinue).versioninfo.fileversion
            IF (!($SVCFileVersion -eq $null))
            {
                $ShowVersion ="(Version $SVCFileVersion)"
                Write-BISFlog -Msg "Product $ProductName $ShowVersion installed" -ShowConsole -Color Cyan
             } ELSE {
                Write-Log -Msg "The version from $ProductName could not be extracted from imagepath $SVCImagePath"
                Write-BISFlog -Msg "Product $ProductName installed" -ShowConsole -Color Cyan
             }

		}
		return $true
 	} ELSE  {
		write-BISFlog -Msg "Service $($ServiceName) Not exists"
		IF ($ProductName) {write-BISFlog -Msg "Product $ProductName NOT installed"}
		return $false
	}

}

function Invoke-Service
 {
	<#
    .SYNOPSIS
        reconfigure the service
	.Description
      	reconfigure a specified service to Start or Stop the service and set the startuptype to disabled, manual, automatic
		use get-help <functionname> -full to see full help
    .EXAMPLE
		The service will be stopped and set to manual startup type
		 Invoke-BISFService -ServiceName wuauserv -Action Stop -StartType manual
	.EXAMPLE
		The service will be stopped
		 Invoke-BISFService -ServiceName wuauserv -Action Stop
	.EXAMPLE
		The service will be started
		 Invoke-BISFService -ServiceName wuauserv -Action Start
	.EXAMPLE
		The service will be started if the Image is in ReadWrite Mode
		 Invoke-BISFService -ServiceName wuauserv -Action Start -CheckDiskMode RW
	.EXAMPLE
		The service will be started if the Image is in ReadOnly Mode
		 Invoke-BISFService -ServiceName wuauserv -Action Start -CheckDiskMode RO
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm, Florian Frank
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 02.09.2015 MS: function created
		Last Change: 30.09.2015 MS: added CheckDiskMode to start the service if the DiskMode is in ReadWrite (RW) or ReadOnly (RO) Mode
        Last Change: 04.03.2016 MS: heavy bug in function Invoke-BISFService, services would not started if needed
		Last Change: 15.03.2016 MS: give wrong variable back, switch RO and RW
		Last Change: 15.03.2016 BR: Syntax error Invoke-BISFService: Set-Service -Name $svc.Name -StartupType $StartType | Out-Null
		Last Change: 15.08.2017 MS: Change $Diskmode -match, needed for AppLayering, example ReadWriteAppLayering
		Last Change: 24.08.2017 MS: add IF ($CheckDiskMode -eq $null) {Write-BISFLog -Msg "DiskMode must not checked"} ELSE {Write-BISFLog -Msg "DiskMode $CheckDiskMode would be checked successfully"}s
		Last Change: 11.09.2017 FF: add missing function name
		Last Change: 29.10.2017 MS: test DiskMode match VDA instead of MCS
		Last Change: 01.07.2018 MS: Hotfix 49: running Test-BISFServiceState after changing Service to get the right Status back
	.Link
#>

	param (
		# Specifies the ServiceName
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]$ServiceName,

	 	# Specifies the Action to Start or Stop the Service
	 	[parameter(Mandatory=$true)]
	 	[ValidateSet("Start", "Stop")]
		[ValidateNotNullOrEmpty()]$Action,

		# Specifies the Starttype: Disabled, Manual, Automatic
		[parameter(Mandatory=$false)]
	 	[ValidateSet("Disabled", "Manual", "Automatic")]
		[ValidateNotNullOrEmpty()]$StartType,

		# Specifies the DiskMode to check: RW, RO
		[parameter(Mandatory=$false)]
	 	[ValidateSet("RW", "RO")]
		[ValidateNotNullOrEmpty()]$CheckDiskMode

	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	If (!($CheckDiskMode -eq $null))
	{
		$DiskMode = Get-BISFDiskMode
		IF (($DiskMode -match "ReadOnly") -or ($DiskMode -match "VDAShared")){$DiskMode="RO" }
		IF (($DiskMode -match "ReadWrite") -or ($DiskMode -match "VDAPrivate")){$DiskMode="RW" }
		Write-BISFLog -Msg "Image will be run in $DiskMode Mode (RO:ReadOnly, RW=ReadWrite)"
	}
	$ErrorActionPreference = "Stop"
	write-BISFlog -Msg "Reconfigure Service $ServiceName" -ShowConsole -Color DarkCyan -SubMsg
	try
	{
		$svc = Get-Service $Servicename
		If ($Action -eq "Stop")
		{

			IF ($svc.Status -eq 'Running')
	        {
	            $svc.Stop() | Out-Null
	            $svc.WaitForStatus('Stopped') | Out-Null
				write-BISFlog -Msg "Service $ServiceName would be stopped"
	        } ELSE {
				write-BISFlog -Msg "Service $ServiceName is already stopped !"
			}
			Test-BISFServiceState -ServiceName $ServiceName -Status "Stopped"
		}

		IF ($StartType)
		{
			IF (($StartType -eq "Manual") -and ($ImageSW -eq $false))
			{
				write-BISFlog -Msg "No Image Management Software detected, Service $ServiceName would not be changed to StartupType $StartType" -Type W
			} ELSE {
				write-BISFlog -Msg "Service $($svc.Name) would be configured to StartupType $StartType"
				Set-Service -Name $svc.Name -StartupType $StartType | Out-Null
			}
		}

		IF (($CheckDiskMode -eq $null) -or ($CheckDiskMode -eq $DiskMode))
		{
			IF ($CheckDiskMode -eq $null) {Write-BISFLog -Msg "DiskMode must not checked"} ELSE {Write-BISFLog -Msg "DiskMode $CheckDiskMode would be checked successfully"}
			If ($Action -eq "Start")
			{

				IF ($svc.Status -eq 'Stopped')
	        	{
		            $svc.Start() | Out-Null
		            $svc.WaitForStatus('Running') | Out-Null
					write-BISFlog -Msg "Service $ServiceName is running now"
	        	} ELSE {
					write-BISFlog -Msg "Service $ServiceName is already running !"
				}
				Test-BISFServiceState -ServiceName $ServiceName -Status "Running"
			}
		}

    }

	catch
	{
		IF ($StartType)
		{
			write-BISFlog -Msg "Error during reconfigure Service $($servicename) -Action $Action -StartType $StartType" -Type W -SubMsg
		} ELSE {
			write-BISFlog -Msg "Error during reconfigure Service $($servicename) -Action $Action" -Type W -SubMsg
		}
		write-BISFlog -Msg "The error is: $_" -Type W -SubMsg
	}
	Finally { $ErrorActionPreference = "Continue" }

}

function Get-AdapterGUID {
	<#
    .SYNOPSIS
        read network GUID like {0252A1FD-4299-4E1C-80B5-ADD027292A6E}
	.Description
      	get GUID of all DHCP Adapters back
		use get-help <functionname> -full to see full help
    .EXAMPLE
		Get-BISFAdapterGUID

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 25.11.2015 MS: function created
		Last Change: 15.03.2016 MS: get duplicate AdapterGUID back, instead unique of each adapter

	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	write-BISFLog -Msg "Read GUIDs of each Networkadapter"
	$HKLM_REG_TCPIP = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
	$AllAdapterGUIDs= Get-ChildItem "$HKLM_REG_TCPIP\Adapters" | Get-ItemProperty | % {$_.PSChildName}
	ForEach ($AdapterGUID in $AllAdapterGUIDs)
	{
		$TestDHCP= Get-ItemProperty "$HKLM_REG_TCPIP\Interfaces\$AdapterGUID" | % {$_.EnableDHCP}
		IF ($TestDHCP -eq 1)
		{
			write-BISFLog -Msg "DHCP on Adapter with GUID $AdapterGUID is enabled"
			[array]$AdapterGUIDarray += $AdapterGUID
		} ELSE {
			write-BISFLog -Msg "DHCP on Adapter with GUID $AdapterGUID is disabled !!"
		}
	}

	return $AdapterGUIDarray
}

function Optimize-WinSxs {
	<#
    .SYNOPSIS
        Cleanup the WinSxs Folder
	.Description
		get further informations here
      	https://msdn.microsoft.com/en-us/library/dn251565.aspx
    .EXAMPLE
		Optimize-BISFWinSxs

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: EUCweb.com

		History
      	Last Change: 07.01.2016 MS: function created
		Last Change: 17.05.2019 MS: HF 106: remove uneccesary out-null command function Optimize-WinSxs
		Last Change: 21.06.2019 MS: FRQ 115: ADMX: Control of WinSxS Optimization
		Last Change: 03.07.2019 MS: ENH 117: WinSxS hide DISM process and get logfile of the DISM Process into BIS-F log
	.Link
#>
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	IF (!($LIC_BISF_CLI_WinSxS -eq "NO"))		
	{
		Write-BISFLog -Msg "Perform WinSxS Optimization" -ShowConsole -Color Cyan
		$runWinSxs = 1
		IF ($LIC_BISF_CLI_WinSxSBaseImage -eq 1)
		{
			$DiskNameExtension = Get-BISFDiskNameExtension
			IF (($DiskNameExtension -eq "BaseDisk") -or ($DiskNameExtension -eq "noVirtualDisk"))
			{
				$runWinSxs = 1
			} ELSE {
				$runWinSxs = 0
				Write-BISFLog "WinSxS Optimization is configured in ADMX to run on BaseDisk or with noVirtualDisk assigned , $DiskNameExtension detected" -ShowConsole -SubMsg -Color DarkCyan
			}

		}
		IF ($runWinSxs -eq 1) {
			IF (!($LIC_BISF_CLI_WinSxSTimeout)) {$LIC_BISF_CLI_WinSxSTimeout = 60}
			IF (Test-path "C:\Windows\logs\DISM\dism_bisf.log") {Remove-Item "C:\Windows\logs\DISM\dism_bisf.log" -Force}
                	Start-Process 'Dism.exe' -ArgumentList '/online /Cleanup-Image /StartComponentCleanup /ResetBase /Logpath:C:\Windows\logs\DISM\dism_bisf.log' -RedirectStandardOutput "C:\windows\temp\WinSxs.log" -NoNewWindow
			Show-BISFProgressBar -CheckProcess "Dism" -ActivityText "run DISM to cleanup WinSxs Folder ...(max. Execution Timeout $LIC_BISF_CLI_WinSxSTimeout min)" -MaximumExecutionMinutes $LIC_BISF_CLI_WinSxSTimeout
		        Get-BISFLogContent -GetLogFile "C:\Windows\logs\DISM\dism_bisf.log"
		} ELSE {
			Write-BISFLog -Msg "WinSxS Optimization will not run (runWinSxs = 0)" -ShowConsole -SubMsg -Color DarkCyan
		}
	} ELSE {
		Write-BISFLog -Msg "WinSxS Optimization is disabled in ADMX configuration."
	}
}

function Test-VMwareHorizonViewSoftware{
	<#
    .SYNOPSIS
        check if the VMware Horizon View Agent installed
	.Description
      	if the VMware Horizon View Agent installed they will send a true or false value and will set the global variable ImageSW to true or false
		use get-help <functionname> -full to see full help

	.EXAMPLE
		Test-BISFVMwareHorizonViewSoftware
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 07.01.2016 MS: function created
		Last Change:

	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    $svc = Test-BISFService -ServiceName "WSNM" -ProductName "VMware Horizon View Script Host"
	IF (($ImageSW -eq $false) -or ($ImageSW -eq $Null)) {IF ($svc -eq $true) { $Global:ImageSW=$true } }
	return $svc

}

Function Get-OSCSessionType {
	<#
    .SYNOPSIS
        check the Sessiontype if there console or not
	.Description
      	if the powershell script is running from console session they gives a true value back, instead of false for RDP Session
	.EXAMPLE
		Get-BISFOSCSessionType
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 21.01.2016 MS: function created, get POSH from https://gallery.technet.microsoft.com/scriptcenter/Determines-the-Terminal-a0a454a4
		Last Change: 10.03.2016 MS: add CLI switch to disable the Sesiontype

	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	IF (!($LIC_BISF_CLI_ST))   #Do not check SessionType
	{
		IF ($State -eq "Preparation")
		{
			$Results = @()
			#Use commad "query session" to list all sessions
			$sessions = query session $Env:USERNAME /server:$Env:COMPUTERNAME
			#Split the results and store them into the variable $Result
			For($i = 1 ;$i -lt $Sessions.Count)
			{
				$temp = "" | Select SessionName, Username
				#Split the result to get the session name
				$temp.SessionName = $sessions[$i].Substring(1,18).Trim()
				#Split the result to get the user name
				$temp.Username = $sessions[$i].Substring(19,20).Trim()
				#Store the result into $Result
				$Results += $temp
				$i ++
			}
			#Verify if the session is terminal or console
   			Foreach($Result in $Results)
  			{
				$Username = $Result.Username
				$Sessionname = $Result.SessionName
				#Check the Username and SessionName
				If($Username.Length -gt 0 )
				{
					#Check for session name. If it contains "rdp-tcp#", the session is terminated.
	    			If($Sessionname -match "rdp-tcp#")
					{
						Write-BISFLog -Msg "BIS-F can run from an RDP session, but this feature is disabled by default. Run BIS-F from a Console session or enable RDP support in the BIS-F ADMX template" -Type E
					}
					#Check for session name.If it contains "console" ,the session is console.
					If($Sessionname -match "console")
					{
						Write-BISFLog -Msg "BIS-F is running from a console session " -ShowConsole -Color DarkCyan -SubMsg
					}
	 			}
		   }
		}
	} ELSE {
		Write-BISFLog -Msg "RDP session support can be enabled in the ADMX template" -ShowConsole -SubMsg -Color DarkCyan
	}

}

function Request-Sysprep {
<#
    .SYNOPSIS
        Ask for sysprep
	.Description
      	use sysprep, only can be used if No Image Management Software (Citrix PVS Target Device, XenDesktop VDA, VMware View Agent) would be detected

	.EXAMPLE
		Request-BISFSysprep
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 28.01.2016 MS: function created
		Last Change: 06.03.2017 MS: Bugfix read Variable $varCLI = ...
		Last Change: 11.02.2018 MS: Bugfix 235, if sysprep is enabled and other Management SW like Citrix VDA, PVS Target Device Driver, VMWare View Agent is installed, the script breaks

	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    IF ($State -eq "Preparation")
    {
        IF (($ImageSW -eq $false) -or ($ImageSW -eq $Null))
	    {
		    $varCLISP = $LIC_BISF_CLI_SP
	        IF (($varCLISP -eq "YES") -or ($varCLISP -eq "NO"))
	        {
		        Write-BISFLog -Msg "Silentswitch for Sysprep would be set to $varCLISP"
	        } ELSE {
       	        Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
		        $MPSP = Show-BISFMessageBox -Msg "No Image Management Software like Citrix PVS Target Device Driver, XenDesktop VDA or VMware Horizon View Agent would be detected. You can use Sysprep to prepare your Image. On Computerstartup BIS-F checked the new generated Computername if they matched WIN- and does not start the Services like SCCM,SCOM, Antivirus, etc. to prevent wrong GUIDS or entries in the System Management Server. If you change the Computername, after reboot BISF starts the services. Would you run SysPrep at the end of BIS-F ?" -Title "Sysprep usage" -YesNo -Question
    	        Write-BISFLog -Msg "$MPSP was selected [YES = use Sysprep] [NO = Not use Sysprep]"
	        }

		    if (($MPSP -eq "YES" ) -or ($varCLISP -eq "YES"))
	        {
		        Write-BISFLog -Msg "Sysprep would be used at the end of BIS-F" -ShowConsole -Color DarkCyan -SubMsg
			    $Global:RunSysprep=$true

	        } ELSE {
		        Write-BISFLog -Msg "Skipping Sysprep usage"
			    $Global:RunSysprep=$false
	        }

	    } ELSE {
		    $Global:RunSysprep=$false
		    IF ($LIC_BISF_CLI_SP -eq "YES")
		    {
			    write-BISFLog -Msg "Sysprep can't be used, because Image Management Software like Citrix PVS Target Device Driver, XenDesktop VDA, VMware Horizon View Agent would be detected !" -ShowConsole -SubMsg -Type W

		    }
	    }
    }

}


function Set-PostSysprep {
<#
    .SYNOPSIS
        Configure Services that set to manual for Sysprep Imaging
	.Description
      	During Sysprep a LIC_BISF_Sysprep_ServiceList would generated, with all Services that must set from manual to automatic

	.EXAMPLE
		Set-BISFPostSysprep
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 02.02.2016 MS: function created
		Last Change:

	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    IF  ( (($computer -notlike "WIN-*") -or ($computer -notlike "DESKTOP-*")) -and ($State -eq "Personalization") -and ($LIC_BISF_RunSysPrep -eq $true) )
    {
        Write-BISFLog -Msg "Running Post Sysprep actions to configure the services in the ServiceList "
        ForEach ($SPService in $LIC_BISF_Sysprep_ServiceList -split(","))
        {
           Write-BISFLog -Msg "Setting $($SPService) to StartUpTyppe automatic"
           Invoke-BISFService -ServiceName $($SPService) -StartType Automatic
        }
        $RunSysPrep = $false
        Write-BISFLog -Msg "Write Sysprep status to registry location Path: $hklm_software_LIC_CTX_BISF_SCRIPTS -Name: LIC_BISF_RunSysPrep -Value: $RunSysPrep"
	    Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_RunSysPrep" -value "$RunSysPrep" -ErrorAction SilentlyContinue
    }

}

function Start-ProcWithProgBar {
<#
    .SYNOPSIS
        Starting a normal windows process and shown the progressbar in the POSH script
	.Description
      	Starting a Process and using the Show-BISFProgresbar BISF-Function to show the ProgressBar on the POSH Script

	.EXAMPLE
		 Start-BISFProcWithProgBar -ProcPath "C:\SCRIPTS\BISF_SCRIPTS\10_SubCall\10_LIB\Tools\deplprof2.exe" -Args "/u /r" -ActText "Delprof2 is running"
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 10.03.2016 MS: function created
		Last Change: 17.03.2017 MS: Bugfix: Start-BISFProcWithProgBar: using $ArgList instead og $Args at the Write-BISFLog commmand here
		Last Change: 17.03.2017 MS: Bugfix: Start-BISFProcWithProgBar: remove -Wait from Start-Process
	    Last Change:
	.Link
#>

	PARAM(
		[parameter(Mandatory=$True)][string]$ProcPath,
		[parameter(Mandatory=$True)][string]$Args,
		[parameter(Mandatory=$True)][string]$ActText
	)
	$tmpLogFile = "C:\Windows\logs\BISFtmpProcessLog.log"
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$ChkProc = [io.fileinfo] "$ProcPath" | % basename  # get name from executable without path and extension
	Write-BISFLog -Msg "Starting Process $ProcPath with ArgumentList $Args"
	Start-Process -FilePath "$ProcPath" -ArgumentList "$Args" -NoNewWindow -RedirectStandardOutput "$tmpLogFile" | Out-Null
	Show-BISFProgressBar -CheckProcess $ChkProc -ActivityText $ActText
	Get-BISFLogContent -GetLogFile "$tmpLogFile"
    Remove-Item -Path "$tmpLogFile" -Force | Out-Null
}

function Invoke-LogRotate {
<#
    .SYNOPSIS
        Rotate Logfiles
	.Description
      	Cleanup Logfiles and keep only a configured value of files

	.EXAMPLE
		Invoke-BISFLogRotate -Versions 5 -LogFileName "Prep*" -Directory "D:\BISFLogs"
    .Inputs
    .Outputs
    .NOTES
		Author: Benjamin Ruoff
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 15.03.2016 BR: function created
		Last Change: 17.03.2016 BR: Change Remove-Item to delete the oldest log
		Last Change: 02.08.2017 MS: using log rotate from ADMX, default = 5 if not set

	.Link
#>
	Param(
	    [Parameter(Mandatory=$True)][Alias('C')][int]$Versions,
        [Parameter(Mandatory=$False)][Alias('FN')][string]$strLogFileName,
	    [Parameter(Mandatory=$True)][Alias('D')][string]$Directory
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	IF ($State -eq "Preparation") {$strLogFileName="Prep*"}
	IF ($State -eq "Personalization") {$strLogFileName="Pers*"}

	[int]$Versions = $LIC_BISF_CLI_LF_RT

	$val_LF_RT = Test-BISFRegistryValue -Path "$Reg_LIC_Policies" -Value "LIC_BISF_CLI_LF_RT"
	IF ($val_LF_RT -eq $false) {write-BISFlog -Msg "Log rotate would NOT specified in the ADMX, it uses their default value 5 ";[int]$Versions = "5"}
	IF ($LIC_BISF_CLI_LF_RT -eq "0") {write-BISFlog -Msg "Log rotate would set to 0 value in the ADMX, it uses now the max. count of 9999 ";[int]$Versions = "9999"}

    $LogFiles = Get-ChildItem -Path $Directory -Filter $strLogFileName | Sort-Object -Property LastWriteTime -Descending
	for ($i=$Versions; $i -le ($Logfiles.Count -1); $i++) {Remove-Item $LogFiles[$i].FullName}
    write-BISFlog -Msg "Cleaning Logfile ($strLogFileName) in $Directory and keep the last $Versions Logs"

}


function Invoke-LogShare {
<#
    .SYNOPSIS
		Based on Preparation Phase the central Logshare would be set

	.Description
      	Preparation Phase:
			defines a optional Central LogShare for all the BISF Logfiles, if the CLI command -LogShare would not
			specified a MessageBox appears to ask for the UNC-Path.
			It's recommended "Authenticated Users has Read/Write Access to to this folder"
	.EXAMPLE
		Invoke-BISFLogShare
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 16.03.2016 MS: function created
		Last Change: 23.03.2016 MS: extend CLI command, you can use -LogShare NO for not beeing used the Central LogShare
		Last Change: 06.03.2017 MS: Bugfix read Variable $varCLI = ...
		Last Change: 18.08.2017 FF: Fix for Bug 200: Popup shouldn't show up if Central Logshare is enabled OR disabled
		Last Change: 02.07.2018 MS: Bugfix 50 - set Global Variable after Registry is set (After LogShare is changed in ADMX, the old path will also be checked and skips execution)
		.Link
#>
	Write-BISFFunctionName2Log  -FunctionName ($MyInvocation.MyCommand | % {$_.Name}) #must be added at the begin to each function
	IF ($State -eq "Preparation")
	{
		Write-BISFLog -Msg "Check Silentswitch..."
		$varCLILS = $LIC_BISF_CLI_LS
		$varCLILSb = $LIC_BISF_CLI_LSb
		$varCLILSCfg = $LIC_BISF_CLI_LogCfg
		IF ($varCLILSCfg -ne $null)
		{
			IF ($varCLILSb -eq "NO") {$varCLILS = $varCLILSb}
			Write-BISFLog -Msg "Silentswitch would be set to $varCLILS"
			$CentralLogShare = $varCLILS
		} ELSE {
		   Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
			$MPLS = Show-BISFMessageBox -Msg "Would you like to define a central LogShare to save all BIS-F Logs on one central place? [YES] Enter the UNC-Path \\Server\Share. Recommended: Authenticated users have Read/Write Access to this folder. [NO] Skip Central LogShare. BIS-F LogFiles would be stored on each computer!" -Title "BISF Central Log-Share" -YesNo -Question
			Write-BISFLog -Msg "$MPLS was selected [YES = define Central LogShare] [NO = Skip Central LogShare]"
			IF ($MPLS -eq "YES")
			{
				Write-BISFLog -Msg "Silentswitch not defined, show Inputprompt to define UNC-Path, to define the Central LogShare"
                $IBLS = Show-BISFCustomInputBox -title "BISF Central LogShare" -message "Please enter the UNC-Path for the Central LogShare \\Server\Share. Recommended: Authenticated users have Read/Write Access to this folder !" "" -defaultText $LIC_BISF_LogShare
				$CentralLogShare = $IBLS
			} ELSE {
				$CentralLogShare = ""
			}
		}

		If (($CentralLogShare -ne "") -and ($CentralLogShare -ne "NO"))
		{
			 Write-BISFLog -Msg "The BIS-F Central LogShare for the Client personalization would be set to $CentralLogShare" -ShowConsole -Color DarkCyan -SubMsg
			 Write-BISFLog -Msg "Set BIS-F Central LogShare in the registry $hklm_software_LIC_CTX_BISF_SCRIPTS, Name LIC_BISF_LogShare, value $CentralLogShare"
			 Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_LogShare" -value "$CentralLogShare" -Force
			$Global:LIC_BISF_LogShare = "$CentralLogShare"
		} ELSE {
			Write-BISFLog -Msg "No BIS-F Central LogShare defined, skip action"
            IF (($LIC_BISF_LogShare -eq "" ) -or ($LIC_BISF_LogShare -eq $null))
			{
				Write-BISFLog -Msg "No Central LogShare would be configured, the local path would be used" -ShowConsole -Color DarkCyan -SubMsg
            } ELSE {
				Write-BISFLog -Msg "The Central LogShare would be previous defined to $LIC_BISF_LogShare, this log would be stored on the Central Share, but for the future the local path would be used" -ShowConsole -Color DarkCyan -SubMsg
			}
				remove-itemproperty -path $hklm_software_LIC_CTX_BISF_SCRIPTS -name "LIC_BISF_LogShare" -ErrorAction SilentlyContinue
            $Global:LIC_BISF_LogShare=""
		}
	}

}

function Test-AccessRights {
	<#
    .SYNOPSIS
        Test write-Access to specified folder
	.Description
      	Test Write-Access to specified folder and give back a true or $flase value

	.EXAMPLE
		Test-BISFAccessRights
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 16.03.2016 MS: function created
		Last Change:

	.Link
#>
	Param(
	    [Parameter(Mandatory=$True)][Alias('D')][string]$Directory
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function

	$aclfile = "$Directory\$($cu_user)_aclTest.tmp"

	Try { [io.file]::OpenWrite($aclfile).close()
		Write-BISFLog "granted write-Access to $Directory [io-file $aclfile]"
		remove-item "$aclfile" -Force
		return $true
    }
	Catch {
		Write-BISFLog "You do not have write access to this directory $Directory [io-file $aclfile]" -Type W
		return $false
	}

}

Function Write-FunctionName2Log  {
	<#
    .SYNOPSIS
        Writes the Function name to the Logfile
	.Description
      	from each function call this Function Write-BISFFunctionName2Log to send the FucntionName to the Logfile for later easily troubleshooting

	.EXAMPLE
		Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})
		Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name}) -EntryPoint End
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 21.03.2016 MS: function created
		Last Change:

	.Link
#>
	Param(
	    [Parameter(Mandatory=$True)][string]$FunctionName,
		[parameter(Mandatory=$false)][ValidateSet("End")][ValidateNotNullOrEmpty()]$EntryPoint
	)
	IF ($EntryPoint -eq "End")
	{
		Write-BISFLog -Msg "End of function $FunctionName"
	} ELSE {
		Write-BISFLog -Msg "Processing function $FunctionName"
	}
}

function Set-LastRun
{
<#
    .SYNOPSIS
        Writes the current TimeStamp to the BISF registry to see see last BISF Run
	.Description


	.EXAMPLE
		Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})
		Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name}) -EntryPoint End
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 07.12.2016 MS: function created
		Last Change:

	.Link
#>
    $cu_user = $env:username
    IF ($State -eq "Preparation")
	{
        Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
        Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_PrepLastRunTime" -value $(Get-Date)
        Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_PrepLastRunUser" -value $cu_user
    }
}

function Get-MacAddress
{
<#
    .SYNOPSIS
        Get the Mac-Adress if the first adapter to use them with the GUID
	.Description
	.EXAMPLE
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 09.01.2017 MS: function created
		Last Change: 20.02.2017 MS: fix empty space given back from $mac, thx to Valentino

	.Link
#>

    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    $computer = $env:COMPUTERNAME
	$HostIP = [System.Net.Dns]::GetHostByName($computer).AddressList[0].IPAddressToString
	$wmi = gwmi -Class Win32_NetworkAdapterConfiguration -ComputerName $computer
	$mac = (($wmi | where { $_.IPAddress -eq $HostIP }).MACAddress)
	$Delimiter = ":"
    $mac = $mac -replace "$Delimiter",""
	Write-BISFLog -Msg "The MAC-Address for further use would be resolved: $mac"
	return $mac
}

function Test-AppLayeringSoftware {
	<#
    .SYNOPSIS
        check if the Citrix AppLayering Service installed
	.Description
      	if the Citrix AppLayering Service they will send a true or false value and will set the global variable ImageSW to true or false
		use get-help <functionname> -full to see full help

	.EXAMPLE
		Test-AppLayeringSoftware
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 25.07.2017 MS: function created
		Last Change: 27.07.2017 MS: add detection of OS, Platform and Application Layer
		Last Change: 31.07.2017 MS: add $Global:CTXAppLayerName
		Last Change: 01.08.2017 MS: Bugfix Test-AppLayeringSoftware, to much more bracket
		Last Change: 24.08.2017 MS: if OS and Platform/Appliaction Layer not detected, VM is not running inside ELM, give back $GLobal:CTXAppLayerName="No-ELM"
		Last Change: 29.10.2017 MS: Bugfix if VM is running outside ELM, different MachineState is set in registry
		Last Change: 25.02.2018 MS: Bugfix 241: AppLayering does not detect the right layer
		Last Change: 30.03.2018 MS: Bugfix 38: MachineState 3 not detected, Pre-ELM State, Layer finalized must not run
		Last Change: 01.07.2018 MS: Bugfix 48: Using RunMode to detect the right AppLayer, persistent between AppLayering updates
		Last Change: 09.07.2018 MS: Bugfix 48 - Part II: get DiskMode, to handle App Layering different
		Last Change: 09.07.2018 MS: Bugfix 48 - Part III: using DiskMode in RunMode 4 to diff between App- or Platform Layer
		Last Change: 21.10.2018 MS: Bugfix 62: BIS-F AppLayering - Layer Finalzed is blocked with MCS - Booting Layered Image
	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	#default values
	$Global:CTXAppLayeringSW = $false              # AppLayering is installed
	$Global:CTXAppLayeringOSLayer = $false       # OS Layer detected
	$Global:CTXAppLayeringPFLayer = $false       # Platform Layer detected
	$GLobal:CTXAppLayerName = $Null
	$svc = Test-BISFService -ServiceName "UniService" -ProductName "Citrix AppLayering"
	IF (($ImageSW -eq $false) -or ($ImageSW -eq $Null)) {IF ($svc -eq $true) { $Global:ImageSW = $true } }
	IF ($svc -eq $true) {
		$Global:CTXAppLayeringSW = $true
		$Global:CTXAppLayeringRunMode = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\unifltr).RunMode
		$DiskMode = Get-BISFDiskMode
		Write-BISFLog -Msg "DiskMode is set to $DiskMode"
		$svcSatus = Test-BISFServiceState -ServiceName "UniService" -Status "Running"
		IF (($DiskMode -eq "ReadWriteAppLayering") -or ($svcSatus -ne "Running")) {

			$CTXAppLayeringRunModeNew = 1
			Write-BISFLog "The origin App Layering RunMode ist set to $CTXAppLayeringRunMode , based on the DiskMode $DiskMode the RunMode is internally changed to $CTXAppLayeringRunModeNew to get the right layer"
			$CTXAppLayeringRunMode = $CTXAppLayeringRunModeNew
		}
		Switch ($CTXAppLayeringRunMode) {
			1 {
				$GLobal:CTXAppLayerName = "No-ELM"
			}

			3 {
				$Global:CTXAppLayeringOSLayer = $true
				$GLobal:CTXAppLayerName = "OS-Layer"
			}

			4 {
				$Global:CTXAppLayeringPFLayer = $true
				$Global:CTXAppLayerName = "Platform/Application Layer"
				IF ($DiskMode -eq "VDAPrivateAppLayering") {$Global:CTXAppLayeringPFLayer = $true; $Global:CTXAppLayerName = "Platform-Layer"}
				IF ($DiskMode -eq "UnmanagedAppLayering") {$Global:CTXAppLayeringAppLayer = $true; $Global:CTXAppLayerName = "Application-Layer"}

			}
			Default {Write-BISFLog -Msg "Not defined - AppLayering RunMode is set to $CTXAppLayeringRunMode" -ShowConsole -Type W}
		}
		Write-BISFLog -Msg "Citrix AppLayering - $CTXAppLayerName detected" -ShowConsole -SubMsg -Color DarkCyan

		<#
		$Global:AppLayMachineState = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\UniService).MachineState
		Write-BISFLog -Msg "AppLayering MachineState is set to $AppLayMachineState"
		$AppLayOS = Test-BISFRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\UniService" -Value "OSLayerEdit"
		$AppLayVS = Test-BISFRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\UniService" -Value "VolumeSerialNumber"
		$PrevBICTaskID = Test-BISFRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\UniService" -Value "PrevBICTaskID"
		Switch ($AppLayMachineState)
		{
			1 {	#VM not running inside ELM
				IF (($AppLayVS) -and ($PrevBICTaskID) -and ($CTXAppLayerName -eq $Null)) {Write-BISFLog -Msg "Citrix AppLayering - VM is not running inside ELM" -ShowConsole -SubMsg -Color DarkCyan; $GLobal:CTXAppLayerName="No-ELM"}
			}
			3 {
				#VM is running pre ELM, build VM before import
				IF ((!($AppLayOS)) -and (!($AppLayVS)) -and (!($PrevBICTaskID)) -and ($CTXAppLayerName -eq $Null)) {Write-BISFLog -Msg "Citrix AppLayering - VM is not running Pre-ELM" -ShowConsole -SubMsg -Color DarkCyan; $GLobal:CTXAppLayerName = "No-ELM"}
			}
			4 {
				IF (($AppLayOS) -and ($CTXAppLayerName -eq $Null)) {Write-BISFLog -Msg "Citrix AppLayering - OS Layer detected" -ShowConsole -SubMsg -Color DarkCyan; $Global:CTXAppLayeringOSLayer=$true; $GLobal:CTXAppLayerName="OS-Layer"}
				IF ((!($AppLayVS) -and ($CTXAppLayerName -eq $Null))) {Write-BISFLog -Msg "Citrix AppLayering - New Platform/Application Layer detected" -ShowConsole -SubMsg -Color DarkCyan; $Global:CTXAppLayeringPFLayer=$true; ; $GLobal:CTXAppLayerName="Platform/Application Layer"}
				IF (($AppLayVS) -and ($CTXAppLayerName -eq $Null)) {Write-BISFLog -Msg "Citrix AppLayering - Updated Platform/Application Layer detected" -ShowConsole -SubMsg -Color DarkCyan; $Global:CTXAppLayeringPFLayer=$true; ; $GLobal:CTXAppLayerName="Platform/Application Layer"}
			}
		Default {Write-BISFLog -Msg "Not defined - AppLayering MachineState is set to $AppLayMachineState" -ShowConsole -Type W}
		}
		#>
	}
	return $svc

}

function Use-PVSConfig{
	<#
    .SYNOPSIS
        Redirect Files to the PVS WriteCacheDisk
	.Description
      	IF Citrix PVS Target Device Driver is installed, the redirection of eventlogs, spool and other is necasaary
		use get-help <functionname> -full to see full help

	.EXAMPLE
		Use-BISFPVSConfig
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 27.07.2017 MS: function created
		Last Change: 01.08.2017 MS: if custom spool folder is enabled in ADMX; use this instead of BIS-F standard
		Last Change: 02.08.2017 MS: change to new ADMX structure to get custom Spool foldername
		Last Change: 31.08.2017 MS: bugfix - Eventlogs would be moved during Preparation only, this saved time during personalization
		Last Change: 04.09.2017 MS: bugfix - Eventlogs would be moved for both States (Prep and Pers) now
		Last Change: 03.11.2017 MS: if PVS Target Device Driver not installed, write info to BIS-F log and set the value $Global:Redirection=$true; $Global:RedirectionCode="NoPVS"
	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	IF ($returnTestPVSSoftware)
	{
		$Global:Redirection=$false
		Write-BISFLog -Msg "Check if redirection of Files to PVS WriteCacheDisk is possible" -ShowConsole -Color Cyan
		#enable redirection
		IF (($CTXAppLayeringSW -eq $false) -and ($State -eq"Preparation")) {$Global:Redirection=$true; $Global:RedirectionCode="PVS-NoAppLay-Prep" ;Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan}
		IF (($CTXAppLayeringSW -eq $false) -and ($State -eq"Personalization") -and ($computer -ne $LIC_BISF_RefSrv_HostName)) {$Global:Redirection=$true; $Global:RedirectionCode="PVS-NoAppLay-Pers-NoBI" ;Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan}
		IF (($CTXAppLayeringSW -eq $false) -and ($State -eq"Personalization") -and ($computer -eq $LIC_BISF_RefSrv_HostName)) {$Global:Redirection=$true; $Global:RedirectionCode="PVS-NoAppLay-Pers-BI" ;Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan}
		IF (($CTXAppLayeringSW -eq $true) -and ($State -eq"Personalization") -and ($computer -ne $LIC_BISF_RefSrv_HostName)) {$Global:Redirection=$true; $Global:RedirectionCode="PVS-AppLay-Pers-NoBI" ;Write-BISFLog -Msg "enable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan}

		#disable redirection
		IF (($CTXAppLayeringSW -eq $true) -and ($State -eq"Preparation")) {$Global:Redirection=$false; $Global:RedirectionCode="PVS-AppLay-Prep" ;Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan}
		IF (($CTXAppLayeringSW -eq $true) -and ($State -eq"Preparation") -and ($computer -eq $LIC_BISF_RefSrv_HostName)) {$Global:Redirection=$false; $Global:RedirectionCode="PVS-AppLay-Prep-BI" ;Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan}
		IF (($CTXAppLayeringSW -eq $true) -and ($State -eq"Personalization") -and ($computer -eq $LIC_BISF_RefSrv_HostName)) {$Global:Redirection=$false; $Global:RedirectionCode="PVS-AppLay-Pers-BI" ;Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan}

		IF ($Redirection -eq $true)
		{
			Write-BISFLog -Msg "Redirection is enabled with Code $RedirectionCode, configure it now" -ShowConsole -SubMsg -Color DarkCyan

			#Check redirection
			$Global:returnTestPVSEnvVariable=Test-BISFWriteCacheDiskDriveLetter -Verbose:$VerbosePreference
			IF ($State -eq "Preparation")
			{
				IF ($DiskMode -eq "ReadOnly") {Write-BISFLog -Msg "Mode $DiskMode - vDisk in Standard Mode, read access only!" -Type E -SubMsg}
				IF ($DiskMode -eq "Unmanaged") {
					IF($LIC_BISF_CLI_P2V_SKIP_IMG -eq 1)
					{
						Write-BISFLog -Msg "Mode $DiskMode - Policy 'Skip PVS master image creation' is enabled, so continuing" -SubMsg
					}
					ELSE {
						Write-BISFLog -Msg "Mode $DiskMode - No vDisk assigned to this Device" -Type E -SubMsg
					}
				}
				$Global:returnTestPVSDriveLetter=Test-BISFWriteCacheDisk -Verbose:$VerbosePreference
			}

			# test if custom spool folder is enabled
			IF ($LIC_BISF_CLI_SPb -eq "1") {$Global:LIC_BISF_SpoolPath = "$PVSDiskDrive\$LIC_BISF_CLI_SpoolFolder"}
			#redirect Spool directory

			# create redirected Spool directory
			Write-BISFLog -Msg "Redirect Spool directory to $LIC_BISF_SpoolPath" -ShowConsole -Color DarkCyan -SubMsg
			if (!(Test-Path -Path $LIC_BISF_SpoolPath))
			{
				Write-BISFLog -Msg "Create redirected Spool directory"
				New-Item -Path $LIC_BISF_SpoolPath -ItemType Directory -Force
			}
			$strRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers"
			Write-BISFLog -Msg "Configure redirected Spool directory in registry $strRegPath"
			Set-ItemProperty -Path $strRegPath  -Name "DefaultSpoolDirectory" -Value $LIC_BISF_SpoolPath

			# redirected eventlogs
		    Move-BISFEvtLogs
		} ELSE {
			Write-BISFLog -Msg "Redirection is disabled with Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan
		}
	} ELSE {
		$Global:Redirection=$true; $Global:RedirectionCode="NoPVS" ;Write-BISFLog -Msg "disable redirection - Code $RedirectionCode" -ShowConsole -SubMsg -Color DarkCyan
	}
}

function Move-EvtLogs
{
	<#
	.Synopsis
	   Enable all Eventlog and move Eventlogs to E:\Eventlogs
	.DESCRIPTION

	.EXAMPLE
	   Example of how to use this cmdlet
	.EXAMPLE
	   Another example of how to use this cmdlet
	.INPUTS
	   Inputs to this cmdlet (if any)
	.OUTPUTS
	   Output from this cmdlet (if any)
	.NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 29.07.2017 MS: function created, thx to Bernd Braun
		Last Change: 01.08.2017 MS: if custom eventlog folder is enabled in ADMX; use this instead of BIS-F standard
		Last Change: 02.08.2017 MS: change to new ADMX structure to get custom EventLog foldername
		Last Change: 11.11.2017 MS: Bugfix, show the right Eventlog during move to the WCD
	.COMPONENT
	   The component this cmdlet belongs to
	.ROLE
	   The role this cmdlet belongs to
	.FUNCTIONALITY
	   Enable all Eventlog and move Eventlogs to the PVS WriteCacheDisk if Redirection is enabled function Use-BISFPVSConfig  #>

	#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	# test if custom searchfolder is enabled
	IF ($LIC_BISF_CLI_EVTb -eq "1") {$Global:LIC_BISF_EvtPath = "$PVSDiskDrive\$LIC_BISF_CLI_EvtFolder"}

	Write-BISFLog -Msg "Move Eventlogs to the PVS WriteCacheDisk" -ShowConsole -Color Cyan
	If (!(Test-Path -Path $LIC_BISF_EvtPath))
	{
		Write-BISFLog -Msg "Create Eventlog directory $LIC_BISF_EvtPath"
        New-Item -Path $LIC_BISF_EvtPath -ItemType Directory -Force
    }
	$appvlogs = Get-WinEvent -ListLog "*" -force -ErrorAction SilentlyContinue| Where-Object {$_.IsEnabled -eq $false}

	foreach ($logitem in $appvlogs) {
		 $x = $logitem.LogName
		 Write-BISFLog -Msg "Eventlog enabled: $x"
	 #    $logitem.IsEnabled = $true
		 $LogfilePath = "$LIC_BISF_EvtPath\" + $logitem.logName + ".evtx"
		 $Logfilepath = $LogFilePath.Replace("/", "")

		 Write-BISFLog -Msg "Path:`t`t $LogfilePath" -ShowConsole -SubMsg -Color DarkCyan
		 $logitem.LogFilePath = $Logfilepath
		 Try {
			$logitem.SaveChanges()
		 }
		 Catch [System.Management.Automation.MethodInvocationException] {
			#$Error | Get-Member
			#$Error.Data
			#$Error.ErrorRecord
			#$Error.Errors
			$x = $_.Exception.Message
			Write-BISFLog -Msg “Error:`t`t $x" -Type W

			#Exit
		 }
		 Catch {
			$Error[0].Exception.GetType().fullname
		 }
		# Write-BISFLog -Msg "`n`n"
	}


	$appvlogs = Get-WinEvent -ListLog "*" -force -ErrorAction SilentlyContinue| Where-Object {$_.IsEnabled -eq $true}

	foreach ($logitem in $appvlogs) {
		 $x = $logitem.LogName
		 Write-BISFLog -Msg “Log enabled: $x"
	#     $logitem.IsEnabled = $true
		 $LogfilePath = "$LIC_BISF_EvtPath\" + $logitem.logName + ".evtx"
		 $Logfilepath = $LogFilePath.Replace("/", "")

		 Write-BISFLog -Msg "Path:`t`t $LogfilePath" -ShowConsole -SubMsg -Color DarkCyan
		 $logitem.LogFilePath = $Logfilepath
		 Try {
			$logitem.SaveChanges()
		 }
		 Catch [System.Management.Automation.MethodInvocationException] {
			#$Error | Get-Member
			#$Error.Data
			#$Error.ErrorRecord
			#$Error.Errors
			$x = $_.Exception.Message
			Write-BISFLog -Msg “Error:`t`t $x" -Type W

			#Exit
		 }
		 Catch {
			$Error[0].Exception.GetType().fullname
		 }
		 #Write-BISFLog -Msg "`n`n"
	}

	$appvlogs = Get-WinEvent -ListLog "Microsoft-Windows-TerminalServices-SessionBroker-*" -force -ErrorAction SilentlyContinue| Where-Object {$_.IsEnabled -eq $true}

	foreach ($logitem in $appvlogs) {
		 $x = $logitem.LogName
		 Write-BISFLog -Msg “Log enabled: $x"
		 $logitem.IsEnabled = $false
		 $LogfilePath = "$LIC_BISF_EvtPath\" + $logitem.logName + ".evtx"
		 $Logfilepath = $LogFilePath.Replace("/", "")

		 Write-BISFLog -Msg "Path:`t`t $LogfilePath" -ShowConsole -SubMsg -Color DarkCyan
		 $logitem.LogFilePath = $Logfilepath
		 Try {
			$logitem.SaveChanges()
		 }
		 Catch [System.Management.Automation.MethodInvocationException] {
			#$Error | Get-Member
			#$Error.Data
			#$Error.ErrorRecord
			#$Error.Errors
			$x = $_.Exception.Message
			Write-BISFLog -Msg “Error:`t`t $x" -Type W

			#Exit
		 }
		 Catch {
			$Error[0].Exception.GetType().fullname
		 }
		 #Write-BISFLog -Msg "`n`n"
	}
	$appvlogs = Get-WinEvent -ListLog "Microsoft-Windows-TerminalServices-SessionBroker-*" -force -ErrorAction SilentlyContinue| Where-Object {$_.IsEnabled -eq $false}

	foreach ($logitem in $appvlogs) {
		 $x = $logitem.LogName
		 Write-BISFLog -Msg “Log enabled: $x"
		 $LogfilePath = "$LIC_BISF_EvtPath\" + $logitem.logName + ".evtx"
		 $Logfilepath = $LogFilePath.Replace("/", "")

		 Write-BISFLog -Msg "Path:`t`t $LogfilePath" -ShowConsole -SubMsg -Color DarkCyan
		 $logitem.LogFilePath = $Logfilepath
		 Try {
			$logitem.SaveChanges()
		 }
		 Catch [System.Management.Automation.MethodInvocationException] {
			#$Error | Get-Member
			#$Error.Data
			#$Error.ErrorRecord
			#$Error.Errors
			$x = $_.Exception.Message
			Write-BISFLog -Msg "Error:`t`t $x" -Type W

			#Exit
		 }
		 Catch {
			$Error[0].Exception.GetType().fullname
		 }
		 #Write-BISFLog -Msg "`n`n"
	}
}

function Get-BootMode {
<#
    .SYNOPSIS
        get System BootMode
		Determines underlying firmware (BIOS) type and returns True for UEFI or False for legacy BIOS.
	.Description
      	This function uses a complied Win32 API call to determine the underlying system firmware type.
		get System BootMode back as follows
			UEFI
			Legacy
		use get-help <functionname> -full to see full help
    .EXAMPLE
		$BootMode = Get-BISFBootMode

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 03.08.2017 MS: function created
		Last Change: 17.09.2017 MS: change to new API Call, get from https://gallery.technet.microsoft.com/scriptcenter/Determine-UEFI-or-Legacy-7dc79488
		Last Change: 03.11.2017 MS: writing BootMode (UEFI or Legacy) in Function to BISF log
	.Link
#>

[OutputType([Bool])]
Param ()


	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	Add-Type -Language CSharp -TypeDefinition @'

    using System;
    using System.Runtime.InteropServices;

    public class CheckUEFI
    {
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern UInt32
        GetFirmwareEnvironmentVariableA(string lpName, string lpGuid, IntPtr pBuffer, UInt32 nSize);

        const int ERROR_INVALID_FUNCTION = 1;

        public static bool IsUEFI()
        {
            // Try to call the GetFirmwareEnvironmentVariable API.  This is invalid on legacy BIOS.

            GetFirmwareEnvironmentVariableA("","{00000000-0000-0000-0000-000000000000}",IntPtr.Zero,0);

            if (Marshal.GetLastWin32Error() == ERROR_INVALID_FUNCTION)

                return false;     // API not supported; this is a legacy BIOS

            else

                return true;      // API error (expected) but call is supported.  This is UEFI.
        }
    }
'@


	$a= [CheckUEFI]::IsUEFI()
    IF ($a -eq $true) {Write-BISFLog -Msg "BootMode UEFI detected";return "UEFI"} ELSE {Write-BISFLog -Msg "BootMode Legacy detected";return "Legacy"}

}

Function Export-Registry {

<#
   .Synopsis
    Export registry item properties.
    .Description
    Export item properties for a give registry key. The default is to write results to the pipeline
    but you can export to either a CSV or XML file. Use -NoBinary to omit any binary registry values.
    .Parameter Path
    The path to the registry key to export.
    .Parameter ExportType
    The type of export, either CSV or XML.
    .Parameter ExportPath
    The filename for the export file.
    .Parameter NoBinary
    Do not export any binary registry values
   .Example
    PS C:\> Export-BISFRegistry "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -ExportType xml -exportpath c:\files\WinLogon.xml

   .Notes
    NAME: Export-BISFRegistry
    Author: Jeffery Hicks / Matthias Schlimm
	Company: Login Consultants Germany GmbH

	History
	Last Change: 14.08.2017 MS : import function into BIS-F
	Last Change: 15.08.2017 MS : Writing the second XML File, these file must be copied to the BIS-F Root Installation folder

#>

[cmdletBinding()]

Param(
[Parameter(Position=0,Mandatory=$True,
HelpMessage="Enter a registry path using the PSDrive format.",
ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
[ValidateScript({(Test-Path $_) -AND ((Get-Item $_).PSProvider.Name -match "Registry")})]
[Alias("PSPath")]
[string[]]$Path,

[Parameter()]
[ValidateSet("csv","xml")]
[string]$ExportType,

[Parameter()]
[string]$ExportPath,

[switch]$NoBinary

)

Begin {
    Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	Write-BISFlog "Starting registry Export" -ShowConsole -Color Cyan
    #initialize an array to hold the results
    $data=@()
 } #close Begin

Process {
    #go through each pipelined path
    Foreach ($item in $path) {
        Write-BISFlog "Getting $item" -ShowConsole -Color DarkCyan -SubMsg
        $regItem=Get-Item -Path $item
        #get property names
        $properties= $RegItem.Property
        Write-BISFlog "Retrieved $(($properties | measure-object).count) properties" -ShowConsole -Color DarkCyan -SubMsg
        if (-not ($properties))
            {
                #no item properties were found so create a default entry
                $value=$Null
                $PropertyItem="(Default)"
                $RegType="String"

                #create a custom object for each entry and add it the temporary array
                $data+=New-Object -TypeName PSObject -Property @{
                    "Path"=$item
                    "Name"=$propertyItem
                    "Value"=$value
                    "Type"=$regType
                    #"Computername"=$env:computername
                 }
            }

            else
            {
            #enumrate each property getting itsname,value and type
            foreach ($property in $properties) {
                Write-BISFlog "Exporting $property" -ShowConsole -Color DarkCyan -SubMsg
                $value=$regItem.GetValue($property,$null,"DoNotExpandEnvironmentNames")
                #get the registry value type
                $regType=$regItem.GetValueKind($property)
                $PropertyItem=$property

                #create a custom object for each entry and add it the temporary array
                $data+=New-Object -TypeName PSObject -Property @{
                    "Path"=$item
                    "Name"=$propertyItem
                    "Value"=$value
                    "Type"=$regType
                    #"Computername"=$env:computername
                 }
               } #foreach
            } #else
    }#close Foreach
 } #close process

End {
  #make sure we got something back
  if ($data)
  {
    #filter out binary if specified
    if ($NoBinary)
    {
        Write-BISFlog "Removing binary values" -ShowConsole -Color DarkCyan -SubMsg
        $data=$data | Where {$_.Type -ne "Binary"}
    }

    #export to a file both a type and path were specified
    if ($ExportType -AND $ExportPath)
    {
      Write-BISFlog "Exporting $ExportType data to $ExportPath" -ShowConsole -Color DarkCyan -SubMsg
      Switch ($exportType) {
        "csv" { $data | Export-CSV -Path $ExportPath -noTypeInformation }
        "xml" { $data | Export-CLIXML -Path $ExportPath }
    } #switch


	#Writing the second XML File, these file must be copied to the BIS-F Root Installation folder
	# Set the File Name
	$filePath = "$LIC_BISF_CLI_EX_PT" + "\BISFSharedConfig.xml "
	Write-BISFlog -Msg "Writing $filePath - copy this file to the BIS-F installation folder, like $InstallLocation on your destination computer (example: Citrix AppLayering in Workergroup)," -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "to import the BIS-F configuration from $($ExportPath). If you run the Computer in Workgroup you must set the shared path NTFS Rights to ""Everyone read"" to get access without prompt."

	# Create The Document
	$XmlWriter = New-Object System.XMl.XmlTextWriter($filePath,$Null)

	# Set The Formatting
	$xmlWriter.Formatting = "Indented"
	$xmlWriter.Indentation = "1"
	# Write the XML Decleration
	$xmlWriter.WriteStartDocument()
	# Write Comment
	$xmlWriter.WriteComment('Path to the BIS-F XML Configuration, if you run the Computer in Workgroup you must set the shared path NTFS Rights to "Everyone read" to get access without prompt.')
	# Write Root Element
	$xmlWriter.WriteStartElement("BISFconfig")
	# Write the Document
	$xmlWriter.WriteElementString("ConfigFile","$ExportPath")
	# Finish The Document
	$xmlWriter.Finalize
	$xmlWriter.Close()

	} #if $exportType
    elseif ( ($ExportType -AND (-not $ExportPath)) -OR ($ExportPath -AND (-not $ExportType)) )
    {
        Write-BISFlog "You forgot to specify both an export type and file." -ShowConsole -Type W -SubMsg
    }
    else
    {
        #write data to the pipeline
        $data
    }
   } #if $#data
   else
   {
        Write-BISFlog "No data found" -ShowConsole -Type W -SubMsg
   }
     #exit the function
 } #close End

} #end Function


function Import-SharedConfiguration {
<#
    .SYNOPSIS
        Import Shared Configuration from XML file
	.Description
      	if the BISFSharedConfiguration.xml does exist in the root of the BIS-F installation folder, read the XML and get the path to the SharedConfiguration

		use get-help <functionname> -full to see full help
    .EXAMPLE
		Import-BISFSharedConfiguration

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 15.08.2017 MS: function created
		Last Change:
	.Link
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$XMLConfigFile = "$InstallLocation" + "BISFSharedConfig.xml"
	IF (Test-Path $XMLConfigFile -PathType Leaf)
	{
		Write-BISFlog "Reading Shared Configuration from file $XMLConfigFile" -ShowConsole -SubMsg -Color DarkCyan
		[xml]$XmlDocument = Get-Content -Path "$XMLConfigFile"
		$xmlfullname = $XmlDocument.GetType().FullName
		$xmlSharedConfigFile = $XmlDocument.BISFconfig.ConfigFile
		Write-BISFlog "Shared Configuration is stored in $xmlSharedConfigFile" -ShowConsole -SubMsg -Color DarkCyan
		IF (Test-Path $xmlSharedConfigFile -PathType Leaf)
		{
			IF (!(Test-Path $Reg_LIC_Policies)) {
				New-Item -Path $hklm_sw_pol -Name $LIC -Force | Out-Null
				New-Item -Path $hklm_sw_pol"\"$LIC -Name $CTX_BISF_SCRIPTS -Force | Out-Null
				write-BISFlog -Msg "create RegHive $Reg_LIC_Policies"
			}
			Write-BISFlog "Import XML Configuration into local Registry to path $Reg_LIC_Policies" -ShowConsole -SubMsg -Color DarkCyan
			$object = Import-CliXML "$xmlSharedConfigFile"
			$object | foreach {New-ItemProperty -path $_.path -name $_.Name -value $_.Value -PropertyType $_.Type -Force | out-Null}

		} ELSE {
			Write-BISFlog "Error: Shared Configuration $xmlSharedConfigFile does not exists !!" -Type E
		}
	} ELSE {
		Write-BISFlog "Shared Configuration does not exist in $ConfigFile"
	}
}

function Remove-FolderAndContents {
	<#
    .SYNOPSIS
        Reomve folder and contents
	.Description
      	Remove the complete content including subfolders of an specified folder

		use get-help <functionname> -full to see full help
    .EXAMPLE
		Remove-BISFFolderAndContents ("C:\windows\temp")

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 22.08.2017 MS: function created
		Last Change:
	.Link
	  # http://stackoverflow.com/a/9012108
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
    param(
        [Parameter(Mandatory=$true, Position=1)] [string] $folder_path
    )

    process {
        $child_items = ([array] (Get-ChildItem -Path $folder_path -Recurse -Force))
        if ($child_items) {
            $null = $child_items | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue -Confirm:$False
        }
        $null = Remove-Item $folder_path -Force -Recurse -Confirm:$False -ErrorAction SilentlyContinue
    }
}

function Start-CDS
{
		<#
    .SYNOPSIS
        Starts the Citrix Desktop Service
	.Description
      	if the Delay Citrix Desktop Service is configured
		through ADMX, this service would be started

		use get-help <functionname> -full to see full help
    .EXAMPLE
		Start-BISFCDS

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 10.09.2017 MS: function created
		Last Change: 12.09.2017 MS: Changing to $servicename = "BrokerAgent"
	.Link
	  #
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function

	IF ($returnTestXDSoftware -eq "true")   # Citrix VDA only
	{
		$servicename = "BrokerAgent"
		IF ($LIC_BISF_CLI_CDS -eq "1")
		{
			Write-BISFLog -Msg "The $servicename would configured through ADMX.. delay operation configured" -ShowConsole -Color Cyan
			Invoke-BISFService -ServiceName "$servicename" -Action Start -StartType Automatic
		} ELSE {
			Write-BISFLog -Msg "The $servicename would not configured through ADMX.. normal operation state"
		}

	}

}

function Start-VHDOfflineDefrag
{
	<#
    .SYNOPSIS
        Mount the VHD(X) File on the UNC-Path and defrag it
	.Description
      	If using Custom UNC-Path to convert the BaseDisk,
		the vdisk on on the unc-path will be mounted and defrag

		use get-help <functionname> -full to see full help
    .EXAMPLE
		Start-BISFVHDOfflineDefrag

    .Inputs
    .Outputs
    .NOTES
		Author: Dennis Span (http://dennisspan.com)


		History
      	Last Change: 11.10.2017 DD: Script created
		Last Change: 18.10.2017 MS: Implement function in BIS-F
		Last Change: 15.11.2017 MS: on the Mounted Disk, the same UniqueID must be set to fix boot recored issues (https://blogs.technet.microsoft.com/markrussinovich/2011/11/06/fixing-disk-signature-collisions/)
	.Link
	  #
#>
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function

		# define Error handling
		# note: do not change these values
		$global:ErrorActionPreference = "Stop"

		# Disable File Security
		$env:SEE_MASK_NOZONECHECKS = 1

		Write-BISFLog -Msg "Starting Offline $vhdext defrag" -ShowConsole -Color Cyan

		# Check if the VHD(X) file exists
		Write-BISFLog -Msg "Check if the $vhdext file '$VHDFileToDefrag' exists"
		if ( (Test-Path $VHDFileToDefrag ) -eq $True ) {
			Write-BISFLog -Msg "The $vhdext file '$VHDFileToDefrag' exists" -ShowConsole -Color DarkCyan -SubMsg
		} else {
			Write-BISFLog -Msg "The $vhdext file '$VHDFileToDefrag' does NOT exist or cannot be reached" -ShowConsole -SubMsg -Type E
		}

		# Retrieve drives before mounting the VHD(X)
		$DrivesAvailableBeforeVHDMount = (Get-PSDrive -PsProvider FileSystem).Name
		Write-BISFLog -Msg "Retrieve available drives (before mount): $([string]$DrivesAvailableBeforeVHDMount)" -ShowConsole -Color DarkCyan -SubMsg


		# Mount VHD(X) (using cvhdmount.exe)
		$tmpLogFile = "C:\Windows\logs\BISFtmpProcessLog.log"
		Write-BISFLog -Msg "Mount (attach) the $vhdext (using cvhdmount.exe)" -ShowConsole -Color DarkCyan -SubMsg
		$process = start-process -FilePath "C:\Program Files\Citrix\Provisioning Services\CVhdMount.exe" -ArgumentList "-p 1 ""$VHDFileToDefrag""" -wait -PassThru -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
        Get-BISFLogContent -GetLogFile "$tmpLogFile"
		Remove-Item -Path "$tmpLogFile" -Force | Out-Null
		$ProcessExitCode = $Process.ExitCode
		Start-Sleep -Seconds 5

		Write-BISFLog -Msg "bring the attached $vhdext online" -ShowConsole -Color DarkCyan -SubMsg
        $process = start-process -FilePath "C:\Program Files\Citrix\Provisioning Services\CVhdMount.exe" -ArgumentList "-o 1 ""$VHDFileToDefrag""" -wait -PassThru -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
        $ProcessExitCode = $Process.ExitCode
		Get-BISFLogContent -GetLogFile "$tmpLogFile"
		Remove-Item -Path "$tmpLogFile" -Force | Out-Null
		Start-Sleep -Seconds 5
		Write-BISFLog -Msg "The $vhdext file was mounted successfully" -ShowConsole -Color DarkCyan -SubMsg


		# Retrieve drives after mounting the VHD(X)
		$DrivesAvailableAfterVHDMount = (Get-PSDrive -PsProvider FileSystem).Name
		Write-BISFLog -Msg "Retrieve available drives (after mount): $([string]$DrivesAvailableAfterVHDMount)" -ShowConsole -Color DarkCyan -SubMsg

		# Check which drive letter or driver letters were added after mounting the VHD(X) file (drive letters are written without a colon; e.g. "D" instead of "D:")
		try {
			[array]$Drives = ((Compare-Object $DrivesAvailableBeforeVHDMount $DrivesAvailableAfterVHDMount).InputObject).ToUpper()
		} catch {
			Write-BISFLog -Msg "No additional drives were detected. It is possible that the $vhdext file was mounted, but that no drive letter could be assigned" -ShowConsole -SubMsg -Type W
			Write-BISFLog -Msg "Please make sure you are using a valid $vhdext file containing a Windows operating system (Windows 7/Windows Server 2008 R2 or higher)" -ShowConsole -SubMsg -Type E
		}

		# Continue check which drive letter or driver letters were added after mounting the VHD(X) file (drive letters are written without a colon; e.g. "D" instead of "D:")
		$DriveCount = $Drives.Count
		switch ($DriveCount)
		{
			0 {
				Write-BISFLog -Msg "No new drives were added. Apparently the $vhdext mount did not succeed" -ShowConsole -SubMsg -Type E
			}
			1 {
				# One additional drive will be found when capturing an operating system WITHOUT a 'System Reserved' boot partition (e.g. Windows 7, Windows Server 2008 R2)
				[string]$DriveLetterToDefrag = "$($Drives):"
				Write-BISFLog -Msg "One new drive was added: $DriveLetterToDefrag" -ShowConsole -SubMsg -Color DarkCyan
			}
			2 {
				# Two additional drives will be found when capturing an operating system WITH a 'System Reserved' boot partition (e.g. Windows 10, Windows Server 2016)
				Write-BISFLog -Msg "Two new drives were added. Checking which drive requires offline defragmentation" -ShowConsole -SubMsg -Color DarkCyan
				foreach ( $Drive in $Drives ) {
					Write-BISFLog -Msg "Checking drive $($Drive):" -ShowConsole -SubMsg -Color DarkCyan
					if ( (Get-WmiObject -Class win32_volume -Filter "DriveLetter = '$($Drive):'").Label -like "*Reserved*") {
						Write-BISFLog -Msg "Drive $($Drive): is the 'System Reserved' drive. This one does not require offline defragmentation" -ShowConsole -SubMsg -Color DarkCyan
					} else {
						Write-BISFLog -Msg "Drive $($Drive): is the primary partition and requires offline defragmentation" -ShowConsole -SubMsg -Color DarkCyan
						[string]$DriveLetterToDefrag = "$($Drive):"
					}
				}
			}
			default {
				Write-BISFLog -Msg "More than two new drives were added. This script is not able to verify which drive needs offline defragmentation" -ShowConsole -SubMsg -Type E
			}
		}


		# Defrag VHD(X)
		Write-BISFLog -Msg "Defragging the $vhdext mounted to drive $DriveLetterToDefrag..." -ShowConsole -SubMsg -Color DarkCyan
		$Process = Start-BISFProcWithProgBar -ProcPath "$($env:windir)\system32\defrag.exe" -Args "$DriveLetterToDefrag" -ActText "Defrag is running with mounted $vhdext $VHDFileToDefrag on Drive $DriveLetterToDefrag"
		$ProcessExitCode = $Process.ExitCode
		Write-BISFLog -Msg  "ExitCode: $ProcessExitCode"
        if (($ProcessExitCode -eq 0 ) -or ($ProcessExitCode -eq $null )) {
			Write-BISFLog -Msg "Defrag drive $DriveLetterToDefrag completed successfully" -ShowConsole -SubMsg -Color DarkCyan
		} else {
			Write-BISFLog -Msg "An error occurred while attempting to defrag drive $DriveLetterToDefrag (error: $ProcessExitCode)" -ShowConsole -SubMsg -Type E
		}

		#fixfing DiskID before unmount
		# Get uniqueid SystemDrive
        Get-BISFDiskID -Driveletter C:
		$DiskIDOSDisk = $DiskID

		#Set same UniqueID from SystemDrive on mounted VHD(X)
		$DiskIDVHDX = Get-BISFDiskID -Driveletter $DriveLetterToDefrag
		$DiskIDVHDX = $DiskID
		$VolNbrVHDX = $VolNbr
		Write-BISFLog -Msg "UniqueID on SystemDrive is $DiskIDOSDisk  - UniqueID on mounted $vhdext is $DiskIDVHDX" -ShowConsole -Color DarkCyan -SubMsg
		IF (!($DiskIDOSDisk -eq $DiskIDVHDX))
		{
			Write-BISFLog -Msg "Set same UniqueID from SystemDrive on mounted $vhdext - Drive $DriveLetterToDefrag" -ShowConsole -Type W -SubMsg
			$DiskpartFile = "$env:TEMP\$computer-DiskpartFile.txt"
			If (Test-Path $DiskpartFile){Remove-Item $DiskpartFile -Force}

			"select volume $VolNbrVHDX" | out-file -filepath $DiskpartFile -encoding Default
			"uniqueid disk ID=$DiskIDOSDisk" | out-file -filepath $DiskpartFile -encoding Default -append
			get-LogContent -GetLogFile "$DiskpartFile"
			diskpart /s $DiskpartFile
			Write-BISFLog -Msg "Disk ID $DiskIDOSDisk is set on $DriveLetterToDefrag"
			} ELSE {
		 Write-BISFLog "DiskID on both Disks are equal, no changes necessary !" -ShowConsole -Color DarkCyan -SubMsg
		}

		# Un-mount VHD(X) (using diskpart)
		Write-BISFLog -Msg "Un-mount (detach) the $vhdext (using CVhdMount.exe)" -ShowConsole -SubMsg -Color DarkCyan
		$process = start-process -FilePath "C:\Program Files\Citrix\Provisioning Services\CVhdMount.exe" -ArgumentList "-u 1 ""$VHDFileToDefrag""" -Wait -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
		$ProcessExitCode = $Process.ExitCode
		Write-BISFLog -Msg  "ExitCode: $ProcessExitCode"
		Get-BISFLogContent -GetLogFile "$tmpLogFile"
		Remove-Item -Path "$tmpLogFile" -Force | Out-Null
		Start-Sleep -Seconds 5
		# Enable File Security
		Remove-Item env:\SEE_MASK_NOZONECHECKS
		$global:VerbosePreference = "Continue"

}

Function Get-DiskID
{
<#
    .SYNOPSIS
        Get the unique ID of the Driveletter

		use get-help <functionname> -full to see full help
    .EXAMPLE
		Get-BISFDiskID -Driveletter C:

    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm


		History
      	Last Change: 15.11.2017 MS: Script created

	.Link
	  #
#>

PARAM(
		[parameter(Mandatory=$True)][string]$Driveletter
	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$DiskpartFile = "$env:TEMP\$computer-DiskpartFile.txt"
	Write-BISFLog -Msg "Get UniqueID from Drive $DriveLetter" -ShowConsole -Color DarkCyan -SubMsg
    $DriveLetter = $DriveLetter.substring(0,1)
    Write-BISFLog -Msg "use Diskpart, search Driveletter $DriveLetter"

    $Searchvol = "list volume" | diskpart | select-string -pattern "Volume" | select-string -pattern "$DriveLetter " -casesensitive | select-string -pattern NTFS | out-string
	Write-BISFLog -Msg "$Searchvol"

    $getvolNbr    = $Searchvol.substring(11,1)   # get Volumenumber from DiskLabel
    Write-BISFLog -Msg "Get Volumenumber $getvolNbr from Disklabel $DriveLetter"

    Remove-Item $DiskpartFile -recurse -ErrorAction SilentlyContinue
    # Write Diskpart File
    "select volume $getvolNbr" | out-file -filepath $DiskpartFile -encoding Default
	"uniqueid disk" | out-file -filepath $DiskpartFile -encoding Default -append
    $result = diskpart /s $DiskpartFile
	get-BISFLogContent -GetLogFile "$DiskpartFile"
    $DiskID = $result | select-string -pattern "ID" -casesensitive | out-string
    $DiskID = $DiskID.Split(":")  #split string on ":"
	$DiskID = $DiskID[1] #get the first string after ":" to get the Disk ID only without the Text
	$DiskID = $DiskID.trim() #remove empty spaces on the right and left
    $start = $DiskID.length
	IF ($start -eq "8")
	{
		Write-BISFLog -Msg "MBR Disk with $start characters identfied"

	} ELSE {
		Write-BISFLog -Msg "GPT Disk with $start characters identfied"
	}
    Write-BISFLog -Msg "UniqueID Disk of Drive $Driveletter is $DiskID"
	$Global:DiskID = $DiskID
	$Global:VolNbr = $getvolNbr
}

function Test-ServiceState {
	<#
    .SYNOPSIS
        check the State of the Service
	.Description
      	After changing a Service from automatic to manual for example, it's necasaary to test of the service has the right state before continue
		use get-help <functionname> -full to see full help
    .EXAMPLE
		The Windows Update Service will be checked if the stopped
		 Test-BISFServiceState -ServiceName wuauserv -Status stopped
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm,
      	Company: EUCweb.com

		History
      	Last Change: 01.07.2018 MS: Hotfix 49 - function created
		Last Change: 21.10.2018 MS: add return $($svc.Status)
	.Link
#>

	param (
		# Specifies the ServiceName
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]$ServiceName,

		# Specifies the Starttype: Disabled, Manual, Automatic
		[parameter(Mandatory = $false)]
		[ValidateSet("Running","Stopped")]
		[ValidateNotNullOrEmpty()]$Status

	)
	Write-BISFFunctionName2Log -FunctionName ($MyInvocation.MyCommand | % {$_.Name})  #must be added at the begin to each function
	$svc = Get-Service $Servicename

	IF ($Status -eq $svc.Status )
	{
		Write-BISFlog -Msg "The Service $($svc.DisplayName) is successfully in $($svc.Status) state"
	}	else {
		Write-BISFlog -Msg "The Service $($svc.DisplayName) is NOT successfully in $Status state" -Type W -SubMsg
	}
	return $svc.Status
}
