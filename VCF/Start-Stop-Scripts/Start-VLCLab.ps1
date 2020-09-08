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
$pHost = "esxi-1.vkernelblog.lan"
$Credentials = Get-Credential
##Components 
$InfraComponents = "fw-1", "dc-1"
$VCFNodes = "vcf-esxi-1", "vcf-esxi-2", "vcf-esxi-3", "vcf-esxi-4"
##Nested Components
$nHosts = "10.0.10.100", "10.0.10.101", "10.0.10.102", "10.0.10.103"
$SDDCComponents = "vcenter-mgmt", "nsx-mgmt-1", "sddc-manager"
$nHost_username = "root"
$nHost_password = "VMware123!"

##Connecting to physical host
try{
    Connect-VIServer -Server $pHost -Credential $Credentials -ErrorAction Stop
}catch{
    $ErrorMessage = $_.Exception.Message
    write-log -Value $ErrorMessage -ErrorType
}

##Starting InfraComponents
foreach($i in $InfraComponents){
    try{
        write-log -Value "Starting VM: $i"
        Start-VM -VM $i -ErrorAction Stop | Out-Null
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }
    do{
        try{
            write-log -Value "Checking if VMtools are up and running on VM: $i"
            $checkVMTools = (Wait-Tools -VM $i -ErrorAction Stop).PowerState
        }catch{
            $ErrorMessage = $_.Exception.Message
            write-log -Value $ErrorMessage -ErrorType
        }finally{
            if([string]::IsNullOrWhiteSpace($ErrorMessage)){
                write-log -Value "VM: $i is online!"
            }
            $ErrorMessage = $null
        }   
    }while ($checkVMTools -ne "PoweredOn")
}

##Starting VCFNodes.
foreach($v in $VCFNodes){
    try{
        write-log -Value "Starting VM: $v"
        Start-VM -VM $v -ErrorAction Stop | Out-Null
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }
}

##Checking if VMtool are up and running from the VCF nodes.
foreach($v in $VCFNodes){
    do{
        try{
            write-log -Value "Checking if VMtools are up and running on VM: $v"
            $checkVMTools = (Wait-Tools -VM $v -ErrorAction Stop).PowerState
        }catch{
            $ErrorMessage = $_.Exception.Message
            write-log -Value $ErrorMessage -ErrorType
        }finally{
            if([string]::IsNullOrWhiteSpace($ErrorMessage)){
                write-log -Value "VM: $v is online!"
            }
            $ErrorMessage = $null
        }   
    }while ($checkVMTools -ne "PoweredOn")
}


##Remove nested hosts out of maintenance mode!!!!!!------
foreach($n in $nHosts){
    try{
        Connect-VIServer -Server $pHost -Credential $Credentials -ErrorAction Stop
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }
    try{
        write-log -Value "Removing nested host: $n out of maintenance mode."
        Set-VMHost -VMHost $n -State Connected -ErrorAction Stop
        write-log -Value "Host $n is out of maintenance mode."
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }
    try{
        Disconnect-VIServer -Server * -Force -Confirm:$false
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-log -Value $ErrorMessage -ErrorType
    }
}

Start-Sleep -Seconds 10

foreach($Component in $SDDC_Components){
    foreach($h in $hosts){
        Connect-VIServer $h -User "root" -Password "VMware123!"
        if(Get-VM -Name $Component -ErrorAction SilentlyContinue){
            Start-VM -VM $Component
            Write-Host "$Component is started on $h." -ForegroundColor Green
        }
        Disconnect-VIServer -Server * -Force -Confirm:$false
    }
}

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');