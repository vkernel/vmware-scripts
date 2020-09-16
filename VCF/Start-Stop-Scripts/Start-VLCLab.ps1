<#
 * Created on Tue Sep 08 2020
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 DAngelo Karijopawiro
 * Website: https://vkernelblog.com
 * GitHub: https://github.com/vkernelblog
 * File: Start-VLCLab.ps1
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
    $LogFile = "$ScriptDirectory\logs\$fdate-Start-VLCLab.log"

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

$begintime = Get-Date 
##Physical ESXI host Settings
$pHost = "esxi-1.vkernelblog.lan"
$Credentials = Get-Credential -Message "Enter the credentials of the physical ESXI host."
##Components start order is: firewall first and DC second. 
$InfraComponents = "fw-1", "dc-1"
$VCFNodes = "vcf-esxi-1", "vcf-esxi-2", "vcf-esxi-3", "vcf-esxi-4"
##Nested Components
$nHosts = "10.0.10.100", "10.0.10.101", "10.0.10.102", "10.0.10.103"
$SDDC_Components = "vcenter-mgmt", "nsx-mgmt-1", "sddc-manager", "edge01-mgmt", "edge02-mgmt"
$nHost_username = "root"
$nHost_password = "VMware123!"
$nHost_Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $nHost_username,(ConvertTo-SecureString -AsPlainText $nHost_password -Force)


try{
    ##Connecting to physical host
    Connect-VIServer -Server $pHost -Credential $Credentials -ErrorAction Stop | Out-Null
    write-log -Value "Connected to $pHost"

    ##Starting InfraComponents
    foreach($i in $InfraComponents){
        write-log -Value "Starting VM: $i"
        Start-VM -VM $i -ErrorAction Stop | Out-Null
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
        do{
            write-log -Value "Checking if VMtools are up and running on VM: $i"
            $checkVMTools = (Wait-Tools -VM $i -ErrorAction Stop).PowerState 
            write-log -Value "VM: $i is online!" -Succeeded
        }while ($checkVMTools -ne "PoweredOn")
    }

    ##Starting VCFNodes.
    foreach($v in $VCFNodes){
    write-log -Value "Starting Nested ESXI node: $v"
    Start-VM -VM $v -ErrorAction Stop | Out-Null
    }

    ##Checking if VMtool are up and running from the VCF nodes.
    foreach($v in $VCFNodes){
        do{
            write-log -Value "Checking if VMtools are up and running on VM: $v"
            $checkVMTools = (Wait-Tools -VM $v -ErrorAction Stop).PowerState
            write-log -Value "VM: $v is online!" -Succeeded
        }while ($checkVMTools -ne "PoweredOn")
    }

    ##Disconnecting from physical host
    Disconnect-VIServer -Server * -Confirm:$false -ErrorAction Stop | Out-Null
    write-log -Value "Disconnected from $pHost"

    ##Remove nested hosts out of maintenance mode
    foreach($n in $nHosts){
        Connect-VIServer -Server $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
        write-log -Value "Connected to $n"
        write-log -Value "Removing nested host: $n out of maintenance mode."
        Set-VMHost -VMHost $n -State Connected -ErrorAction Stop | Out-Null
        write-log -Value "Host $n is out of maintenance mode." -Succeeded
        Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction Stop | Out-Null
        write-log -Value "Disconnected from $n"
    }

    Start-Sleep -Seconds 10

    ##Starting VCF Components
    foreach($Component in $SDDC_Components){
        foreach($n in $nHosts){
            Connect-VIServer $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
            write-log -Value "Connected to $n"
            if(Get-VM -Name $Component -ErrorAction SilentlyContinue){
                Start-VM -VM $Component -ErrorAction Stop | Out-Null
                write-log -Value "$Component is started on ESXI host:  $n." -Succeeded
            }else{
                write-log -Value "$Component is not available on ESXI host: $n." -WarningType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction Stop
            write-log -Value "Disconnected from $n"
        }
    }
}catch{
    $ErrorMessage = $_.Exception.Message
    write-log -Value $ErrorMessage -ErrorType
}


$endtime = Get-Date
$ElapsedTime = New-TimeSpan –Start $begintime –End $endtime 
$ElapsedTimeOutput = 'Duration: {0:mm} min {0:ss} sec' -f $ElapsedTime
write-log -Value "$ElapsedTimeOutput" -Succeeded

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');