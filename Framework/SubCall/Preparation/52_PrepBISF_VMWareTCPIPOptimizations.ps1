<#
    .Synopsis
      Sets VMWare Optimizations per VMWare documents.
    .Description
      Sets VMWare Optimizations per VMWare and Microsoft documents.
      Tested with Server 2012R2, 2008R2
      Refrences:
        VMWare 2055140 - Understanding TCP Segmentation Offload (TSO) and Large Receive Offload (LRO) in a VMware environment (2055140) - https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2055140
                                                                Enable or Disable LRO on a VMXNET3 Adapter on a Windows Virtual Machine - https://docs.vmware.com/en/VMware-vSphere/6.0/com.vmware.vsphere.networking.doc/GUID-ECC80415-442C-44E9-BA7A-852DDB174B9F.html
                         On Windows, the LRO technology is also referred to as Receive Side Coalescing (RSC)
        VMWare 2008925 - Poor network performance or high network latency on Windows virtual machines - https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2008925
                              VMware Tools and RSS Incompatibility Issues (Guidance is to enable RSS) - https://blogs.vmware.com/apps/2017/03/rush-post-vmware-tools-rss-incompatibility-issues.html
                                                                 Setting the Number of RSS Processors - https://docs.microsoft.com/en-us/windows-hardware/drivers/network/setting-the-number-of-rss-processors
                                                            Receive Side Scaling for the File Servers - https://blogs.technet.microsoft.com/networking/2015/07/24/receive-side-scaling-for-the-file-servers/
                   Drive up networking performance for your most demanding workloads with Virtual RSS - https://blogs.technet.microsoft.com/networking/2013/07/31/drive-up-networking-performance-for-your-most-demanding-workloads-with-virtual-rss/
                                                                Setting the number of Receiver Queues - https://technet.microsoft.com/en-us/library/jj574168(v=ws.11).aspx
                                                   Set TCPAckFrequency to resolve VMWare NIC slowness - https://communities.vmware.com/thread/491697?start=30&tstart=0
                                  Disable Nagle's Algorithm  for improved realtime/Citrix performance - https://blogs.technet.microsoft.com/nettracer/2013/01/05/tcp-delayed-ack-combined-with-nagle-algorithm-can-badly-impact-communication-performance/
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Trentent Tye

      History
      2017.06.27 TT: Script created
	  2017.08.05 TT: Tested with 2008 R2
	  2017.08.29 TT: Updated with NUMA detection
	  19.08.2019 MS: ENH 8: VMWare RSS and TCPIP Optimizations integrated into BIS-F
	  11.10.2019 MS: Running Optimizations on VMWare Hypervisor only
	  02.01.2020 MS: HF 168 - VMware Optimizations 52_PrepBISF_VMWareTCPIPOptimization not executed

	  .Link
    #>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$setRSS = $true
	$OS = (gwmi win32_operatingsystem).caption

	#count logical CPU's
	$CPUCount = 0
	foreach ($logicalProc in ( (Get-WmiObject Win32_processor -Property NumberOfLogicalProcessors).NumberOfLogicalProcessors)) {
		$CPUCount = $CPUCount + $logicalProc
	}

	#less than 2 CPU present?
	if ($CPUCount -le 2) {
		$setRSS = $false
	}

	#count number of NIC's
	$NICCount = 0
	foreach ($netAdapter in (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE)) {
		$NICCount++
	}

	#NIC == #CPU(-1)
	if ($NICCount -ge ($CPUCount - 1)) {
		$setRSS = $false
	}

	#find out if we are a NUMA VM
	$NumaCSharp = @"
using System;
using System.Diagnostics;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Windows
{
    public class Kernel32
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct PROCESSORCORE
        {
            public byte Flags;
        };

        [StructLayout(LayoutKind.Sequential)]
        public struct NUMANODE
        {
            public uint NodeNumber;
        }

        public enum PROCESSOR_CACHE_TYPE
        {
            CacheUnified,
            CacheInstruction,
            CacheData,
            CacheTrace
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct CACHE_DESCRIPTOR
        {
            public byte Level;
            public byte Associativity;
            public ushort LineSize;
            public uint Size;
            public PROCESSOR_CACHE_TYPE Type;
        }

        [StructLayout(LayoutKind.Explicit)]
        public struct SYSTEM_LOGICAL_PROCESSOR_INFORMATION_UNION
        {
            [FieldOffset(0)]
            public PROCESSORCORE ProcessorCore;
            [FieldOffset(0)]
            public NUMANODE NumaNode;
            [FieldOffset(0)]
            public CACHE_DESCRIPTOR Cache;
            [FieldOffset(0)]
            private UInt64 Reserved1;
            [FieldOffset(8)]
            private UInt64 Reserved2;
        }

        public enum LOGICAL_PROCESSOR_RELATIONSHIP
        {
            RelationProcessorCore,
            RelationNumaNode,
            RelationCache,
            RelationProcessorPackage,
            RelationGroup,
            RelationAll = 0xffff
        }

        public struct SYSTEM_LOGICAL_PROCESSOR_INFORMATION
        {
            public UIntPtr ProcessorMask;
            public LOGICAL_PROCESSOR_RELATIONSHIP Relationship;
            public SYSTEM_LOGICAL_PROCESSOR_INFORMATION_UNION ProcessorInformation;
        }

        [DllImport(@"kernel32.dll", SetLastError=true)]
        public static extern bool GetLogicalProcessorInformation(
            IntPtr Buffer,
            ref uint ReturnLength
        );

        private const int ERROR_INSUFFICIENT_BUFFER = 122;

        public static SYSTEM_LOGICAL_PROCESSOR_INFORMATION[] MyGetLogicalProcessorInformation()
        {
            uint ReturnLength = 0;
            GetLogicalProcessorInformation(IntPtr.Zero, ref ReturnLength);
            if (Marshal.GetLastWin32Error() == ERROR_INSUFFICIENT_BUFFER)
            {
                IntPtr Ptr = Marshal.AllocHGlobal((int)ReturnLength);
                try
                {
                    if (GetLogicalProcessorInformation(Ptr, ref ReturnLength))
                    {
                        int size = Marshal.SizeOf(typeof(SYSTEM_LOGICAL_PROCESSOR_INFORMATION));
                        int len = (int)ReturnLength / size;
                        SYSTEM_LOGICAL_PROCESSOR_INFORMATION[] Buffer = new SYSTEM_LOGICAL_PROCESSOR_INFORMATION[len];
                        IntPtr Item = Ptr;
                        for (int i = 0; i < len; i++)
                        {
                            Buffer[i] = (SYSTEM_LOGICAL_PROCESSOR_INFORMATION)Marshal.PtrToStructure(Item, typeof(SYSTEM_LOGICAL_PROCESSOR_INFORMATION));
                            Item += size;
                        }
                        return Buffer;
                    }
                }
                finally
                {
                    Marshal.FreeHGlobal(Ptr);
                }
            }
            return null;
        }
    }
}
"@
	$cp = New-Object CodeDom.Compiler.CompilerParameters
	$cp.CompilerOptions = "/unsafe"
	$cp.WarningLevel = 4
	$cp.TreatWarningsAsErrors = $false
	$cp.ReferencedAssemblies.Add("System.dll") | Out-Null
	Add-Type -TypeDefinition $NumaCSharp -CompilerParameters $cp

	$NumaPresent = $false
	$NumaNode = [Windows.Kernel32]::MyGetLogicalProcessorInformation()
	$NumaNodeCount = ($NumaNode | where { $_.Relationship -eq "RelationNumaNode" }).count
	if ($NumaNodeCount -gt 1) {
		Write-BISFLog -Msg "NumaNode detected" -ShowConsole -Color DarkCyan -SubMsg
		$NumaPresent = $true
	}

}

Process {

	function Enable-RSSForVMXNet3 {
		#count the number of VMXNet3 NIC's
		$VMXNet3Nics = (Get-WmiObject win32_networkadapter -filter "netconnectionstatus = 2" | where { $_.ServiceName -eq "vmxnet3ndis6" })
		$NICCount = 0
		foreach ($netAdapter in $VMXNet3Nics) {
			$NICCount++
		}

		foreach ($a in (ls "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}" -Recurse -ErrorAction SilentlyContinue)) {
			if ($a.Property -like "`*RSS") {
				if ($a.GetValue("*RSS") -eq 0) {
					Write-BISFLog -Msg "Found *RSS disabled on an individual NIC. Enabling..."
					Set-ItemProperty -Path $a.PSPath -Name "*RSS" -Value 1
				}
			}
		}
		Write-BISFLog -Msg "Configuring RSS on 2008 R2."
		#maximum number of RSS processors is 8 for VMXNet3 per NIC.  If we have less than 8 CPU's then count the number of NIC's
		#base Processor Number starts at 0, so set to 1.
		$baseProcessorNumber = 1

		#We want to avoid overlapping CPU cores with NIC assignments. I am going to divide # of CPU's by # of NIC's and then assign accordingly  So to assign CPU's to NIC we need to follow this table:
		<#   #MaxProc per NIC chart
                CPU
            NIC      1   2   3   4   5
                    --------------------
                2  | 1   1   1   1   1
                3  | 2   1   1   1   1
                4  | 2   1   1   1   1
                5  | 4   2   1   1   1
                6  | 4   2   1   1   1
                7  | 4   2   2   1   1
                8  | 4   2   2   1   1
                9  | 8   4   2   2   1
        #>
		#count is done that you need N+1 CPU's to bump up a MaxProc level upto a maximum of 8. MaxProc must be in powers of 2.  This ensures a *minimum* of 1 CPU free for app processing
		#if we have 1 NIC then we all we need to do is set the BaseProcessorNumber and we can set the MaxProc to 8.  This will use all cores up to the 8th as an RSS processor.  Cores above that will
		#not be used for RSS (but that's fine...  8 should be enough... right?)
		$numberOfProcPerNic = ($CPUCount / $NICCount)
		switch ($numberOfProcPerNic) {
			{ $_ -le 2 } { $MaxProc = 1 }
			{ $_ -gt 2 } { $MaxProc = 2 }
			{ $_ -gt 4 } { $MaxProc = 4 }
			{ $_ -gt 8 } { $MaxProc = 8 }
		}
		$nicCount = 0

		foreach ($netAdapter in $VMXNet3Nics) {
			$nicCount++
			if ($nicCount -eq 1) {
				$baseProcessorNumber = 1
			}
			else {
				$baseProcessorNumber = $maxProcessorNumber + 1
			}
			$maxProcessorNumber = ($baseProcessorNumber + $MaxProc)
			if ($maxProcessorNumber -ge ($CPUCount - 1)) {
				$maxProcessorNumber = ($CPUCount - 1)
			}
			foreach ($a in (ls "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}" -Recurse -ErrorAction SilentlyContinue)) {
				if ($a.Property -like "NetCfgInstanceId") {
					if ($a.GetValue("NetCfgInstanceId") -eq $netAdapter.GUID) {
						Set-ItemProperty -Path $a.PSPath -Name "*MaxRssProcessors" -Value $MaxProc -Type String
						Set-ItemProperty -Path $a.PSPath -Name "*RssBaseProcNumber" -Value $baseProcessorNumber -Type String
					}
				}
			}
		}
	}
    IF ($returnGetHypervisor -like "VMware*") {
	    Write-BISFLog -Msg "Starting VMWare TCPIP Optimizations" -ShowConsole -Color Cyan

	                                                                                        if ($OS -like "*2008 R2*") {
		<# Configure RSS for 2008R2 #>
		$tcpGlobalParameters = netsh interface tcp show global
		$netParameters = @()
		foreach ($line in $tcpGlobalParameters) {
			if ($line.Contains(":")) {
				$object = New-Object PSObject
				$object | Add-Member -MemberType NoteProperty -Name Setting -Value $line.Split(":")[0]
				$object | Add-Member -MemberType NoteProperty -Name State -Value $line.Split(":")[1]
				$netParameters += $object
			}
		}
		foreach ($setting in $netParameters) {
			if ($setting.setting -like "*Receive-Side Scaling State*") {
				if ($setting.State -like "*enabled*") {
					Write-BISFLog "Enabling RSS globally..."
					netsh interface tcp set global rss=enabled
				}
			}
		}
		Enable-RSSForVMXNet3
	}
	                                                                                                                                                                                                                                                                                                                                                                                                            else {
		#for server 2012 R2 and 2016 this should apply
		$NetAdapters = Get-NetAdapter | sort -Property InterfaceDescription
		#check if RSC is enabled globally.  If not, enable on specific vmxnet3 NIC's
		if (((Get-NetOffloadGlobalSetting).ReceiveSegmentCoalescing) -eq "Disabled") {
			foreach ($netAdapter in $netAdapters) {
				if (($netAdapter.InterfaceDescription).StartsWith("vmxnet3")) {
					Write-BISFLog -Msg "Enabling Receive Side Coalescing..." -ShowConsole -Color DarkCyan -SubMsg
					$netAdapter | Set-NetAdapterRsc -IPv4Enabled $true -IPv6Enabled $true
				}
			}
		}

		<#

        Configure RSS...  We are going to configure RSS on the basis of N-1 CPU.  This will ensure a minimum of 1 CPU will always be available for OS/Apps.
        There are two exceptions to configuring RSS.

           #1 - Two or less CPU's present.  Although we could configure RSS to use a single core we may hurt performance more than help by doing os.
           #2 - Equal number of NIC's to (# of CPU's -1)

        So let's check for exceptions first and exit out if found.
        #>



		#if RSS is not configured for all NIC's we'll enable
		$NICNeedConfiguring = $false
		foreach ($netAdapter in $netAdapters) {
			if (($netAdapter | Get-NetAdapter).Enabled -eq $false) {
				$setRSS = $true
				break
			}
		}

		if ($setRSS -eq $false) {
			Write-BISFLog -Msg "All NICS configured accordingly - exiting" -ShowConsole -Color DarkCyan -SubMsg
		}

		<#enable RSS and set processor values.
        set RSS to not use the 1st processor - http://windowsitpro.com/hyper-v/why-you-skip-first-core-when-configuring-rss-and-vmq
        "In both RSS and DVMQ configurations there is a BaseProcessorNumber parameter which often is set to 1 while the actual processors start at 0. This specifies the starting processor to be used for processing by the NIC. The reason for this is to reserve CPU 0 for OS processes since the OS tends to use CPU 0 for most of its system processing and this is a best practice as it removes contention between the system and network processing. Note that if using multiple NICs it is recommended to not overlap logical processor usage if possible, for example the first NIC may use cores 1 through 4 while the next would use cores 5 through 8 and so on."
        Also disable RSS on low CPU count systems ( -le 2) - https://blogs.technet.microsoft.com/networking/2013/07/31/drive-up-networking-performance-for-your-most-demanding-workloads-with-virtual-rss/

        "There is a catch and that’s the reason why vRSS is not enabled by default on any VMs. There are extra calculations that must be done to accomplish the spreading which leads to higher CPU utilization in the host. This means that small VMs with minimal or average network traffic will not want to enable this feature."

        "To fully utilize the CPUs, the number of RSS Receive Queues must be equal to or greater than Max Processors." - https://technet.microsoft.com/en-us/library/jj574168%28v=ws.11%29.aspx?f=255&MSPPError=-2147217396
            ^^--RSS must be enabled first for Receive Queues to become available on VMXNet3
        #>

		if ($setRSS -eq $true) {

			Write-BISFLog -Msg "Passed checks.  Enabling RSS."
			#maximum number of RSS processors is 8 for VMXNet3 per NIC.  If we have less than 8 CPU's then count the number of NIC's
			#This script does not take NUMA into consideration (at this time) so NIC assignment will be against all CPU's(-1)
			#base Processor Number starts at 0, so set to 1.
			$baseProcessorNumber = 1

			if ($NumaPresent) {
				$profile = "NUMA"
			}
			else {
				$profile = "Closest" #Closest. Logical processor numbers that are near the network adapter’s base RSS processor are preferred. With this profile, the operating system might rebalance logical processors dynamically based on load. - https://technet.microsoft.com/en-us/library/jj574168(v=ws.11).aspx
			}


			#We want to avoid overlapping CPU cores with NIC assignments. I am going to divide # of CPU's by # of NIC's and then assign accordingly  So to assign CPU's to NIC we need to follow this table:
			<#   #MaxProc per NIC chart
                    CPU
                NIC      1   2   3   4   5
                        --------------------
                    2  | 1   1   1   1   1
                    3  | 2   1   1   1   1
                    4  | 2   1   1   1   1
                    5  | 4   2   1   1   1
                    6  | 4   2   1   1   1
                    7  | 4   2   2   1   1
                    8  | 4   2   2   1   1
                    9  | 8   4   2   2   1

            #count is done that you need N+1 CPU's to bump up a MaxProc level upto a maximum of 8. MaxProc must be in powers of 2.  This ensures a *minimum* of 1 CPU free for app processing
            #if we have 1 NIC then we all we need to do is set the BaseProcessorNumber and we can set the MaxProc to 8.  This will use all cores up to the 8th as an RSS processor.  Cores above that will
            #not be used for RSS (but that's fine...  8 should be enough... right?)

            ##IF NUMA IS PRESENT THIS SCRIPT CURRENTLY ASSUMES THAT THERE ARE NOT MORE NICs THAN NUMA NODES

            #>
			$numberOfProcPerNic = ($CPUCount / $NICCount)
			switch ($numberOfProcPerNic) {
				{ $_ -le 2 } { $MaxProc = 1 }
				{ $_ -gt 2 } { $MaxProc = 2 }
				{ $_ -gt 4 } { $MaxProc = 4 }
				{ $_ -gt 8 } { $MaxProc = 8 }
			}
			$nicCount = 0

			foreach ($netAdapter in $netAdapters) {
				$nicCount++
				if ($nicCount -eq 1) {
					$baseProcessorNumber = 1
				}
				else {
					$baseProcessorNumber = $maxProcessorNumber + 1
				}
				$maxProcessorNumber = ($baseProcessorNumber + $MaxProc)
				if ($maxProcessorNumber -ge ($CPUCount - 1)) {
					$maxProcessorNumber = ($CPUCount - 1)
				}
				if ($NumaPresent) {
					$netAdapter | Set-NetAdapterRSS -Enabled $true -BaseProcessorGroup $NICCount -BaseProcessorNumber $baseProcessorNumber -MaxProcessors $MaxProc -MaxProcessorNumber $maxProcessorNumber -profile $profile
				}
				else {
					$netAdapter | Set-NetAdapterRSS -Enabled $true -BaseProcessorNumber $baseProcessorNumber -MaxProcessors $MaxProc -MaxProcessorNumber $maxProcessorNumber -profile $profile
				}

			}
			Write-BISFLog -Msg "RSS Enabled Results: " -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "$($NetAdapter | get-netadapterrss | Out-String)" -ShowConsole -Color DarkCyan -SubMsg
		}
	}

	    $tcpAckConfigured = $false
	    Write-BISFLog -Msg "Configuring TCPAckFrequency..." -ShowConsole -Color DarkCyan -SubMsg
	    $strGUIDS = [array](Get-WmiObject win32_networkadapter -filter "netconnectionstatus = 2" )
	    foreach ($strGUID in $strGUIDS) {
		    if (-not(((Get-ItemProperty  -path HKLM:\System\CurrentControlSet\services\Tcpip\Parameters\Interfaces\$($strGUID.GUID)).TcpAckFrequency) -eq 1)) {
			    Write-BISFLog -Msg "Configuring TCPAckFrequency on the Network Adapters : $($strGUID.Name)" -ShowConsole -Color DarkCyan -SubMsg
			    New-ItemProperty -path HKLM:\System\CurrentControlSet\services\Tcpip\Parameters\Interfaces\$($strGUID.GUID) -propertytype DWORD -name TcpAckFrequency -value 1 | Out-Null
			    $tcpAckConfigured = $true
		    }
	    }
	    if ($tcpAckConfigured -eq $true) {
		    Write-BISFLog -Msg "TCPAckFrequency was configured." -ShowConsole -Color DarkCyan -SubMsg
	    }
     else {
		    Write-BISFLog -Msg "TCPAckFrequency was already set." -ShowConsole -Color DarkCyan -SubMsg
	    }
    } ELSE {
         Write-BISFLog -Msg "NO VMWare Hypervisor detected for starting VMWare TCPIP Optimizations"
    }
}


End {
	Add-BISFFinishLine
}
