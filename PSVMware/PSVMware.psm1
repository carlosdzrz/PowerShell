function Get-VMCustomizationSpec {
<#
    .SYNOPSIS
    Function to retrieve info of Get-OSCustomizationSpec and Get-OSCustomizationNicMapping.
    .DESCRIPTION
    Function to retrieve info of Get-OSCustomizationSpec and Get-OSCustomizationNicMapping.
    .PARAMETER CProfile
    A vSphere OSCustomizationSpecImpl object
    .INPUTS
    System.Management.Automation.PSObject.
    .OUTPUTS
    System.Management.Automation.PSObject.
    .EXAMPLE
    PS> Get-VMCustomizationSpec -CProfile CP_Linux_Suse_12
    .EXAMPLE
    PS> Get-OSCustomizationSpec | Get-VMCustomizationSpec
    .NOTES
    NAME: Get-VMCustomizationSpec
    AUTHOR: CarlosDZRZ
    .LINK
    https://code.vmware.com/web/tool/11.5.0/vmware-powercli
#>  
[CmdletBinding()]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [string[]]$CProfile
)

begin {
    if ( -not (Get-Module  VMware.VimAutomation.Core)) {
        Import-Module VMware.VimAutomation.Core
    }
    if ($null -eq $global:DefaultVIServers.Name) {
        Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
        break
    }
    $CProfile_obj = @()
}
process {
    foreach ($Profile in $CProfile) {
        $Profile = Get-OSCustomizationSpec $Profile
        $ProfileNic = $Profile | Get-OSCustomizationNicMapping
        $CProfile_obj += [PSCustomObject]@{
            Name                = $Profile.Name
            Description         = $Profile.Description
            AutoLogonCount      = $Profile.AutoLogonCount
            ChangeSid           = $Profile.ChangeSid
            Type                = $Profile.Type
            OSType              = $Profile.OSType
            LastUpdate          = $Profile.LastUpdate
            Server              = $Profile.Server
            TimeZone            = $Profile.TimeZone
            Workgroup           = $Profile.Workgroup
            IPMode              = $ProfileNic.IPMode
            IPAddress           = $ProfileNic.IPAddress
            SubnetMask          = $ProfileNic.SubnetMask
            DefaultGateway      = $ProfileNic.DefaultGateway
            AlternateGateway    = $ProfileNic.AlternateGateway
            DnsServer           = $Profile.DnsServer
            DnsSuffix           = $Profile.DnsSuffix
            Domain              = $Profile.Domain
        }#EndPSCustomObject
    }	
}
end {
    return $CProfile_obj
}
}#End Function Get-VMCustomizationSpec

function Get-VMConfig {
<#
    .SYNOPSIS
    Function to retrieve Configuration info of a VM.
    .DESCRIPTION
    Function to retrieve Configuration info of a VM.
    .PARAMETER VM
    A vSphere VM object
    .INPUTS
    System.Management.Automation.PSObject.
    .OUTPUTS
    System.Management.Automation.PSObject.
    .EXAMPLE
    PS> Get-VMConfig -VM VM01, VM02
    .EXAMPLE
    PS> Get-VM VM01, VM02 | Get-VMConfig
    .NOTES
    NAME: Get-VMConfig
    AUTHOR: CarlosDZRZ
    .LINK
    https://code.vmware.com/web/tool/11.5.0/vmware-powercli
#>  
[CmdletBinding()]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [string[]]$VM
)

begin {
    if ( -not (Get-Module  VMware.VimAutomation.Core)) {
        Import-Module VMware.VimAutomation.Core
    }
    if ($null -eq $global:DefaultVIServers.Name) {
        Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
        break
    }
    $VMConfig_obj = @()
}
process {
    foreach ($VMName in $VM) {
        $VMName = Get-VM $VMName
        $VMDT = $VMName | Get-Datastore
        $vSwitch = $VMName | Get-VirtualSwitch
        $vPortGroup = $VMName | Get-VirtualPortGroup
		$VMDisks = $VMName | Get-HardDisk | select Parent, Name, StorageFormat, CapacityGB, Filename
        $VMView = $VMName | Get-View
        $VMConfig_obj += [PSCustomObject]@{
            Name                    = $VMName.Name
            PowerState              = $VMName.PowerState
            NumCpu                  = $VMName.NumCpu
            MemoryGB                = $VMName.MemoryGB
            MemoryHotAddEnabled     = $VMView.Config.MemoryHotAddEnabled
            CpuHotAddEnabled        = $VMView.Config.CpuHotAddEnabled
            CpuHotRemoveEnabled     = $VMView.Config.CpuHotRemoveEnabled
            MaxCpuUsage             = $VMView.Runtime.MaxCpuUsage
            MaxMemoryUsage          = $VMView.Runtime.MaxMemoryUsage
            OverallCpuUsage         = $VMView.Summary.QuickStats.OverallCpuUsage
            OverallCpuDemand        = $VMView.Summary.QuickStats.OverallCpuDemand
            GuestMemoryUsage        = $VMView.Summary.QuickStats.GuestMemoryUsage
            VMMemoryUsage           = $VMView.Summary.QuickStats.HostMemoryUsage
            Uptime                  = (New-TimeSpan -Seconds $VMView.Summary.QuickStats.UptimeSeconds).ToString("d'.'hh':'mm':'ss")
            VMHost                  = $VMName.VMHost
            UsedSpaceGB             = [math]::Round($VMName.UsedSpaceGB, 2)
            ProvisionedSpaceGB      = [math]::Round($VMName.ProvisionedSpaceGB, 2)
            CreateDate              = $VMName.CreateDate
            OSFullName              = $VMName.Guest.OSFullName
            "VMTools Version"       = $VMView.Config.Tools.ToolsVersion
            IPAddress               = $VMName.Guest.IPAddress
            Nics                    = $VMName.Guest.Nics
            Datastore_Name          = $VMDT.Name
            VirtualSwitch           = $vSwitch.Name
            vPortGroup              = $vPortGroup.Name
            VLanId                  = $vPortGroup.VLanId
			Disks					= $VMDisks
        }#EndPSCustomObject
    }	
}
end {
    return $VMConfig_obj
}
}#End Function Get-VMConfig

function Get-VMHostConfig {
<#
    .SYNOPSIS
    Function to retrieve the Configuration info of a vSphere host.
    .DESCRIPTION
    Function to retrieve the Configuration info of a vSphere host.
    .PARAMETER VMHost
    A vSphere ESXi Host object
    .INPUTS
    System.Management.Automation.PSObject.
    .OUTPUTS
    System.Management.Automation.PSObject.
    .EXAMPLE
    PS> Get-VMHostConfig -VMHost ESXi01, ESXi02
    .EXAMPLE
    PS> Get-VMHost ESXi01,ESXi02 | Get-VMHostConfig
    .NOTES
    NAME: Get-VMHostConfig
    AUTHOR: CarlosDZRZ
    .LINK
    https://code.vmware.com/web/tool/11.5.0/vmware-powercli
#>  
[CmdletBinding()]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [string[]]$VMHost
)

begin {
    if ( -not (Get-Module  VMware.VimAutomation.Core)) {
        Import-Module VMware.VimAutomation.Core
    }
    if ($null -eq $global:DefaultVIServers.Name) {
        Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
        break
    }
    $VMHostConfig_obj = @()
}
process {
    foreach ($vHost in $VMHost) {
        $vHost = Get-VMHost $VMHost
        $HostDTlist = $vHost | Get-Datastore
        $VMHostView = $vHost | Get-View
        $VMHostConfig_obj += [PSCustomObject]@{
            Name                    = $vHost.Name
            ConnectionState         = $vHost.ConnectionState
            PowerState              = $vHost.PowerState
            OverallStatus           = $VMHostView.Summary.OverallStatus
            Manufacturer            = $vHost.Manufacturer
            Model                   = $vHost.Model
            NumCpuSockets           = $VMHostView.Summary.Hardware.NumCpuPkgs
            NumCpuCores             = $vHost.NumCpu
            NumCpuThreads           = $VMHostView.Summary.Hardware.NumCpuThreads
            NumNics                 = $VMHostView.Summary.Hardware.NumNics
            NumHBAs                 = $VMHostView.Summary.Hardware.NumHBAs
            CpuTotalMhz             = $vHost.CpuTotalMhz
            CpuUsageMhz             = $vHost.CpuUsageMhz
            MemoryTotalGB           = [math]::Round($vHost.MemoryTotalGB, 2)
            MemoryUsageGB           = [math]::Round($vHost.MemoryUsageGB, 2)
            ProcessorType           = $vHost.ProcessorType
            HyperthreadingActive    = $vHost.HyperthreadingActive
            MaxEVCMode              = $vHost.MaxEVCMode
            Uptime                  = (New-TimeSpan -Seconds $VMHostView.Summary.QuickStats.Uptime).ToString("d'.'hh':'mm':'ss")            
            ManagementServerIp      = $VMHostView.Summary.ManagementServerIp
            VMSwapfileDatastore     = $vHost.VMSwapfileDatastore
            Datastores              = $HostDTlist
        }#EndPSCustomObject
    }
}
end {
    return $VMHostConfig_obj
}
}#End Function Get-VMHostConfig

function Get-VMHostNetworkConfig {
<#
    .SYNOPSIS
    Function to retrieve the Network Configuration info of a vSphere host.
    .DESCRIPTION
    Function to retrieve the Network Configuration info of a vSphere host.
    .PARAMETER VMHost
    A vSphere ESXi Host object
    .INPUTS
    System.Management.Automation.PSObject.
    .OUTPUTS
    System.Management.Automation.PSObject.
    .EXAMPLE
    PS> Get-VMHostNetworkConfig -VMHost ESXi01, ESXi02
    .EXAMPLE
    PS> Get-VMHost ESXi01,ESXi02 | Get-VMHostNetworkConfig
    .NOTES
    NAME: Get-VMHostNetworkConfig
    AUTHOR: CarlosDZRZ
    .LINK
    https://code.vmware.com/web/tool/11.5.0/vmware-powercli
#>  
[CmdletBinding()]
param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [string[]]$VMHost
)

begin {
    if ( -not (Get-Module  VMware.VimAutomation.Core)) {
        Import-Module VMware.VimAutomation.Core
    }
    if ($null -eq $global:DefaultVIServers.Name) {
        Write-Host -ForegroundColor Red "You are not currently connected to any servers. Please connect first using a Connect-VIServer cmdlet."
        break
    }
    $VMHostNetworkConfig_obj = @()
}
process {    
    foreach ($vHost in $VMHost) {
        $vHost = Get-VMHost $VMHost
        $vSwitches = $vHost | Get-VirtualSwitch -Standard
        $vDSwitches = $vHost | Get-VirtualSwitch -Distributed
        #Standard Switches
        foreach ($vSwitch in $vSwitches) {
            $vPortGroups = $vSwitch | Get-VirtualPortGroup
            foreach ($vPortGroup in $vPortGroups){
                $VMHostNetworkConfig_obj += [PSCustomObject]@{
                    VMHost          = $vHost
                    VirtualSwitch   = $vSwitch.Name
                    vPortGroup      = $vPortGroup.Name
                    Nic             = [string]$vSwitch.Nic
                    VLanId          = $vPortGroup.VLanId
                }#EndPSCustomObject
            }
        }
        #Distributed Switches
        foreach ($vDSwitch in $vDSwitches) {
            $vDSwitch = Get-VDSwitch $vDSwitch
            $vDPortGroups = $vDSwitch | Get-VDPortgroup
            foreach ($vDPortGroup in $vDPortGroups){
                $vDPorts = $vDPortGroup | Get-VDPort
                $VMHostNetworkConfig_obj += [PSCustomObject]@{
                    VMHost          = $vHost
                    VirtualSwitch   = $vDSwitch.Name
                    vPortGroup      = $vDPortGroup.Name
                    VLanId          = $vDPortGroup.VlanConfiguration
                }#EndPSCustomObject
            }
        }
    }
}
end {
    return $VMHostNetworkConfig_obj
}
} #End Function Get-VMHostNetworkConfig