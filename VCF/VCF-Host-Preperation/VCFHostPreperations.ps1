<#
 * Created on Tue Sep 08 2020
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 DAngelo Karijopawiro
 * Website: https://vkernelblog.com
 * GitHub: https://github.com/vkernelblog
 * File: VCFHostPreperations.ps1
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
 * TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>


$ServerArray = @(
        [PSCustomObject]@{Name = "vlvm2001"; IP = "10.16.11.1"}
        [PSCustomObject]@{Name = "vlvm2003"; IP = "10.16.11.2"}
        [PSCustomObject]@{Name = "vlvm2005"; IP = "10.16.11.3"}
        [PSCustomObject]@{Name = "vlvm2007"; IP = "10.16.11.4"}
        [PSCustomObject]@{Name = "vlvm2009"; IP = "10.16.11.5"}
        [PSCustomObject]@{Name = "vlvm2002"; IP = "10.16.21.1"}
        [PSCustomObject]@{Name = "vlvm2004"; IP = "10.16.21.2"}
        [PSCustomObject]@{Name = "vlvm2006"; IP = "10.16.21.3"}
        [PSCustomObject]@{Name = "vlvm2008"; IP = "10.16.21.4"}
        [PSCustomObject]@{Name = "vlvm2010"; IP = "10.16.21.5"}
)

function write-log{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [switch]$ErrorType,
        [switch]$WarningType,
        [switch]$Succeeded
    )
    
    $date = Get-Date -Format s 
    $fdate = Get-Date -Format dd-mm-yyyy-HH-mm

    $ScriptDirectory = $PSScriptRoot
    if((Test-Path -Path $ScriptDirectory\logs) -like "False"){
        New-Item -ItemType Directory -Path "$ScriptDirectory\Logs" | Out-Null
    }
    $LogFile = "$ScriptDirectory\logs\$fdate-output.log"

    if($ErrorType){
        Write-Host "$date - $Value" -ForegroundColor Red
        Out-File -InputObject "$date - $Value" -FilePath $LogFile -Append 
    }
    elseif($WarningType){
        Write-Host "$date - $Value"  -ForegroundColor Yellow
        Out-File -InputObject "$date - $Value"  -FilePath $LogFile -Append 
    }
    elseif($Succeeded){
        Write-Host "$date - $Value"  -ForegroundColor Green
        Out-File -InputObject "$date - $Value"  -FilePath $LogFile -Append
    }
    else{
        Write-Host "$date - $Value" 
        Out-File -InputObject "$date - $Value"  -FilePath $LogFile -Append 
    }
    
}

##Settings
$ESXICredentails = Get-Credential -Message "Enter the credentials for the ESXI root user." 
$DNSPrimary = "10.16.2.1"
$DNSSecondary = "10.16.2.2" 
$NTP = "ntp.vanleeuwen.com"
$domainname = "vanleeuwen.com"

foreach($a in $ServerArray){
    $hostname = $a.Name
    $fqdn = $hostname+$domainname

    ##Connect to ESXI host.
    try{
        Connect-VIServer -Server $a.IP -Credential $ESXICredentails -ErrorAction Stop | Out-Null
        write-log -Value "Connected to $fqdn"
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }

    ##Configure FQDN and DNS servers
    try{
        $VMHostNetwork = Get-VMHostNetwork -VMHost $a.IP -ErrorAction Stop
        $VMHostNetwork | Set-VMHostNetwork -DnsAddress $DNSPrimary, $DNSSecondary -ErrorAction Stop | Out-Null
        write-log -Value "Configured the following DNS servers: '$DNSPrimary,$DNSSecondary' on ESXI host: $fqdn"
        $VMHostNetwork | Set-VMHostNetwork -HostName $hostname -ErrorAction Stop | Out-Null
        write-log -Value "Configured the following hostname: '$hostname' on ESXI host: $fqdn"
        $VMHostNetwork | Set-VMHostNetwork -DomainName $domainname -ErrorAction Stop | Out-Null
        write-log -Value "Configured the following domain: '$domainname' on ESXI host: $fqdn"
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }

    ##Enabling SSH service
    try{
        $VMHostNetwork = Get-VMHostNetwork -VMHost $a.IP -ErrorAction Stop
        $sshService = Get-VMHostService -VMHost $a.IP -ErrorAction Stop | Where-Object{$_.key -eq "TSM-SSH"}
        $sshService | Set-VMHostService -Policy "on" -ErrorAction Stop | Out-Null
        write-log -Value "Configured TSM-SSH policy: 'Start and stop with host' on ESXI host: $fqdn"
        $sshService | Restart-VMHostService -Confirm:$false -ErrorAction Stop | Out-Null
        write-log -Value "Restarted VMHost service: 'TSM-SSH' on ESXI host: $fqdn"
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }

    ##Configure NTP server
    try{
        Add-VMHostNtpServer -VMHost $a.IP -NtpServer $NTP -ErrorAction Stop | Out-Null
        write-log -Value "Configured the following NTP server: $NTP on ESXI host: $fqdn"
        $ntpService = Get-VMHostService -VMHost $a.IP -ErrorAction Stop | Where-Object{$_.key -eq "ntpd"}
        $ntpService | Set-VMHostService -Policy "on" -ErrorAction Stop | Out-Null
        write-log -Value "Configured NTP policy: 'Start and stop with host' on ESXI host: $fqdn"
        $ntpService | Restart-VMHostService -Confirm:$false -ErrorAction Stop | Out-Null
        write-log -Value "Restarted VMHost service: 'ntpd' on ESXI host: $fqdn"
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }

    ##disconnecting from ESXI Host
    try{
        disconnect-VIServer -Server * -Confirm:$false -ErrorAction Stop | Out-Null
        write-log -Value "Disconnected from $fqdn"
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }
}

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');