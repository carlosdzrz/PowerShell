#region Help
<#
	.SYNOPSIS    
		Creates a HTML Report describing the RDS 2012 environment.

	    THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	    RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.

        Version 1.0 January 2017

    .DESCRIPTION 
        This script creates a HTML report showing the following information about an Remote 
        Desktop Services 2012 environment. 
		Report details:
		
		1) Servers & Roles:

			o Server names and their roles

		2) Deployment Overview:
        
			o Workspace Info
				* WorkspaceID
                * WorkspaceName
			o Deployment with Connection Broker High Availability (shown only HA Deployments)
				* ClientAccessName
				* Database Connection String

		3) GateWay Info:

			o Gatewaymode
				* Automatic
				* DoNotUse
				* Custom
			o LogonMethod
				* Password
				* Smartcard
				* AllowUserToSelectRuntime
			o GatewayExternalFQDN (External FQDN of the RD Gateway server specified for the deployment.)

		4) Session Host Info:

			o Collection Names
			o Host servers from each collection
			o Resource Type from each collection
			o Profile Disk (True / False)
				* Disk Path (shown as tooltip)
				* Max Size (shown as tooltip)
			o Remote App published

		5) Virtualization Host Info:

			o Collection Names
			o Collection Type
				* PersonalManaged
				* PersonalUnmanaged
				* PooledManaged
				* PooledUnmanaged
			o Size (Number of Virtual Desktop from each collection)
			o VirtualDesktop Rollback (True / False)
			o Storage Type
				* LocalStorage
				* CentralSmbShareStorage
				* CentralSanStorage
			o VirtualDesktop Name Prefix
			o Profile Disk (True / False)
				* Disk Path (shown as tooltip)
				* Max Size (shown as tooltip)    

	.PARAMETER ReportFilePath
        HTML report file path. $env:SystemDrive + "\temp" directory is the default value.
	
	.PARAMETER SendMail
	    Send Mail after completion. Set to $True to enable. If enabled, -MailFrom, -MailTo, -MailServer are mandatory
	
	.PARAMETER MailFrom
	    Email address to send from. Passed directly to Send-MailMessage as -From
	
	.PARAMETER MailTo
	    Email address to send to. Passed directly to Send-MailMessage as -To
	
	.PARAMETER MailServer
	    SMTP Mail server to attempt to send through. Passed directly to Send-MailMessage as -SmtpServer

	.EXAMPLE
		Creates a RDS 2012 report in the SystemDrive + "\temp\RDS_report.html" directory.
		.\Get-RDSReport.ps1
		
	.EXAMPLE
		Creates a RDS 2012 report with RDS_report.html file name and saves is to the specified folder.
		.\Get-RDSReport.ps1 -ReportFilePath c:\carlosdzrz\reports		

	.EXAMPLE
		Creates a RDS 2012 report and sends it to multiple recipients as attachment without smtp authentication.
		.\Get-RDSReport.ps1 -SendMail $true -MailServer 10.29.0.50 -MailFrom sender@rds.corp -MailTo recepient1@rds.corp,recepient2@rds.corp
 
	.INPUTS
		None
 
	.OUTPUTS
		Html Report file
 
	.NOTES
		Author: CarlosDZRZ
		Date created: 25.January.2017
		Version: 1.0
 
	.LINK
		https://technet.microsoft.com/library/jj215451(v=wps.630).aspx
        https://social.technet.microsoft.com/wiki/contents/articles/12835.using-powershell-to-install-configure-and-maintain-rds-in-windows-server-2012.aspx
        Html Style:
		https://gallery.technet.microsoft.com/scriptcenter/Hyper-V-Reporting-Script-4adaf5d0		
#>
#endregion Help

#region Script Parameters
# -----------------------
param(
    [parameter(Position=0,Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Filename to write HTML report to')][string]$ReportFilePath = $env:SystemDrive + "\temp",
	[parameter(Position=1,Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Send Mail ($True/$False)')][bool]$SendMail=$false,
	[parameter(Position=2,Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Mail From')][string]$MailFrom,
	[parameter(Position=3,Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Mail To')]$MailTo,
	[parameter(Position=4,Mandatory=$false,ValueFromPipeline=$false,HelpMessage='Mail Server')][string]$MailServer
)
#endregion Script Parameters

#region Functions
# Sub Function to neatly update progress
function UpdateProgress
{
	param($PercentComplete,$Status)
	Write-Progress -id 1 -activity "Get-RDSReport" -status $Status -percentComplete $PercentComplete
}
#endregion Functions

#region Check Requirements
UpdateProgress 5 "Checking Requirements"
#Check if Role RDS-Connection-Broker exist
$RDSCBRole = Get-WindowsFeature -Name RDS-Connection-Broker
if (!$RDSCBRole.Installed)
{
	throw "The script must execute on the Connection Broker"
}

#Check if ReportFilePath exist
if (Test-Path -Path $ReportFilePath -PathType Container)
{
	#$HTMLReport --> Filename to write HTML Report to
	$HTMLReport = $ReportFilePath + "\RDS_report.html"
}
else
{
	New-Item -Path $ReportFilePath -ItemType directory
	Write-Host -ForegroundColor Green "create a new folder $ReportFilePath"
	$HTMLReport = $ReportFilePath + "\RDS_report.html"
}

#Check if -SendMail parameter set and if so check -MailFrom, -MailTo and -MailServer are set
if ($SendMail)
{
	if (!$MailFrom -or !$MailTo -or !$MailServer)
	{
		throw "If -SendMail specified, you must also specify -MailFrom, -MailTo and -MailServer"
	}
}
#endregion Check Requirements

#region Variables
#----------------

# State Colors
[array]$stateBgColors = "", "#ACFA58","#E6E6E6","#FB7171","#FBD95B","#BDD7EE" #0-Null, 1-Online(green), 2-Offline(grey), 3-Failed/Critical(red), 4-Warning(orange), 5-Other(blue)
[array]$stateWordColors = "", "#298A08","#848484","#A40000","#9C6500","#204F7A","#FFFFFF" #0-Null, 1-Online(green), 2-Offline(grey), 3-Failed/Critical(red), 4-Warning(orange), 5-Other(blue), 6-White

# Date and Time
$Date = Get-Date -Format d/MMM/yyyy
$Time = Get-Date -Format "hh:mm:ss tt"

#RDS variables
UpdateProgress 10 "Initializing variables"
Import-Module RemoteDesktop
$FormatEnumerationLimit = 40
$CB = $null
$CBHA = $null
$CBRole = $null
#Get Connection Broker
if (Get-RDConnectionBrokerHighAvailability -ErrorAction Stop)
{
    $CBHA = Get-RDConnectionBrokerHighAvailability
    $CB = $CBHA.ActiveManagementServer
}
else
{
    $CBRole = Get-RDServer | Where-Object{$_.Roles -match 'RDS-CONNECTION-BROKER'}
    $CB = $CBRole.Server
}
$outDeploymentOverviewTable = ""
$outGateWayTable = ""
$outSessionHostTable = ""
$outVirtualizationHostTable = ""
#when true paint Gateway Configuration Table information
[bool]$RolGWInstalled = $false
#when true paint Session Host Table information
[bool]$RolSHInstalled = $false
#when true paint Virutalization Host Table information
[bool]$RolVHInstalled = $false
#endregion Variables

#region HTML Start
#----------------

UpdateProgress 15 "Writing HTML Report Header"
# HTML Head
$outHtmlStart = "<!DOCTYPE html>
<html>
<head>
<title>RDS 2012 Environment Report</title>
<style>
/*Reset CSS*/
html, body, div, span, applet, object, iframe, h1, h2, h3, h4, h5, h6, p, blockquote, pre, a, abbr, acronym, address, big, cite, code, del, dfn, em, img, ins, kbd, q, s, samp,
small, strike, strong, sub, sup, tt, var, b, u, i, center, dl, dt, dd, ol, ul, li, fieldset, form, label, legend, table, caption, tbody, tfoot, thead, tr, th, td,
article, aside, canvas, details, embed, figure, figcaption, footer, header, hgroup, menu, nav, output, ruby, section, summary, 
time, mark, audio, video {margin: 0;padding: 0;border: 0;font-size: 100%;font: inherit;vertical-align: baseline;}
ol, ul {list-style: none;}
blockquote, q {quotes: none;}
blockquote:before, blockquote:after,
q:before, q:after {content: '';content: none;}
table {border-collapse: collapse;border-spacing: 0;}
/*Reset CSS*/

body{
    width:100%;
    min-width:1024px;
    font-family: Verdana, sans-serif;
    font-size:14px;
    line-height:1.5;
    color:#222222;
    background-color:#fcfcfc;
}

p{
    color:222222;
}

strong{
    font-weight:600;
}

h1{
    font-size:30px;
    font-weight:300;
}

h2{
    font-size:20px;
    font-weight:300;
}

#ReportBody{
    width:95%;
    height:500;
    margin: 0 auto;
}

table{
    width:100%;
    min-width:1280px;
    border: 1px solid #CCCCCC;
}

/*Row*/
tr{
    font-size: 12px;
}

/*Column*/
td {
    padding:10px 8px 10px 8px;
    font-size: 12px;
    border: 1px solid #CCCCCC;
    text-align:center;
    vertical-align:middle;
}

/*Table Heading*/
th {
    background: #f3f3f3;
    border: 1px solid #CCCCCC;
    font-size: 14px;
    font-weight:normal;
    padding:12px;
    text-align:center;
    vertical-align:middle;
}

.Deployment-Overview{
    width:100%;
    float:left;
    margin-bottom:30px;
}

table#Deployment-Overview-Table tr:nth-child(odd){
    background:#F9F9F9;
}

.Roles{
    width:100%;
    float:left;
    margin-bottom:30px;
}

table#Roles-Table tr:nth-child(odd){
    background:#F9F9F9;
}

.GateWay{
    width:100%;
    float:left;
    margin-bottom:30px;
}

table#GateWay-Table tr:nth-child(odd){
    background:#F9F9F9;
}

.Session-Host{
    width:100%;
    float:left;
    margin-bottom:30px;
}

table#Session-Host-Table tr:nth-child(odd){
    background:#F9F9F9;
}

.Virtualization-Host{
    width:100%;
    float:left;
    margin-bottom:22px;
    line-height:1.5;
}

table#Virtualization-Host-Table tr:nth-child(odd){
    background:#F9F9F9;
}
</style>
</head>
<body>
<br><br>
<center><h1>RDS 2012 Environment Report</h1></center>
<center><font face=""Verdana,sans-serif"" size=""3"" color=""#222222"">Generated on $($Date) at $($Time)</font></center>
<br>
<div id=""ReportBody""><!--Start ReportBody-->"
#endregion HTML Start

#region Gathering Roles & Servers
UpdateProgress 25 "Writing HTML Roles & Servers Information"
#Roles-Table Header
$outRolesTableStart ="
<div class=""Roles""><!--Start Roles Class-->
    <h2>Servers & Roles</h2><br>
    <table id=""Roles-Table"">
    <tbody>
        <tr><!--Header Line-->
            <th><p style=""text-align:left;margin-left:-4px"">SERVER NAME</p></th>
            <th><p>LICENSING</p></th>
            <th><p>GATEWAY</p></th>
            <th><p style=""line-height:1.2"">CONNECTION<br>BROKER</p></th>
            <th><p style=""line-height:1.2"">WEB<br>ACCESS</p></th>
            <th><p style=""line-height:1.2"">SESSION<br>HOST</p></th>
            <th><p style=""line-height:1.2"">VIRTUALIZATION<br>HOST</p></th>
        </tr>"

# Generate Data Lines
$Servers = Get-RDServer -ConnectionBroker $CB
$outRolesTableData = $null
foreach ($server in $servers)
{
    $servername = $server.Server.ToUpper()
    $roles = $server.Roles
    $RolInstalledCB = "", $stateBgColors[0],$stateWordColors[2]
    $RolInstalledWA = "", $stateBgColors[0],$stateWordColors[2]
    $RolInstalledLIC = "", $stateBgColors[0],$stateWordColors[2]
    $RolInstalledSH = "", $stateBgColors[0],$stateWordColors[2]
    $RolInstalledVH = "", $stateBgColors[0],$stateWordColors[2]
    $RolInstalledGW = "", $stateBgColors[0],$stateWordColors[2]
    #colors Roles
    foreach ($rol in $roles)
    {
        if ($rol -eq 'RDS-CONNECTION-BROKER')
        {
            $RolInstalledCB = "X",$stateBgColors[1],$stateWordColors[1]
        }
        if ($rol -eq 'RDS-WEB-ACCESS')
        {
            $RolInstalledWA = "X",$stateBgColors[1],$stateWordColors[1]
        }
        if ($rol -eq 'RDS-LICENSING')
        {
            $RolInstalledLIC = "X",$stateBgColors[1],$stateWordColors[1]
        }
        if ($rol -eq 'RDS-RD-SERVER')
        {
            $RolInstalledSH = "X",$stateBgColors[1],$stateWordColors[1]
            $RolSHInstalled = $true            
        }
        if ($rol -eq 'RDS-VIRTUALIZATION')
        {
            $RolInstalledVH = "X",$stateBgColors[1],$stateWordColors[1]
            $RolVHInstalled = $true
        }
        if ($rol -eq 'RDS-GATEWAY')
        {
            $RolInstalledGW = "X",$stateBgColors[1],$stateWordColors[1]
			$RolGWInstalled = $true
        }
    }
    $outRolesTableData += "
        <tr><!--Data Line-->
            <td><p style=""text-align:left;"">$($servername)</p></td>
            <td bgcolor=""$($RolInstalledLIC[1])""><p style=""color:$($RolInstalledLIC[2])"">$($RolInstalledLIC[0])</p></td>
            <td bgcolor=""$($RolInstalledGW[1])""><p style=""color:$($RolInstalledGW[2])"">$($RolInstalledGW[0])</p></td>
            <td bgcolor=""$($RolInstalledCB[1])""><p style=""color:$($RolInstalledCB[2])"">$($RolInstalledCB[0])</p></td>
            <td bgcolor=""$($RolInstalledWA[1])""><p style=""color:$($RolInstalledWA[2])"">$($RolInstalledWA[0])</p></td>
            <td bgcolor=""$($RolInstalledSH[1])""><p style=""color:$($RolInstalledSH[2])"">$($RolInstalledSH[0])</p></td>
            <td bgcolor=""$($RolInstalledVH[1])""><p style=""color:$($RolInstalledVH[2])"">$($RolInstalledVH[0])</p></td>
        </tr>"
}

#End Roles-Table
$outRolesTableEnd ="
    </tbody>
    </table>
</div><!--End Roles Class-->"

$outRolesTable = $outRolesTableStart + $outRolesTableData + $outRolesTableEnd

#endregion Gathering Roles & Servers

#region Gathering Deployment Overview
#Get Workspace
UpdateProgress 35 "Writing HTML Deployment Overview"
$WS = Get-RDWorkspace -ConnectionBroker $CB
$outDeploymentOverviewTable += "
<div class=""Deployment-Overview""><!--Start Deployment-Overview Class-->
    <h2>Deployment Overview</h2><br>
    <table id=""Deployment-Overview-Table"">
    <tbody>
        <tr><!--Header Line-->
            <th><p style=""text-align:left;margin-left:-4px"">WorkspaceID</p></th>
            <th><p>WorkspaceName</p></th>"
if ($CBHA)
{
    $outDeploymentOverviewTable +="
            <th><p>ClientAccessName</p></th>
            <th><p>DatabaseConnectionString</p></th>"
}
$outDeploymentOverviewTable += "
        </tr>
        <tr><!--Data Line-->
            <td><p style=""text-align:left;"">$($WS.WorkspaceID)</p></td>
            <td><p style=""text-align:left;"">$($WS.WorkspaceName)</p></td>"
if ($CBHA)
{
    $outDeploymentOverviewTable +="
        <td><p style=""text-align:left;"">$($CBHA.ClientAccessName)</p></td>
        <td><p style=""text-align:left;"">$($CBHA.DatabaseConnectionString)</p></td>"
}
$outDeploymentOverviewTable +="
        </tr>
    </tbody>
    </table>
</div><!--End Deployment-Overview Class-->"
#endregion Gathering Deployment-Overview

#region Gathering Gateway Configuration
if ($RolGWInstalled)
{
	UpdateProgress 40 "Writing HTML Gateway Configuration"
	$GWConfiguration = Get-RDDeploymentGatewayConfiguration -ConnectionBroker $CB
	#Gateway-Table
    $outGateWayTable ="
    <div class=""GateWay""><!--Start GateWay Class-->
        <h2>GateWay Configuration</h2><br>
        <table id=""GateWay-Table"">
        <tbody>
            <tr><!--Header Line-->
                <th><p style=""text-align:left;margin-left:-4px"">Gatewaymode</p></th>
				<th><p style=""text-align:left;margin-left:-4px"">LogonMethod</p></th>
				<th><p style=""text-align:left;margin-left:-4px"">GatewayExternalFQDN</p></th>
            </tr>
	    	<tr><!--Data Line-->
	        	<td><p style=""text-align:left;"">$($GWConfiguration.Gatewaymode)</p></td>
	            <td><p style=""text-align:left;"">$($GWConfiguration.LogonMethod)</p></td>
	            <td><p style=""text-align:left;"">$($GWConfiguration.GatewayExternalFQDN)</p></td>
			</tr>
        </tbody>
        </table>
    </div><!--End GateWay Class-->"
}
#endregion Gathering Gateway Configuration

#region Gathering Session Host
if ($RolSHInstalled)
{
    UpdateProgress 50 "Writing HTML Session Host Servers Information"
    #Session-Host-Table Header
    $outSessionHostTableStart ="
    <div class=""Session-Host""><!--Start Session-Host Class-->
        <h2>Session Host Info</h2><br>
        <table id=""Session-Table"">
        <tbody>
            <tr><!--Header Line-->
                <th><p style=""text-align:left;margin-left:-4px"">COLLECTION</p></th>
                <th><p>SERVERS</p></th>
                <th><p style=""line-height:1.2"">Resource<br>Type</p></th>
                <th><p style=""line-height:1.2"">Profile<br>Disk</p></th>
                <th><p style=""line-height:1.2"">Remote<br>App</p></th>
            </tr>"
    # Generate Data Lines
    $SH_collections = Get-RDSessionCollection -ConnectionBroker $CB
    $outSessionHostTableData = $null
    foreach ($SH_collection in $SH_collections)
    {
	    $collectionSH = $null
	    $serversSH = $null
	    $ResourceType = $null
	    $ProfileDiskSH = $null
	    $RemoteApps = $null
	    $outRemoteApps = $null
        $collectionSH = $SH_collection.CollectionName
        $serversSH = Get-RDSessionHost -CollectionName $collectionSH -ConnectionBroker $CB
        $outserversSH = $serversSH.SessionHost.ToUpper() -join "<br>"
        $ResourceType = $SH_collection.ResourceType
        $ProfileDiskSH = Get-RDSessionCollectionConfiguration -CollectionName $collectionSH -UserProfileDisk -ConnectionBroker $CB
        $RemoteApps = Get-RDRemoteApp -CollectionName $collectionSH -ConnectionBroker $CB
        $outRemoteApps = $RemoteApps.Alias -join "<br>"
        $outSessionHostTableData += "
            <tr><!--Data Line-->
                <td><p style=""text-align:left;"">$($collectionSH)</p></td>
                <td><p style=""text-align:left;"">$($outserversSH)</p></td>
                <td><p style=""text-align:center;"">$($ResourceType)</p></td>"
        if($ProfileDiskSH.EnableUserProfileDisk -eq $true)
        {
            #&#10 a line break.
            $outSessionHostTableData += "
                <td><p style=""text-align:center;""><abbr title=""Disk Path: $($ProfileDiskSH.DiskPath)&#10;Max Size: $($ProfileDiskSH.MaxUserProfileDiskSizeGB) GB"">$($ProfileDiskSH.EnableUserProfileDisk) <span style=""font-size:10px;color:orange"">*</span></abbr></p></td>"
        }
        else
        {
            $outSessionHostTableData += "
                <td><p style=""text-align:center;"">$($ProfileDiskSH.EnableUserProfileDisk)</p></td>"
        }
        $outSessionHostTableData += "
                <td><p style=""text-align:left;"">$($outRemoteApps)</p></td>
            </tr>"
    }

    #End Session-Table
    $outSessionHostTableEnd ="
        </tbody>
        </table>
    </div><!--End Session Class-->"

    $outSessionHostTable = $outSessionHostTableStart + $outSessionHostTableData + $outSessionHostTableEnd
}
#endregion Gathering Session Host

#region Gathering Virtualization Host
if ($RolVHInstalled)
{
    UpdateProgress 75 "Writing HTML Session Virtualization Servers Information"
    #Virtualization-Host-Table Header
    $outVirtualizationHostTableStart ="
    <div class=""Virtualization-Host""><!--Start Virtualization-Host Class-->
        <h2>Virtualization Host Info</h2><br>
        <table id=""Virtualization-Table"">
        <tbody>
            <tr><!--Header Line-->
                <th><p style=""text-align:left;margin-left:-4px"">COLLECTION</p></th>
                <th><p>Type</p></th>
                <th><p>Size</p></th>
                <th><p style=""line-height:1.2"">VirtualDesktop<br>Rollback</p></th>
                <th><p style=""line-height:1.2"">StorageType</p></th>
                <th><p style=""line-height:1.2"">VirtualDesktopTemplate<br>ExportPath</p></th>
                <th><p style=""line-height:1.2"">VirtualDesktop<br>NamePrefix</p></th>
                <th><p style=""line-height:1.2"">Profile<br>Disk</p></th>
            </tr>"
    # Generate Data Lines
    $VH_collections = Get-RDVirtualDesktopCollection -ConnectionBroker $CB
    $outVirtualizationHostTableData = $null
    foreach ($VH_collection in $VH_collections)
    {
	    $collectionVH = $null
	    $VirtualDesktopInfo = $null
	    $VirtualDesktopConfig = $null
	    $ProfileDiskVH = $null
        $collectionVH = $VH_collection.CollectionName
        $VirtualDesktopInfo = Get-RDVirtualDesktopCollection -CollectionName $collectionVH -ConnectionBroker $CB
        $VirtualDesktopConfig = Get-RDVirtualDesktopCollectionConfiguration -CollectionName $collectionVH -VirtualDesktopConfiguration -ConnectionBroker $CB
        $ProfileDiskVH = Get-RDVirtualDesktopCollectionConfiguration -CollectionName $collectionVH -UserProfileDisks -ConnectionBroker $CB
        $outVirtualizationHostTableData += "
            <tr><!--Data Line-->
                <td><p style=""text-align:left;"">$($collectionVH)</p></td>
                <td><p style=""text-align:center;"">$($VH_collection.Type)</p></td>
                <td><p style=""text-align:center;"">$($VH_collection.Size)</p></td>
                <td><p style=""text-align:center;"">$($VirtualDesktopInfo.VirtualDesktopRollback)</p></td>"
        #If you specify LocalStorage, specify a value for the LocalStoragePath parameter. 
        if ($VirtualDesktopConfig.StorageType -eq "LocalStorage")
        {
            $outVirtualizationHostTableData += "
                <td><p style=""text-align:center;""><abbr title=""Storage Path: $($VirtualDesktopConfig.LocalStoragePath)"">$($VirtualDesktopConfig.StorageType)<span style=""font-size:10px;color:orange"">*</span></abbr></p></td>"
        }
        #If you specify CentralSMBSharedStorage or CentralSanStorage, specify a value for the CentralStorage parameter.
        else
        {
            $outVirtualizationHostTableData += "
                <td><p style=""text-align:center;""><abbr title=""Storage Path: $($VirtualDesktopConfig.CentralStoragePath)"">$($VirtualDesktopConfig.StorageType)<span style=""font-size:10px;color:orange"">*</span></abbr></p></td>"
        }
        $outVirtualizationHostTableData += "
                <td><p style=""text-align:left;"">$($VirtualDesktopConfig.VirtualDesktopTemplateExportPath)</p></td>
                <td><p style=""text-align:left;"">$($VirtualDesktopConfig.VirtualDesktopNamePrefix)</p></td>"
        if($ProfileDiskVH.EnableUserProfileDisks -eq $true)
        {
            $outVirtualizationHostTableData += "
                <td><p style=""text-align:center;""><abbr title=""Disk Path: $($ProfileDiskVH.DiskPath)&#10;Max Size: $($ProfileDiskVH.MaxUserProfileDiskSizeGB) GB"">$($ProfileDiskVH.EnableUserProfileDisks) <span style=""font-size:10px;color:orange"">*</span></abbr></p></td></tr>"
        }
        else
        {
            $outVirtualizationHostTableData += "
                <td><p style=""text-align:center;"">$($ProfileDiskVH.EnableUserProfileDisks)</p></td></tr>"
        }        
    }

    #End Virtualization-Table
    $outVirtualizationHostTableEnd ="
        </tbody>
        </table>
    </div><!--End Virtualization Class-->"

    $outVirtualizationHostTable = $outVirtualizationHostTableStart + $outVirtualizationHostTableData + $outVirtualizationHostTableEnd
}
#endregion Gathering Virtualization Host

#region HTML End
#---------------
UpdateProgress 90 "Writing HTML Report"
$outHtmlEnd ="
</div><!--End ReportBody-->
<center><p style=""font-size:12px;color:#BDBDBD"">ScriptVersion: 1.0 | CreatedBy: CarlosDZRZ </p></center>
<br>
</body>
</html>"

$outFullHTML = $outHtmlStart + $outRolesTable + $outDeploymentOverviewTable + $outGateWayTable + $outSessionHostTable + $outVirtualizationHostTable + $outHtmlEnd
$outFullHTML | Out-File $HTMLReport

#endregion

if ($SendMail)
{
	UpdateProgress 95 "Sending mail message.."
	Send-MailMessage -Attachments $HTMLReport -To $MailTo -From $MailFrom -Subject "RDS 2012 Environment Report" -BodyAsHtml $outFullHTML -SmtpServer $MailServer
}