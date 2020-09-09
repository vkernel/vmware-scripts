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

$nHosts  = "10.0.10.100", "10.0.10.101", "10.0.10.102", "10.0.10.103"
$vCenterFQDN = "vcenter-mgmt.vkernelblog.net"
$vCenter_Credentials = Get-Credential -Message "Enter the credentials for the nested vCenter."  
$vCenterVM = "vcenter-mgmt"
$nHost_username = "root"
$nHost_password = "VMware123!"
$nHost_Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $nHost_username,(ConvertTo-SecureString -AsPlainText $nHost_password -Force)

try{
    Connect-VIServer -Server $vCenterFQDN -Credential $vCenter_Credentials -ErrorAction Stop | Out-Null
    write-log -Value "Connected to $vCenterFQDN"

    ##Shutdown all the VMs except vCenter
    $VMs = Get-VM -ErrorAction Stop| Where-Object{($_.Name -notlike "vcenter-mgmt") -and ($_.PowerState -like "PoweredOn")} | Sort-Object guestid -Descending
    foreach($VM in $VMs){
        Shutdown-VMGuest -VM $VM -Confirm:$false -ErrorAction Stop | Out-Null
    }

    ##Check if all VMs besides vCenter are powered off.
    foreach($VM in $VMs){
        Do
        { 
            $check = Get-VM -Name $VM -ErrorAction Stop 
            $VMname = $check.name 
            if($check.PowerState -like "PoweredOn"){
                write-log -Value "The following VM is still powered on: $VMname"
                start-Sleep -Seconds 5
            }
            else{
                write-log -Value "The following VM is powered off: $VMname" 
            }
        } 
          while($check.PowerState -ne "PoweredOff") 
    }

    Shutdown-VMGuest -VM $vCenterVM -Confirm:$false -ErrorAction Stop | Out-Null
    write-log -Value "Powered off VM: $vCenterVM."
    Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

    ##Shutdown vCenter Server.
    foreach($n in $nHosts){
        Connect-VIServer $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
        write-log -Value "Connected to nested host: $n"
        $check = Get-VM -Name $vCenterVM -ErrorAction SilentlyContinue
            if ($check){
                Do
                { 
                    $check2 = Get-VM -Name $vCenterVM -ErrorAction SilentlyContinue
                    $VMname = $check2.name 
                    if($check2.PowerState -like "PoweredOn"){
                        write-log -Value "The following VM: $VMname is still powered on host: $n" 
                        start-Sleep -Seconds 5
                    }
                    else{
                        write-log -Value "The following VM: $VMname is powered off on host: $n" 
                        }
                    } 
                    while($check2.PowerState -ne "PoweredOff") 
            }else{
                write-log -Value "vCenter doesn't run on host:" $n 
            }
            
    }
  
    Start-Sleep -Seconds 10
    write-log -Value "Waiting for 10 seconds"

    ##Put nested hosts in maintenace mode
    foreach($n in $nHosts){
        Connect-VIServer $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
        write-log -Value "Connected to nested host: $n"
        if((Get-VMHost -Name $n -ErrorAction SilentlyContinue).ConnectionState -eq "Connected"){
            Set-VMHost -VMHost $n -State "Maintenance" -VsanDataMigrationMode NoDataMigration | Out-Null
            write-log -Value "Nested host: $n has been put in maintenance mode!"
        }else{
            write-log -Value "Nested host: $n was already in maintenace mode!" 
        }
        Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
        write-log -Value "Disconnected from nested host: $n"
    }

    ##Poweroff nested hosts
    foreach($n in $nHosts){
        Connect-VIServer $n -User "root" -Password "VMware123!" | Out-Null
        Stop-VMHost -VMHost $n -Confirm:$false | Out-Null
        write-log -Value "Powered off nested host: $n!" 
        Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
        write-log -Value "Disonnected from nested host: $n." 
    }
}catch{
    $ErrorMessage = $_.Exception.Message
    write-log -Value $ErrorMessage -ErrorType
}
   
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');