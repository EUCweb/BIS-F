<#
    .Synopsis
      Updates Symantec Virus Definitions to the latest off the internet
    .Description
      Updates Symantec Virus Definitions to the latest off the internet.  FTP functions taken from the PowerShell FTP client module by Michal Gajda (https://gallery.technet.microsoft.com/scriptcenter/PowerShell-FTP-Client-db6fe0cb)
      Tested on 2012R2, 2008 R2
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Trentent Tye
      Editor: Trentent Tye
      Company: TheoryPC

      History
      Last Change: 2017.07.09 TT: Script created
	  Last Change: 2018.08.08 TT: Tested on 2008 R2
	  .Link
    #>

Begin{
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

	#product specified
	$Product = "Symantec Enterprise Protection"
	$SEP_path = "${env:Programfiles(x86)}\Symantec\Symantec Endpoint Protection"
	$updateVirusDefs = $true
}

Process {
####################################################################
####### functions #####
####################################################################
    Function Set-FTPConnection
    {
        <#
	    .SYNOPSIS
	        Set config to ftp Connection.

	    .DESCRIPTION
	        The Set-FTPConnection cmdlet creates a Windows PowerShell configuration to ftp server. When you create a ftp connection, you may run multiple commands that use this config.
		
	    .PARAMETER Credential
	        Specifies a user account that has permission to access to ftp location.
			
	    .PARAMETER Server
	        Specifies the ftp server you want to connect. 
			
	    .PARAMETER EnableSsl
	        Specifies that an SSL connection should be used. 
			
	    .PARAMETER ignoreCert
	        If you use SSL connection you may ignore certificate error. 
			
	    .PARAMETER KeepAlive
	        Specifies whether the control connection to the ftp server is closed after the request completes.  
			
	    .PARAMETER UseBinary
	        Specifies the data type for file transfers.  
			
	    .PARAMETER UsePassive
	        Behavior of a client application's data transfer process. 

	    .PARAMETER Session
	        Specifies a friendly name for the ftp session. Default session name is 'DefaultFTPSession'.
	
	    .EXAMPLE

		    Set-FTPConnection -Credentials userName -Server myftpserver.com
		
	    .EXAMPLE

		    $Credentials = Get-Credential
		    Set-FTPConnection -Credentials $Credentials -Server ftp://myftpserver.com -EnableSsl -ignoreCert -UsePassive

	    .NOTES
		    Author: Michal Gajda
		    Blog  : http://commandlinegeeks.com/

	    .LINK
            Get-FTPChildItem
	    #>    

	    [CmdletBinding(
    	    SupportsShouldProcess=$True,
            ConfirmImpact="Low"
        )]
        Param(
		    [parameter(Mandatory=$true)]
		    [Alias("Credential")]
		    $Credentials, 
		    [parameter(Mandatory=$true)]
		    [String]$Server,
		    [Switch]$EnableSsl = $False,
		    [Switch]$ignoreCert = $False,
		    [Switch]$KeepAlive = $False,
		    [Switch]$UseBinary = $False,
		    [Switch]$UsePassive = $False,
		    [String]$Session = "DefaultFTPSession"
	    )
	
	    Begin
	    {
		    if($Credentials -isnot [System.Management.Automation.PSCredential])
		    {
			    $Credentials = Get-Credential $Credentials
		    }
	    }
	
	    Process
	    {
            if ($pscmdlet.ShouldProcess($Server,"Connect to FTP Server")) 
		    {	
			    if(!($Server -match "ftp://"))
			    {
				    $Server = "ftp://"+$Server	
				    Write-Debug "Add ftp:// at start: $Server"				
			    }
			
			    Write-Verbose "Create FtpWebRequest object."
			    [System.Net.FtpWebRequest]$Request = [System.Net.WebRequest]::Create($Server)
			    $Request.Credentials = $Credentials
			    $Request.EnableSsl = $EnableSsl
			    $Request.KeepAlive = $KeepAlive
			    $Request.UseBinary = $UseBinary
			    $Request.UsePassive = $UsePassive
			    $Request | Add-Member -MemberType NoteProperty -Name ignoreCert -Value $ignoreCert
			    $Request | Add-Member -MemberType NoteProperty -Name Session -Value $Session

			    $Request.Method = [System.Net.WebRequestMethods+FTP]::ListDirectoryDetails
			    Try
			    {
				    #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$ignoreCert} ##TTYE - This call will break future invoke-webrequest's that use https to a new site --> https://blogs.technet.microsoft.com/bshukla/2010/04/12/ignoring-ssl-trust-in-powershell-system-net-webclient/
				    $Response = $Request.GetResponse()
				    $Response.Close()
				
				    if((Get-Variable -Scope Global -Name $Session -ErrorAction SilentlyContinue) -eq $null)
				    {
					    Write-Verbose "Create global variable: $Session"
					    New-Variable -Scope Global -Name $Session -Value $Request
				    }
				    else
				    {
					    Write-Verbose "Set global variable: $Session"
					    Set-Variable -Scope Global -Name $Session -Value $Request
				    }
				
				    Return $Response
			    }
			    Catch
			    {
				    Write-Error $_.Exception.Message -ErrorAction Stop 
			    }
		    }
	    }
	
	    End{}				
    }

    Function Get-FTPConnection
    {
        <#
	    .SYNOPSIS
	        Get config to ftp Connection.

	    .DESCRIPTION
	        The Get-FTPConnection cmdlet create a list of registered PSFTP sessions.
		
	    .PARAMETER Session
	        Specifies a friendly name for the ftp session.
	
	    .EXAMPLE

		    Get-FTPConnection
		
	    .EXAMPLE

		    Get-FTPConnection -Session DefaultFTPS*

	    .NOTES
		    Author: Michal Gajda
		    Blog  : http://commandlinegeeks.com/

	    .LINK
            Set-FTPConnection
	    #>    

	    [OutputType('PSFTP.Session')]
	    [CmdletBinding(
    	    SupportsShouldProcess=$True,
            ConfirmImpact="Low"
        )]
        Param(
		    [String]$Session
	    )
	
	    Begin{}
	
	    Process
	    {
		    if($Session)
		    {
			    $Variables = Get-Variable -Scope Global | 
			    Where-Object {$_.value -is [System.Net.FtpWebRequest] -and $_.Name -like $Session}
		    }
		    else
		    {
			    $Variables = Get-Variable -Scope Global | Where-Object {$_.value -is [System.Net.FtpWebRequest]}
		    }
		
		    $Sessions = @()
		    $Variables | ForEach{
			    $CurrentSession = Get-Variable -Scope Global -Name $_.Name -ErrorAction SilentlyContinue -ValueOnly
		
			    if($Sessions -notcontains $CurrentSession)
			    {
				    $Sessions += $_.Value
			    }
		    }

		    $Sessions.PSTypeNames.Clear()
		    $Sessions.PSTypeNames.Add('PSFTP.Session')
		
		    Return $Sessions
	    }
	
	    End{}				
    }

    Function Get-FTPChildItem
    {
	    <#
	    .SYNOPSIS
		    Gets the item and child items from ftp location.

	    .DESCRIPTION
		    The Get-FTPChildItem cmdlet gets the items from ftp locations. If the item is a container, it gets the items inside the container, known as child items. 
		
	    .PARAMETER Path
		    Specifies a path to ftp location or file. 
			
	    .PARAMETER Session
		    Specifies a friendly name for the ftp session. Default session name is 'DefaultFTPSession'.
		
	    .PARAMETER Recurse
		    Get recurse child items.

	    .PARAMETER Depth
		    Define depth of  folder in recurse mode. Autoenable recurse mode.

	    .PARAMETER Filter
		    Specifies a filter parameter to return only this objects that have proper name. This parameter allow to use of wildcards. Defalut value is *.	
		
	    .EXAMPLE
		    PS P:\> Get-FTPChildItem -path ftp://ftp.contoso.com/folder


		       Parent: ftp://ftp.contoso.com/folder

		    Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		    --- -----     --  ----   -----  ----   ------------        ----
		    d   rwxr-xr-x 3   ftp    ftp           2012-06-19 12:58:00 subfolder1
		    d   rwxr-xr-x 2   ftp    ftp           2012-06-19 12:58:00 subfolder2
		    -   rw-r--r-- 1   ftp    ftp    1KB    2012-06-15 12:49:00 textitem.txt

	    .EXAMPLE
		    PS P:\> Get-FTPChildItem -path ftp://ftp.contoso.com/folder -Filter "subfolder*"


		       Parent: ftp://ftp.contoso.com/folder

		    Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		    --- -----     --  ----   -----  ----   ------------        ----
		    d   rwxr-xr-x 3   ftp    ftp           2012-06-19 12:58:00 subfolder1
		    d   rwxr-xr-x 2   ftp    ftp           2012-06-19 12:58:00 subfolder2	

	    .EXAMPLE
		    PS P:\> Get-FTPChildItem -path folder -Recurse


		       Parent: ftp://ftp.contoso.com/folder

		    Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		    --- -----     --  ----   -----  ----   ------------        ----
		    d   rwxr-xr-x 3   ftp    ftp           2012-06-19 12:58:00 subfolder1
		    d   rwxr-xr-x 2   ftp    ftp           2012-06-19 12:58:00 subfolder2
		    -   rw-r--r-- 1   ftp    ftp    1KB    2012-06-15 12:49:00 textitem.txt


		       Parent: ftp://ftp.contoso.com/folder/subfolder1

		    Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		    --- -----     --  ----   -----  ----   ------------        ----
		    d   rwxr-xr-x 2   ftp    ftp           2012-06-19 12:58:00 subfolder11
		    -   rw-r--r-- 1   ftp    ftp    21KB   2012-06-19 09:20:00 test.xlsx
		    -   rw-r--r-- 1   ftp    ftp    14KB   2012-06-19 11:27:00 ziped.zip


		       Parent: ftp://ftp.contoso.com/folder/subfolder1/subfolder11

		    Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		    --- -----     --  ----   -----  ----   ------------        ----
		    -   rw-r--r-- 1   ftp    ftp    14KB   2012-06-19 11:27:00 ziped.zip


		       Parent: ftp://ftp.contoso.com/folder/subfolder2

		    Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		    --- -----     --  ----   -----  ----   ------------        ----
		    -   rw-r--r-- 1   ftp    ftp    1KB    2012-06-15 12:49:00 textitem.txt
		    -   rw-r--r-- 1   ftp    ftp    14KB   2012-06-19 11:27:00 ziped.zip

	    .EXAMPLE
		    PS P:\> $ftpFile = Get-FTPChildItem -path /folder/subfolder1/test.xlsx
		    PS P:\> $ftpFile | Select-Object Parent, Name, ModifiedDate

		    Parent                                  Name                                    ModifiedDate
		    ------                                  ----                                    ------------
		    ftp://ftp.contoso.com/folder/subfolder1 test.xlsx                               2012-06-19 09:20:00
		
	    .NOTES
		    Author: Michal Gajda
		    Blog  : http://commandlinegeeks.com/

	    .LINK
		    Set-FTPConnection
	    #>	 

	    [OutputType('PSFTP.Item')]
	    [CmdletBinding(
		    SupportsShouldProcess=$True,
		    ConfirmImpact="Low"
	    )]
	    Param(
		    [parameter(ValueFromPipelineByPropertyName=$true,
			    ValueFromPipeline=$true)]
		    [String]$Path = "",
		    $Session = "DefaultFTPSession",
		    [parameter(ValueFromPipelineByPropertyName=$true)]
		    [Switch]$Recurse,	
		    [Int]$Depth = 0,		
		    [String]$Filter = "*"
	    )
	
	    Begin
	    {
		    if($Session -isnot [String])
		    {
			    $CurrentSession = $Session
		    }
		    else
		    {
			    $CurrentSession = Get-Variable -Scope Global -Name $Session -ErrorAction SilentlyContinue -ValueOnly
		    }
		
		    if($CurrentSession -eq $null)
		    {
			    Write-Warning "Add-FTPItem: Cannot find session $Session. First use Set-FTPConnection to config FTP connection."
			    Break
			    Return
		    }	
	    }
	
	    Process
	    {
		    Write-Debug "Native path: $Path"
		
		    if($Path -match "ftp://")
		    {
			    $RequestUri = $Path
			    Write-Verbose "Use original path: $RequestUri"
			
		    }
		    else
		    {
			    $RequestUri = $CurrentSession.RequestUri.OriginalString+"/"+$Path
			    Write-Verbose "Add ftp:// at start: $RequestUri"
		    }
		    $RequestUri = [regex]::Replace($RequestUri, '/$', '')
		    $RequestUri = [regex]::Replace($RequestUri, '/+', '/')
		    $RequestUri = [regex]::Replace($RequestUri, '^ftp:/', 'ftp://')
		    Write-Verbose "Remove additonal slash: $RequestUri"

		    if($Depth -gt 0)
		    {
			    $CurrentDepth = [regex]::matches($RequestUri,"/").count
			    if((Get-Variable -Scope Script -Name MaxDepth -ErrorAction SilentlyContinue) -eq $null)
			    {
				    New-Variable -Scope Script -Name MaxDepth -Value ([Int]$CurrentDepth +$Depth)
			    }
		
			    Write-Verbose "Auto enable recurse mode. Current depth / Max Depth: $CurrentDepth / $($Script:MaxDepth)"
			    $Recurse = $true
		    }

		
		    if ($pscmdlet.ShouldProcess($RequestUri,"Get child items from ftp location")) 
		    {	
			    if((Get-FTPItemSize $RequestUri -Session $Session -Silent) -eq -1)
			    {
				    Write-Verbose "Path is directory"
				    $ParentPath = $RequestUri
			    }
			    else
			    {
				    Write-Verbose "Path is file. Delete last file name to get parent path."
				    $LastIndex = $RequestUri.LastIndexOf("/")
				    $ParentPath = $RequestUri.SubString(0,$LastIndex)
			    }
						
			    [System.Net.FtpWebRequest]$Request = [System.Net.WebRequest]::Create($RequestUri)
			    $Request.Credentials = $CurrentSession.Credentials
			    $Request.EnableSsl = $CurrentSession.EnableSsl
			    $Request.KeepAlive = $CurrentSession.KeepAlive
			    $Request.UseBinary = $CurrentSession.UseBinary
			    $Request.UsePassive = $CurrentSession.UsePassive
			
			    $Request.Method = [System.Net.WebRequestMethods+FTP]::ListDirectoryDetails
			    Write-Verbose "Use WebRequestMethods: $($Request.Method)"
			    Try
			    {
				    $mode = "Unknown"
				    #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$CurrentSession.ignoreCert}  ##TTYE - This call will break future invoke-webrequest's that use https to a new site  --> https://blogs.technet.microsoft.com/bshukla/2010/04/12/ignoring-ssl-trust-in-powershell-system-net-webclient/
				    $Response = $Request.GetResponse()
				
				    [System.IO.StreamReader]$Stream = New-Object System.IO.StreamReader($Response.GetResponseStream(),[System.Text.Encoding]::Default)

				    $DirList = @()
				    $ItemsCollection = @()
				    Try
				    {
					    [string]$Line = $Stream.ReadLine()
					    Write-Debug "Read Line: $Line"
				    }
				    Catch
				    {
					    $Line = $null
					    Write-Debug "Line is null"
				    }
				
				    While ($Line)
				    {
					    if($mode -eq "Compatible" -or $mode -eq "Unknown")
					    {
						    $null, [string]$IsDirectory, [string]$Flag, [string]$Link, [string]$UserName, [string]$GroupName, [string]$Size, [string]$Date, [string]$Name = `
						    [regex]::split($Line,'^([d-])([rwxt-]{9})\s+(\d{1,})\s+([.@A-Za-z0-9-]+)\s+([A-Za-z0-9-]+)\s+(\d{1,})\s+(\w+\s+\d{1,2}\s+\d{1,2}:?\d{2})\s+(.+?)\s?$',"SingleLine,IgnoreCase,IgnorePatternWhitespace")

						    if($IsDirectory -eq "" -and $mode -eq "Unknown")
						    {
							    $mode = "IIS6"
						    }
						    elseif($mode -ne "Compatible")
						    {
							    $mode = "Compatible" #IIS7/Linux
						    }
						
						    if($mode -eq "Compatible")
						    {
							    $DatePart = $Date -split "\s+"
							    $NewDateString = "$($DatePart[0]) $('{0:D2}' -f [int]$DatePart[1]) $($DatePart[2])"
							
							    Try
							    {
								    if($DatePart[2] -match ":")
								    {
									    $Month = ([DateTime]::ParseExact($DatePart[0],"MMM",[System.Globalization.CultureInfo]::InvariantCulture)).Month
									    if((Get-Date).Month -ge $Month)
									    {
										    $NewDate = [DateTime]::ParseExact($NewDateString,"MMM dd HH:mm",[System.Globalization.CultureInfo]::InvariantCulture)
									    }
									    else
									    {
										    $NewDate = ([DateTime]::ParseExact($NewDateString,"MMM dd HH:mm",[System.Globalization.CultureInfo]::InvariantCulture)).AddYears(-1)
									    }
								    }
								    else
								    {
									    $NewDate = [DateTime]::ParseExact($NewDateString,"MMM dd yyyy",[System.Globalization.CultureInfo]::InvariantCulture)
								    }
							    }
							    Catch
							    {
								    Write-Verbose "Can't parse date: $Date"
							    }							
						    }
					    }
					
					    if($mode -eq "IIS6")
					    {
						    $null, [string]$NewDate, [string]$IsDirectory, [string]$Size, [string]$Name = `
						    [regex]::split($Line,'^(\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}[AP]M)\s+<*([DIR]*)>*\s+(\d*)\s+(.+).*$',"SingleLine,IgnoreCase")
						
						    if($IsDirectory -eq "")
						    {
							    $IsDirectory = "-"
						    }
					    }
					
					    Switch($Size)
					    {
						    {[int64]$_ -lt 1024} { $HFSize = $_+"B"; break }
						    {[System.Math]::Round([int64]$_/1KB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1KB,0))+"KB"; break }
						    {[System.Math]::Round([int64]$_/1MB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1MB,0))+"MB"; break }
						    {[System.Math]::Round([int64]$_/1GB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1GB,0))+"GB"; break }
						    {[System.Math]::Round([int64]$_/1TB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1TB,0))+"TB"; break }
						    {[System.Math]::Round([int64]$_/1PB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1PB,0))+"PB"; break }
					    } 
					
					    if($IsDirectory -eq "d" -or $IsDirectory -eq "DIR")
					    {
						    $HFSize = ""
					    }
					
					    if($ParentPath -match "\*|\?")
					    {
						    $LastIndex = $ParentPath.LastIndexOf("/")
						    $ParentPath = $ParentPath.SubString(0,$LastIndex)
						    $ParentPath.Trim() + "/" + $Name.Trim()
					    }
					
					    $LineObj = New-Object PSObject -Property @{
						    Dir = $IsDirectory
						    Right = $Flag
						    Ln = $Link
						    User = $UserName
						    Group = $GroupName
						    Size = $HFSize
						    SizeInByte = $Size
						    OrgModifiedDate = $Date
						    ModifiedDate = $NewDate
						    Name = $Name.Trim()
						    FullName = $ParentPath.Trim() + "/" + $Name.Trim()
						    Parent = $ParentPath.Trim()
					    }
					
					    $LineObj.PSTypeNames.Clear()
					    $LineObj.PSTypeNames.Add('PSFTP.Item')
			
					    if($Recurse -and ($LineObj.Dir -eq "d" -or $LineObj.Dir -eq "DIR"))
					    {
						    $DirList += $LineObj
					    }
					
					
					    if($LineObj.Dir)
					    {
						    if($LineObj.Name -like $Filter)
						    {
							    Write-Debug "Filter accepted: $Filter"
							    $ItemsCollection += $LineObj
						    }
					    }
					    $Line = $Stream.ReadLine()
					    Write-Debug "Read Line: $Line"
				    }
				
				    $Response.Close()
				
				    if($Recurse -and ($CurrentDepth -lt $Script:MaxDepth -or $Depth -eq 0))
				    {
					    $RecurseResult = @()
					    $DirList | ForEach-Object {
						    Write-Debug "Recurse is active and go to: $($_.FullName)"
						    $RecurseResult += Get-FTPChildItem -Path ($_.FullName) -Session $Session -Recurse -Filter $Filter -Depth $Depth
						
					    }	

					    $ItemsCollection += $RecurseResult
				    }	
				
				    if($ItemsCollection.count -eq 0)
				    {
					    Return 
				    }
				    else
				    {
					    Return $ItemsCollection | Sort-Object -Property @{Expression="Parent";Descending=$false}, @{Expression="Dir";Descending=$true}, @{Expression="Name";Descending=$false} 
				    }
			    }
			    Catch
			    {
				    Write-Error $_.Exception.Message -ErrorAction Stop 
			    }
		    }
		
		    if($CurrentDepth -ge $Script:MaxDepth)
		    {
			    Remove-Variable -Scope Script -Name CurrentDepth 
		    }		
	    }
	
	    End{}
    }

    Function Get-FTPItemSize
    {
        <#
	    .SYNOPSIS
	        Gets the item size.

	    .DESCRIPTION
	        The Get-FTPItemSize cmdlet gets the specific item size. 
		
	    .PARAMETER Path
	        Specifies a path to ftp location. 

	    .PARAMETER Silent
	        Hide warnings. 
		
	    .PARAMETER Session
	        Specifies a friendly name for the ftp session. Default session name is 'DefaultFTPSession'. 
	
	    .EXAMPLE
            PS> Get-FTPItemSize -Path "/myFolder/myFile.txt"
		    82033

	    .NOTES
		    Author: Michal Gajda
		    Blog  : http://commandlinegeeks.com/

	    .LINK
            Get-FTPChildItem
	    #>    

	    [CmdletBinding(
    	    SupportsShouldProcess=$True,
            ConfirmImpact="Low"
        )]
        Param(
		    [parameter(Mandatory=$true)]
		    [String]$Path = "",
		    [Switch]$Silent = $False,
		    $Session = "DefaultFTPSession"
	    )
	
	    Begin
	    {
		    if($Session -isnot [String])
		    {
			    $CurrentSession = $Session
		    }
		    else
		    {
			    $CurrentSession = Get-Variable -Scope Global -Name $Session -ErrorAction SilentlyContinue -ValueOnly
		    }
		
		    if($CurrentSession -eq $null)
		    {
			    Write-Warning "Add-FTPItem: Cannot find session $Session. First use Set-FTPConnection to config FTP connection."
			    Break
			    Return
		    }	
	    }
	
	    Process
	    {
		    Write-Debug "Native path: $Path"
		
		    if($Path -match "ftp://")
		    {
			    $RequestUri = $Path
			    Write-Debug "Use original path: $RequestUri"
			
		    }
		    else
		    {
			    $RequestUri = $CurrentSession.RequestUri.OriginalString+"/"+$Path
			    Write-Debug "Add ftp:// at start: $RequestUri"
		    }
		    $RequestUri = [regex]::Replace($RequestUri, '/$', '')
		    $RequestUri = [regex]::Replace($RequestUri, '/+', '/')
		    $RequestUri = [regex]::Replace($RequestUri, '^ftp:/', 'ftp://')
		    Write-Debug "Remove additonal slash: $RequestUri"
		
		    if ($pscmdlet.ShouldProcess($RequestUri,"Get item size")) 
		    {	
			    [System.Net.FtpWebRequest]$Request = [System.Net.WebRequest]::Create($RequestUri)
			    $Request.Credentials = $CurrentSession.Credentials
			    $Request.EnableSsl = $CurrentSession.EnableSsl
			    $Request.KeepAlive = $CurrentSession.KeepAlive
			    $Request.UseBinary = $CurrentSession.UseBinary
			    $Request.UsePassive = $CurrentSession.UsePassive
			
			    $Request.Method = [System.Net.WebRequestMethods+FTP]::GetFileSize 
			    Try
			    {
				    #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$CurrentSession.ignoreCert} ##TTYE - This call will break future invoke-webrequest's that use https to a new site --> https://blogs.technet.microsoft.com/bshukla/2010/04/12/ignoring-ssl-trust-in-powershell-system-net-webclient/
				    $Response = $Request.GetResponse()

				    $Status = $Response.ContentLength
				    $Response.Close()
				    Return $Status
			    }
			    Catch
			    {
				    if(!$Silent)
				    {
					    Write-Error $_.Exception.Message -ErrorAction Stop  
				    }	
				    Return -1
			    }
		    }
	    }
	
	    End{}				
    }

    
    Function RemoveOldDefs {
        Write-BISFLog -Msg "Removing superceded virus definitions" -ShowConsole -Color DarkCyan -SubMsg
        $allDefs = (dir $env:ProgramData"\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Definitions\VirusDefs" | where-object {$_.name -like "*20*"}).Name #may have to update the date string in 2100's
        #if there is only one set of virus definitions folder we are done (you can't remove it) -- measure.count enables count on 2003 with PowerShell 2
        if (($allDefs | measure).Count -eq 1) { 
            continue 
        } else {
            [System.Collections.ArrayList]$ArrayList = $allDefs
            $ArrayList.Remove("$virusDefsFTPName")
            Write-BISFLog -Msg "Removing old definitions"  -ShowConsole -Color DarkCyan -SubMsg
            Write-BISFLog -Msg "$($ArrayList | out-string)" -ShowConsole -Color DarkCyan -SubMsg
            foreach ($def in $ArrayList) {
                rmdir $env:ProgramData"\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Definitions\VirusDefs\$def" -Recurse -ErrorAction SilentlyContinue
            }
        }
    }

    Function Execute-Command ($commandTitle, $commandPath, $commandArguments)  #from here: https://stackoverflow.com/questions/8761888/capturing-standard-out-and-error-with-start-process
    {
      Try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $commandPath
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = $commandArguments
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        [pscustomobject]@{
            commandTitle = $commandTitle
            stdout = $p.StandardOutput.ReadToEnd()
            stderr = $p.StandardError.ReadToEnd()
            ExitCode = $p.ExitCode  
        }
        $p.WaitForExit()
      }
      Catch {
         exit
      }
    }
####################################################################
####### end functions #####
####################################################################

#### Main Program
    Write-BISFLog -Msg "===========================$script_name===========================" -ShowConsole -Color DarkCyan -SubMsg

    If (Test-Path ("$SEP_path\smc.exe") -PathType Leaf) {
        Write-BISFLog -Msg "Updating virus definitions for $Product" -ShowConsole -Color Cyan

        $SepLiveUpdateResult = Execute-Command -commandTitle "SepLiveUpdate" -commandPath "$SEP_path\SepLiveUpdate.exe"
        
        #if SepLiveUpdate is disabled we'll download new definitions from FTP
        if ($SepLiveUpdateResult.stderr -like "LiveUpdate has been disabled.*") {

            Write-BISFLog -Msg "Updating virus definitions for $Product from FTP" -ShowConsole -Color Cyan

            #Enable VPDebug.log
            #New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Symantec\Symantec Endpoint Protection\AV\ProductControl" -PropertyType String -Name Debug -Value ALL -Force | Out-Null

            # create anonymous credentials
            $cred = new-object System.Net.NetworkCredential('anonymous','','')

            # Set-FTPConnection returns a credential error...  ignore it.  It actually works.
            Write-BISFLog -Msg "Connecting to Symantec FTP site" -ShowConsole -Color DarkCyan -SubMsg
            Set-FTPConnection -Server ftp://ftp.symantec.com/public/english_us_canada/antivirus_definitions/norton_antivirus/ -Credentials $cred -Session VirusDefDownload -UsePassive -ErrorAction silentlycontinue | out-null

            Write-BISFLog -Msg "Getting list of items on the FTP site" -ShowConsole -Color DarkCyan -SubMsg
            $Session = Get-FTPConnection -Session VirusDefDownload
        
            $listOfFTPItems = Get-FTPChildItem -Session $Session
        
            # Symantec Endpoint Protection Client Installations on Windows Platforms (64-bit)
            # Use the v5i64 executable file for 64-bit client installations and v5i32 for 32-bit installations.

            If ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
              $listOfFTPItems = $listOfFTPItems | Where-Object {$_.name -like "*-v5i64*"}
            } else {
              $listOfFTPItems = $listOfFTPItems | Where-Object {$_.name -like "*-v5i32*"}
            }

            #we are relying on Symantec keeping the name arranged by properdate on the file.  If they change their name scheme
            # YYYYMMDD-### then this sort method may not work.
            $virusDefs = $listOfFTPItems | sort-object Name | select -Last 1
        
            #compare current virusDefs to the definitions actually installed.  Take the FTP name format, remove -v5i##.exe, swap
            #hypens "-" for "." then do a compare against the virusDefs in this folder:
            #C:\ProgramData\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Definitions\VirusDefs
            If ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
              $virusDefsFTPName = $virusDefs.Name.Replace('-v5i64.exe','')
            } else {
              $virusDefsFTPName = $virusDefs.Name.Replace('-v5i32.exe','')
            }

            $virusDefsFTPName = $virusDefsFTPName.Replace('-','.')
            Write-BISFLog -Msg "FTP Virus Definition Name: $( $virusDefs.FullName)"  -ShowConsole -Color DarkCyan -SubMsg
       

            #compare folder name with virusDefs on FTP site.
            If (test-path $env:ProgramData"\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Definitions\VirusDefs\$virusDefsFTPName") {
                Write-BISFLog -Msg "Local Virus definitions match latest FTP definitions.  No update necessary."  -ShowConsole -Color DarkCyan -SubMsg
                $updateVirusDefs = $false
                RemoveOldDefs
              }

            #Remove any previous download if one exists
            if (test-path ($env:TEMP + "\" + $virusDefs.Name)) {
                remove-item ($env:TEMP + "\" + $virusDefs.Name) -Force -ErrorAction SilentlyContinue
            }


            if ($updateVirusDefs -eq $true) {
                Write-BISFLog -Msg "Local virus definitions do not match definitions on Symantec FTP.  Updating..."  -ShowConsole -Color DarkCyan -SubMsg
                Write-BISFLog -Msg "Downloading and installing newest definitions: $($virusDefs.Name)"  -ShowConsole -Color DarkCyan -SubMsg
                Write-BISFLog -Msg "Starting Download" -ShowConsole -Color DarkCyan -SubMsg

                #we use native C# ftp calls as it's way faster than invoke-request and not prone to SSL breakage with the FTP Powershell modules
                $RemoteFile 	=  $virusDefs.FullName
                $LocalFile	= $env:TEMP + "\" + $virusDefs.Name


                Start-Job -Name "FTPDownload" -scriptBlock {
                    $cred = $args[0]
                    $RemoteFile = $args[1]
                    $LocalFile	= $args[2]

                    # Create a FTPWebRequest 
                    $FTPRequest = [System.Net.FtpWebRequest]::Create($RemoteFile) 
                    $FTPRequest.Credentials = $cred
                    $FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile 
                    $FTPRequest.UseBinary = $true 
                    $FTPRequest.KeepAlive = $false
                    # Send the ftp request
                    # Create the target file on the local system and the download buffer 
            
                    $LocalFileFile = New-Object IO.FileStream ($LocalFile,[IO.FileMode]::Create) 

                    $FTPRequest.GetResponse().GetResponseStream().CopyTo($LocalFileFile)
                    #Release the file from the stream
                    $LocalFileFile.Close()

                    #cleanup our request
                    $FTPRequest.GetResponse().Close()
                    $FTPRequest.GetResponse().Dispose()
                } -ArgumentList $cred,$RemoteFile,$LocalFile | out-null
                sleep 4
                do {
                    sleep 1
                    $pctComplete = [math]::floor(((ls $LocalFile).Length / ($virusDefs.SizeInByte))*100)
                    Write-Progress -Activity "Downloading newest definitions" -status "$pctComplete% Complete:" -PercentComplete $pctComplete
                
                } 
                until ((get-job -Name "FTPDownload").state -eq "Completed") 
                Write-Progress -Activity "Downloading newest definitions" -Completed
                Remove-Job  -Name "FTPDownload"
            
                Write-BISFLog -Msg "Finished Download" -ShowConsole -Color DarkCyan -SubMsg
                Write-BISFLog -Msg "Installing new definitions" -ShowConsole -Color DarkCyan -SubMsg

                #install Defs
                $downloadedDefs = $env:TEMP + "\" + $virusDefs.Name
                $VirusDefInstall = Start-Process $downloadedDefs -ArgumentList /q -PassThru
                Show-BISFProgressBar -CheckProcess $VirusDefInstall -ActivityText "Updating definitions..." -MaximumExecutionMinutes 3 -TerminateRunawayProcess

                Write-BISFLog -Msg "Installation Completed" -ShowConsole -Color DarkCyan -SubMsg
                sleep 2

                #remove old definitions
                RemoveOldDefs

                #Remove download if one exists
                if (test-path ($env:TEMP + "\" + $virusDefs.Name)) {
                    remove-item ($env:TEMP + "\" + $virusDefs.Name) -Force  -ErrorAction SilentlyContinue
                }
            }
        }
    }
    else {
        Write-BISFLog -Msg "SepLiveUpdate returned: $($SepLiveUpdateResult.stderr)" -ShowConsole -Color Cyan
    }
}


End {
	Add-BISFFinishLine
}
