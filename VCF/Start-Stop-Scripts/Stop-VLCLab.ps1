<#
 * Created on Tue Sep 08 2020
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 DAngelo Karijopawiro
 * Website: https://vkernelblog.com
 * GitHub: https://github.com/vkernelblog
 * File: Stop-VLCLab.ps1
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
function write-log{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [switch]$ErrorType,
        [switch]$WarningType,
        [switch]$Succeeded
    )
    
    $date = Get-Date -Format s 
    $fdate = Get-Date -Format dd-mm-yyyy

    $ScriptDirectory = $PSScriptRoot
    if((Test-Path -Path $ScriptDirectory\logs) -like "False"){
        New-Item -ItemType Directory -Path "$ScriptDirectory\Logs" | Out-Null
    }
    $LogFile = "$ScriptDirectory\logs\$fdate-Stop-VLCLab.log"

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

$begintime = Get-Date -Format HH:mm
##Physical ESXI host Settings
$pHost = "esxi-1.vkernelblog.lan"
$Credentials = Get-Credential -Message "Enter the credentials of the physical ESXI host."
##Nested Components
$nHosts  = "10.0.10.100", "10.0.10.101", "10.0.10.102", "10.0.10.103"
$nHost_username = "root"
$nHost_password = "VMware123!"
$nHost_Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $nHost_username,(ConvertTo-SecureString -AsPlainText $nHost_password -Force)
$SDDC_Components = "vcenter-mgmt", "nsx-mgmt-1", "sddc-manager"
##Components start order is: firewall first and DC second. 
$InfraComponents = "dc-1", "fw-1"

try{
    ##Stoping VCF Components
    foreach($Component in $SDDC_Components){
        foreach($n in $nHosts){
            Connect-VIServer $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
            write-log -Value "Connected to $n"
            if(Get-VM -Name $Component -ErrorAction SilentlyContinue){
                Shutdown-VMGuest -VM $Component -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                write-log -Value "$Component is powered off on ESXI host:  $n." -Succeeded
            }else{
                write-log -Value "$Component is not available on ESXI host: $n." -WarningType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            write-log -Value "Disconnected from nested host: $n"
        }
    }

    ##Checking if the VCF Components are powered off
    foreach($Component in $SDDC_Components){
        foreach($n in $nHosts){
            Connect-VIServer $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
            write-log -Value "Connected to $n"
            if(Get-VM -Name $Component -ErrorAction SilentlyContinue){
                write-log -Value "Checking powerstate of component: $Component"
                do{
                    $checkComponent = (Get-VM -Name $Component).PowerState 
                }while ($checkComponent -ne "PoweredOff")
                write-log -Value "The powerstate of component: $Component is PoweredOff." -Succeeded
            }else{
                write-log -Value "$Component is not available on ESXI host: $n." -WarningType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            write-log -Value "Disconnected from nested host: $n"
        }
    }

    ##Put nested hosts in maintenace mode
    foreach($n in $nHosts){
        Connect-VIServer $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
        write-log -Value "Connected to nested host: $n"
        if((Get-VMHost -Name $n -ErrorAction SilentlyContinue).ConnectionState -eq "Connected"){
            Set-VMHost -VMHost $n -State "Maintenance" -VsanDataMigrationMode NoDataMigration -ErrorAction Stop| Out-Null
            write-log -Value "Nested host: $n has been put in maintenance mode!" -Succeeded
        }else{
            write-log -Value "Nested host: $n was already in maintenace mode!"  -WarningType
        }
        Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
        write-log -Value "Disconnected from nested host: $n"
    }

    ##Poweroff nested hosts
    foreach($n in $nHosts){
        Connect-VIServer $n -User "root" -Password "VMware123!" | Out-Null
        Stop-VMHost -VMHost $n -Confirm:$false -ErrorAction Stop | Out-Null
        write-log -Value "Powered off nested host: $n!" -Succeeded
        Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
        write-log -Value "Disonnected from nested host: $n." 
    }

    ##Stoping Infra Components
    foreach($i in $InfraComponents){
            Connect-VIServer $pHost -Credential $Credentials -ErrorAction Stop | Out-Null
            write-log -Value "Connected to $n"
            if(Get-VM -Name $i -ErrorAction SilentlyContinue){
                Shutdown-VMGuest -VM $i -Confirm:$false -ErrorAction Stop | Out-Null
                write-log -Value "$i is powered off on ESXI host:  $n." -Succeeded
            }else{
                write-log -Value "$i is not available on ESXI host: $n." -WarningType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            write-log -Value "Disconnected from nested host: $n"
    }
}catch{
    $ErrorMessage = $_.Exception.Message
    write-log -Value $ErrorMessage -ErrorType
}

$endtime = Get-Date -Format HH:mm
$ElapsedTime = New-TimeSpan –Start $begintime –End $endtime 
$ElapsedTimeOutput = 'Duration: {0:mm} min {0:ss} sec' -f $ElapsedTime
write-log -Value "$ElapsedTimeOutput" -Succeeded

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');