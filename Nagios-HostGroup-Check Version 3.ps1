# Stephen Pastoriza 2023-29-11
# PowerShell script to check the status of new PMCS customers and upgrade projects in monitoring.
# Version 3 - Checks access to WinRM Ports

Clear-Host
Set-Location "C:\Users\e5614720\Documents\Nagios_Outputs\HostGroup_Check"

# Nagios Details
$xiserver = "10.18.129.141"
${apikey} = "oIkJnf6Q88VZNcjFgDHcdUbIRKedLHZqlDp28uRAF3vIeSjtLhYXb9GiaaObQNUr"

# Get Host Group Information.
# $Hostgroup = Read-Host "Please enter Host Group name"
Write-Host "Host Group Selected is:" `n$Hostgroup

# Retrieve JSON Host Data from Nagios.
$HostGroupJSON = Invoke-WebRequest -Method GET "http://${xiServer}/nagiosxi/api/v1/config/hostgroup?apikey=${apiKey}&pretty=1"

# Extract ALL SERVER NAMES from Host Group JSON
$AllServers = ((ConvertFrom-Json ${HostGroupJSON}) | where-object hostgroup_name -eq $Hostgroup | Select-Object -ExpandProperty members) -join "|"

# Retrieve HOST DOWN Data from Nagios.
$HostResponseJSON = Invoke-WebRequest -Method GET "http://$xiserver/nagiosxi/api/v1/objects/hoststatus?apikey=${apikey}&pretty=1"

# Extract A Powered Down servers  from HostGroupResponse JSON
$ServersDown = ((ConvertFrom-Json ${HostResponseJSON}.Content).hoststatus | where-object host_name -Match $AllServers |  where-object current_state -eq "1" `
| Select-Object -ExpandProperty host_name -ErrorAction SilentlyContinue) 

# Create a list of servers that are powered up, and remove powered down servers.
$ServersUp = $AllServers + $ServersDown | Group-Object | Where-Object Count -eq 1 | Select-Object -Expand Group

# Retrieve Critical Server Alerts from Nagios.
$ServiceJSON = Invoke-WebRequest -Method GET "http://$xiserver/nagiosxi/api/v1/objects/servicestatus?apikey=${apikey}&pretty=1"

# CRITICAL ALERTS for powered on servers.
$CritiicalAlert = ((ConvertFrom-Json ${ServiceJSON}.Content).servicestatus | where-object host_name -Match $ServersUp | where-object output -Like "*Critical*" `
| Select-Object @{Name="Server Name";Expression={$_.host_name}},@{Name="Details";Expression={$_.output}},@{Name="Service Description";Expression={$_.display_name}} -ErrorAction SilentlyContinue  `
| sort-object "Service Description") 

# UNKNOWN ALERTS for powered on servers.
$UnknwonAlert = ((ConvertFrom-Json ${ServiceJSON}.Content).servicestatus | where-object host_name -Match $ServersUp | where-object output -Like "*No services found for service names*" `
| Select-Object @{Name="Server Name";Expression={$_.host_name}},@{Name="Details";Expression={$_.output}},@{Name="Service Description";Expression={$_.display_name}} -ErrorAction SilentlyContinue  `
| sort-object "Server Name") 

# Produce the Text File to supply to PM.
"The following servers are powered down and need to be powered on for testing: `r "  | Out-File -FilePath .\$Hostgroup.txt
$ServersDown | Out-File  -FilePath .\$Hostgroup.txt -Append 

"  " | Out-File -FilePath .\$Hostgroup.txt -Append
"Total number of powered down servers:" | Out-File -FilePath .\$Hostgroup.txt -Append
$ServersDown.count | Out-File  -FilePath .\$Hostgroup.txt -Append

"  " | Out-File -FilePath .\$Hostgroup.txt -Append
"Critical alerts that needs to be addressed:" | Out-File -FilePath .\$Hostgroup.txt -Append
$CritiicalAlert | Out-File  -FilePath .\$Hostgroup.txt -Append

"  " | Out-File -FilePath .\$Hostgroup.txt -Append
"Missing Software:" | Out-File -FilePath .\$Hostgroup.txt -Append
$UnknwonAlert  | Out-File  -FilePath .\$Hostgroup.txt -Append

"  " | Out-File -FilePath .\$Hostgroup.txt -Append
"WinRM Checks:" | Out-File -FilePath .\$Hostgroup.txt -Append

# Added on 2023-12-28
# Creates the TestPort function. Which allows for fast checks of WinRM ports

Function TestPort ()
{
    param(
    [Parameter(Mandatory = $true)] [string]$Hostname,
    [Parameter(Mandatory = $true)] [string]$Port
    )
    $timeout=900

    $requestCallback = $state = $null
    $client = New-Object System.Net.Sockets.TcpClient
    $client.BeginConnect($Hostname,$Port,$requestCallback,$state) | out-Null
    Start-Sleep -milli $timeOut
    if ($client.Connected) { $Status = "Open" } else { $Status = "Closed" }
    $client.Close()
    Write-Output $Hostname,$Status
}

# ForEach to check WinRM access
$Port = "5985"
$ServersupList = ($ServersUp).Split("|")

# Useful for testing purposes
#$ServersupList = $ServersupList | Where-Object {$_ -match "IWKSAPKPKIDDC01.prod.cloud|IWKSAPKPKIDDC02.prod.cloud"}

ForEach ($Server in $ServersupList)
{
TestPort $Server $Port
If ((TestPort $Server $Port) -Match "Closed") {"$Server WinRM Port Closed" | Out-File -FilePath .\$Hostgroup.txt -Append}
}

Explorer.exe .\$Hostgroup.txt

# OTHER USEFUL COMMANDS

<# This part of the script can be used to remove scheduled down time. It will remove downtime for servers powered up and down for all servers in the specified Host Group.
$ScheduledDowntimeJSON = Invoke-WebRequest -Method GET "http://${xiServer}/nagiosxi/api/v1/objects/downtime?apikey=${apiKey}&pretty=1"

$InternalID = ((ConvertFrom-Json ${ScheduledDowntimeJSON}.Content).scheduleddowntime | where-object host_name -Match $AllServers | Select-Object -ExpandProperty internal_id -ErrorAction SilentlyContinue)

ForEach ($ID in $InternalID) {

    Invoke-WebRequest -Uri "http://${xiServer}/nagiosxi/api/v1/system/scheduleddowntime/${ID}?apikey=${apiKey}&pretty=1" -UseBasicParsing -Method Delete
        
    }    

#>

<# This can be used to forace a check one the issues have been addressed.

 # Force immediate check for Hosts.
 Invoke-WebRequest -Uri "http://${xiServer}/nagiosxi/api/v1/system/corecommand?apikey=${apiKey}" -Method POST -Body `
 "cmd=SCHEDULE_FORCED_HOST_CHECK;${$ServersUp}" | select-object -ExpandProperty Content
 
 # Force immediate check for Services.
 Invoke-WebRequest -Uri "http://${xiServer}/nagiosxi/api/v1/system/corecommand?apikey=${apiKey}" -Method POST -Body `
 "cmd=SCHEDULE_FORCED_HOST_SVC_CHECKS;${$ServersUp}" | select-object -ExpandProperty Content

#>

