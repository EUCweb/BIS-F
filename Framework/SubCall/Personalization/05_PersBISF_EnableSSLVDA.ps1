<#
    .Synopsis
      Configures Citrix VDA for SSL communication
    .Description
      Configures Citrix VDA for SSL communication during computerstartup
      Tested on 2019
    .NOTES
      Author: Trentent Tye

      History
		  2019.07.05 TT: Script created
		  16.08.2019 MS: ENH 107 - integrated into BIS-F
	  .Link
		  https://github.com/EUCweb/BIS-F/issues/107

		  .Link
		  https://eucweb.com
    #>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	if ($LIC_BISF_CLI_VDASSL -eq "YES") { $EnableMode = $true }
	if ($LIC_BISF_CLI_VDASSL -eq "NO") { $DisableMode = $true }
	[int]$SSLPort = $LIC_BISF_CLI_VDASSL_SSLPORT
	$SSLMinVersion = $LIC_BISF_CLI_VDASSL_MinVer
	$SSLCipherSuite = $LIC_BISF_CLI_VDASSL_CipherSuite
	if ($CertificateThumbPrint -ne "") { $CertificateThumbPrint = $LIC_BISF_CLI_VDASSL_CertThumbprint }
}

Process {
	Write-BISFLog -Msg "===========================$script_name===========================" -ShowConsole -Color DarkCyan -SubMsg
	if (-not($EnableMode) -or ($DisableMode)) {
		Write-BISFLog -Msg "VDA SSL Options not configured."  -ShowConsole -Color Yellow
		Return
	}

	# Registry path constants
	$ICA_LISTENER_PATH = 'HKLM:\system\CurrentControlSet\Control\Terminal Server\Wds\icawd'
	$ICA_CIPHER_SUITE = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman'
	$DHEnabled = 'Enabled'
	$BACK_DHEnabled = 'Back_Enabled'
	$ENABLE_SSL_KEY = 'SSLEnabled'
	$SSL_CERT_HASH_KEY = 'SSLThumbprint'
	$SSL_PORT_KEY = 'SSLPort'
	$SSL_MINVERSION_KEY = 'SSLMinVersion'
	$SSL_CIPHERSUITE_KEY = 'SSLCipherSuite'

	$POLICIES_PATH = 'HKLM:\SOFTWARE\Policies\Citrix\ICAPolicies'
	$ICA_LISTENER_PORT_KEY = 'IcaListenerPortNumber'
	$SESSION_RELIABILITY_PORT_KEY = 'SessionReliabilityPort'
	$WEBSOCKET_PORT_KEY = 'WebSocketPort'

	#Read ICA, CGP and HTML5 ports from the registry
	try {
		$IcaPort = (Get-ItemProperty -Path $POLICIES_PATH -Name $ICA_LISTENER_PORT_KEY -ErrorAction SilentlyContinue).IcaListenerPortNumber
	}
	catch {
		$IcaPort = 1494
	}

	try {
		$CgpPort = (Get-ItemProperty -Path $POLICIES_PATH -Name $SESSION_RELIABILITY_PORT_KEY -ErrorAction SilentlyContinue).SessionReliabilityPort
	}
	catch {
		$CgpPort = 2598
	}

	try {
		$Html5Port = (Get-ItemProperty -Path $POLICIES_PATH -Name $WEBSOCKET_PORT_KEY -ErrorAction SilentlyContinue).WebSocketPort
	}
	catch {
		$Html5Port = 8008
	}

	if (!$IcaPort) {
		$IcaPort = 1494
	}
	if (!$CgpPort) {
		$CgpPort = 2598
	}
	if (!$Html5Port) {
		$Html5Port = 8008
	}

	# Determine the name of the ICA Session Manager
	if (Get-Service | Where-Object { $_.Name -eq 'porticaservice' }) {
		$username = 'NT SERVICE\PorticaService'
		$serviceName = 'PortIcaService'
	}
	else {
		$username = 'NT SERVICE\TermService'
		$serviceName = 'TermService'
	}

	Write-BISFLog -Msg "Discovered the following:" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "ICA Port     : $IcaPort" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "CGP Port     : $CgpPort" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "HTML5 Port   : $Html5Port" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "Username     : $username" -ShowConsole -Color DarkCyan -SubMsg
	Write-BISFLog -Msg "ServiceName  : $serviceName" -ShowConsole -Color DarkCyan -SubMsg

	if ($DisableMode) {
		#Disable Mode.  GPO was set to Disabled.
		#Replace Diffie-Hellman Enabled value to its original value
		Write-BISFLog -Msg "Disable SSL for the Citrix VDA." -ShowConsole -Color Yellow
		if (Test-Path $ICA_CIPHER_SUITE) {
			$back_enabled_exists = Get-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -ErrorAction SilentlyContinue
			if ($back_enabled_exists -ne $null) {
				Set-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -Value $back_enabled_exists.Back_Enabled
				Remove-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled
			}
		}

		Write-BISFLog -Msg "Resetting Firewall rules." -ShowConsole -Color DarkCyan -SubMsg
		#Enable any existing rules for ICA, CGP and HTML5 ports
		netsh advfirewall firewall add rule name="Citrix ICA Service"        dir=in action=allow service=$serviceName profile=any protocol=tcp localport=$IcaPort | Out-Null
		netsh advfirewall firewall add rule name="Citrix CGP Server Service" dir=in action=allow service=$serviceName profile=any protocol=tcp localport=$CgpPort | Out-Null
		netsh advfirewall firewall add rule name="Citrix Websocket Service"  dir=in action=allow service=$serviceName profile=any protocol=tcp localport=$Html5Port | Out-Null

		#Enable existing rules for UDP-ICA, UDP-CGP
		netsh advfirewall firewall add rule name="Citrix ICA UDP" dir=in action=allow service=$serviceName profile=any protocol=udp localport=$IcaPort | Out-Null
		netsh advfirewall firewall add rule name="Citrix CGP UDP" dir=in action=allow service=$serviceName profile=any protocol=udp localport=$CgpPort | Out-Null

		#Delete any existing rules for Citrix SSL Service
		netsh advfirewall firewall delete rule name="Citrix SSL Service" | Out-Null

		#Delete any existing rules for Citrix DTLS Service
		netsh advfirewall firewall delete rule name="Citrix DTLS Service" | Out-Null

		#Turning off SSL by setting SSLEnabled key to 0
		Write-BISFLog -Msg "Disabling ICA SSL." -ShowConsole -Color DarkCyan -SubMsg
		Set-ItemProperty -Path $ICA_LISTENER_PATH -name $ENABLE_SSL_KEY -Value 0 -Type DWord -Confirm:$false

		Write-BISFLog -Msg "SSL to VDA has been disabled." -ShowConsole -Color DarkCyan -SubMsg
	}

	if ($EnableMode) {
		#Enable Mode.  GPO was set to Enabled.
		Write-BISFLog -Msg "Enable SSL for the Citrix VDA." -ShowConsole -Color Yellow
		$RegistryKeysSet = $ACLsSet = $FirewallConfigured = $False

		#Certificates MUST be in the Local Machine > Personal store.
		$Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
		$Store.Open("ReadOnly")

		if ($Store.Certificates.Count -eq 0) {
			Write-BISFLog -Msg "No certificates found in the Personal Local Machine Certificate Store. Please install a certificate and try again." -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			$Store.Close()
			break
		}
		elseif ($Store.Certificates.Count -ge 1) {
			if ($CertificateThumbPrint) {
				$Certificate = $Store.Certificates | where { $_.GetCertHashString() -eq $CertificateThumbPrint }
				if (!$Certificate) {
					Write-BISFLog -Msg "No certificate found in the certificate store with thumbprint $CertificateThumbPrint"  -ShowConsole -Color DarkCyan -SubMsg
					Write-BISFLog -Msg "Enabling SSL to VDA failed."  -ShowConsole -Color DarkCyan -SubMsg
					$Store.Close()
					break
				}
			}
			foreach ($certificate in $Store.Certificates) {
				if ($certificate.DnsNameList.unicode -like "$($env:COMPUTERNAME)*") {
					$CertificateThumbPrint = $Certificate.GetCertHashString()
					$cert = $certificate
				}
			}
			if (-not($CertificateThumbPrint)) {
				$ComputerName = "CN=" + [System.Net.Dns]::GetHostByName((hostname)).HostName + ","
				$Certificate = $Store.Certificates | where { $_.Subject -match $ComputerName }
				$CertificateThumbPrint = $Certificate.GetCertHashString()
			}

		}
		elseif (-not($CertificateThumbPrint)) {
			Write-BISFLog -Msg "No certificate found in the certificate store with thumbprint $CertificateThumbPrint" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			$Store.Close()
			break
		}

		Write-BISFLog -Msg "Certificate:" -ShowConsole -Color Cyan
		foreach ($line in $($cert.DnsNameList)) { if ($line) { Write-BISFLog -Msg "DNSNameList  : $line" -ShowConsole -Color Yellow -SubMsg } }
		foreach ($line in $($cert | fl | Out-String -Stream)) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color Yellow -SubMsg } }

		#Validate the certificate

		#Validate expiration date
		$ValidTo = [DateTime]::Parse($cert.GetExpirationDateString())
		if($ValidTo -lt [DateTime]::UtcNow) {
			Write-BISFLog -Msg "The certificate is expired. Please install a valid certificate and try again." -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			$Store.Close()
			break
		}

		#Check certificate trust
		if(!$cert.Verify()) {
			Write-BISFLog -Msg "Verification of the certificate failed. Please install a valid certificate and try again." -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			$Store.Close()
			break
		}

		#Check private key availability
		try {
			[System.Security.Cryptography.AsymmetricAlgorithm] $PrivateKey = $cert.PrivateKey
			$UniqueContainer = ((($cert).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
		}
		catch {
			Write-BISFLog -Msg "Unable to access the Private Key of the Certificate or one of its fields." -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			$Store.Close()
			break
		}

		if(!$PrivateKey -or !$UniqueContainer) {
			Write-BISFLog -Msg "Unable to access the Private Key of the Certificate or one of its fields." -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Enabling SSL to VDA failed." -ShowConsole -Color DarkCyan -SubMsg
			$Store.Close()
			break
		}

		Write-BISFLog -Msg "Setting ACL's on private key file" -ShowConsole -Color Cyan
		$private_key = ((($cert).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
		$dir = $env:ProgramData + '\Microsoft\Crypto\RSA\MachineKeys\'
		$keypath = $dir + $private_key
		icacls $keypath /grant `"$username`"`:RX | Out-Null
		$acls = icacls $keypath
		foreach ($line in $acls) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color DarkCyan -SubMsg } }


		Write-BISFLog -Msg "ACLs set." -ShowConsole -Color DarkCyan -SubMsg
		$ACLsSet = $True

		#Delete any existing rules for the SSLPort
		netsh advfirewall firewall delete rule name=all protocol=tcp localport=$SSLPort | Out-Null

		#Delete any existing rules for the DTLSPort
		netsh advfirewall firewall delete rule name=all protocol=udp localport=$SSLPort | Out-Null

		#Delete any existing rules for Citrix SSL Service
		netsh advfirewall firewall delete rule name="Citrix SSL Service" | Out-Null

		#Delete any existing rules for Citrix DTLS Service
		netsh advfirewall firewall delete rule name="Citrix DTLS Service" | Out-Null

		#Creating firewall rule for Citrix SSL Service
		netsh advfirewall firewall add rule name="Citrix SSL Service"  dir=in action=allow service=$serviceName profile=any protocol=tcp localport=$SSLPort | Out-Null

		#Creating firewall rule for Citrix DTLS Service
		netsh advfirewall firewall add rule name="Citrix DTLS Service" dir=in action=allow service=$serviceName profile=any protocol=udp localport=$SSLPort | Out-Null

		#Disable any existing rules for ICA, CGP and HTML5 ports
		netsh advfirewall firewall set rule name="Citrix ICA Service"        protocol=tcp localport=$IcaPort new enable=no | Out-Null
		netsh advfirewall firewall set rule name="Citrix CGP Server Service" protocol=tcp localport=$CgpPort new enable=no | Out-Null
		netsh advfirewall firewall set rule name="Citrix Websocket Service"  protocol=tcp localport=$Html5Port new enable=no | Out-Null

		#Disable existing rules for UDP-ICA, UDP-CGP
		netsh advfirewall firewall set rule name="Citrix ICA UDP" protocol=udp localport=$IcaPort new enable=no | Out-Null
		netsh advfirewall firewall set rule name="Citrix CGP UDP" protocol=udp localport=$CgpPort new enable=no | Out-Null

		Write-BISFLog -Msg "Firewall rules:"  -ShowConsole -Color Cyan
		$CitrixSSLService = . netsh advfirewall firewall show rule "Citrix SSL Service"
		foreach ($line in $CitrixSSLService) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color DarkCyan -SubMsg } }

		$CitrixDTLSService = . netsh advfirewall firewall show rule "Citrix DTLS Service"
		foreach ($line in $CitrixDTLSService) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color DarkCyan -SubMsg } }

		$CitrixICAService = . netsh advfirewall firewall show rule "Citrix ICA Service"
		foreach ($line in $CitrixICAService) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color DarkCyan -SubMsg } }

		$CitrixCGPServerService = . netsh advfirewall firewall show rule "Citrix CGP Server Service"
		foreach ($line in $CitrixCGPServerService) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color DarkCyan -SubMsg } }

		$CitrixWebsocketService = . netsh advfirewall firewall show rule "Citrix Websocket Service"
		foreach ($line in $CitrixWebsocketService) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color DarkCyan -SubMsg } }

		$CitrixICAUDP = . netsh advfirewall firewall show rule "Citrix ICA UDP"
		foreach ($line in $CitrixICAUDP) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color DarkCyan -SubMsg } }

		$CitrixCGPUDP = . netsh advfirewall firewall show rule "Citrix CGP UDP"
		foreach ($line in $CitrixCGPUDP) { if ($line) { Write-BISFLog -Msg "$line" -ShowConsole -Color DarkCyan -SubMsg } }

		Write-BISFLog -Msg "Firewall configured." -ShowConsole -Color DarkCyan -SubMsg
		$FirewallConfigured = $True

		# Create registry keys to enable SSL to the VDA
		Write-BISFLog -Msg "Setting registry keys..."  -ShowConsole -Color Cyan
		Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_CERT_HASH_KEY -Value $cert.GetCertHash() -Type Binary -Confirm:$False
		switch($SSLMinVersion) {
			"SSL_3.0" {
				Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_MINVERSION_KEY -Value 1 -Type DWord -Confirm:$False
			}
			"TLS_1.0" {
				Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_MINVERSION_KEY -Value 2 -Type DWord -Confirm:$False
			}
			"TLS_1.1" {
				Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_MINVERSION_KEY -Value 3 -Type DWord -Confirm:$False
			}
			"TLS_1.2" {
				Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_MINVERSION_KEY -Value 4 -Type DWord -Confirm:$False
			}
		}

		switch($SSLCipherSuite) {
			"GOV" {
				Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_CIPHERSUITE_KEY -Value 1 -Type DWord -Confirm:$False
			}
			"COM" {
				Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_CIPHERSUITE_KEY -Value 2 -Type DWord -Confirm:$False
			}
			"ALL" {
				Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_CIPHERSUITE_KEY -Value 3 -Type DWord -Confirm:$False
			}
		}

		Set-ItemProperty -Path $ICA_LISTENER_PATH -name $SSL_PORT_KEY -Value $SSLPort -Type DWord -Confirm:$False

		#Backup DH Cipher Suite and set Enabled:0 if SSL is enabled
		if (!(Test-Path $ICA_CIPHER_SUITE)) {
			New-Item -Path $ICA_CIPHER_SUITE -Force | Out-Null
			New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -Value 0 -PropertyType DWORD -Force | Out-Null
			New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -Value 1 -PropertyType DWORD -Force | Out-Null
		}
		else {
			$back_enabled_exists = Get-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -ErrorAction SilentlyContinue
			if ($back_enabled_exists -eq $null) {
				$exists = Get-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -ErrorAction SilentlyContinue
				if ($exists -ne $null) {
					New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -Value $exists.Enabled -PropertyType DWORD -Force | Out-Null
					Set-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -Value 0
				}
				else {
					New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $DHEnabled -Value 0 -PropertyType DWORD -Force | Out-Null
					New-ItemProperty -Path $ICA_CIPHER_SUITE -Name $BACK_DHEnabled -Value 1 -PropertyType DWORD -Force | Out-Null
				}
			}
		}

		# NOTE: This must be the last thing done when enabling SSL as the Citrix Service
		#       will use this as a signal to try and start the Citrix SSL Listener!!!!
		Set-ItemProperty -Path $ICA_LISTENER_PATH -name $ENABLE_SSL_KEY -Value 1 -Type DWord -Confirm:$False

		Write-BISFLog -Msg "Registry Key Values:" -ShowConsole -Color Cyan
		Write-BISFLog -Msg "$ICA_LISTENER_PATH\$ENABLE_SSL_KEY : $($(Get-ItemProperty -Path $ICA_LISTENER_PATH).$ENABLE_SSL_KEY)" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "$ICA_LISTENER_PATH\$SSL_CERT_HASH_KEY : $($(Get-ItemProperty -Path $ICA_LISTENER_PATH).$SSL_CERT_HASH_KEY)" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "$ICA_LISTENER_PATH\$SSL_MINVERSION_KEY : $($(Get-ItemProperty -Path $ICA_LISTENER_PATH).$SSL_MINVERSION_KEY)" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "$ICA_LISTENER_PATH\$SSL_CIPHERSUITE_KEY : $($(Get-ItemProperty -Path $ICA_LISTENER_PATH).$SSL_CIPHERSUITE_KEY)" -ShowConsole -Color DarkCyan -SubMsg
		Write-BISFLog -Msg "$ICA_LISTENER_PATH\$SSL_PORT_KEY : $($(Get-ItemProperty -Path $ICA_LISTENER_PATH).$SSL_PORT_KEY)" -ShowConsole -Color DarkCyan -SubMsg

		Write-BISFLog -Msg "Registry keys set." -ShowConsole -Color DarkCyan -SubMsg
		$RegistryKeysSet = $True

		$Store.Close()

		if ($RegistryKeysSet -and $ACLsSet -and $FirewallConfigured) {
			Write-BISFLog -Msg "SSL to VDA enabled." -ShowConsole -Color DarkCyan -SubMsg
		}
		else {
			if (!$RegistryKeysSet) {
				Write-BISFLog -Msg "Configure registry manually or re-run the script to complete enabling SSL to VDA." -ShowConsole -Color DarkCyan -SubMsg
			}

			if (!$ACLsSet) {
				Write-BISFLog -Msg "Configure ACLs manually or re-run the script to complete enabling SSL to VDA." -ShowConsole -Color DarkCyan -SubMsg
			}

			if (!$FirewallConfigured) {
				Write-BISFLog -Msg "Configure firewall manually or re-run the script to complete enabling SSL to VDA." -ShowConsole -Color DarkCyan -SubMsg
			}
		}
	}
}


End {
	Add-BISFFinishLine
}
