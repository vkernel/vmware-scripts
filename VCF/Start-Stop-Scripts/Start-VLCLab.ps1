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
        [string]$nalue,
        [switch]$ErrorType,
        [switch]$WarningType,
        [switch]$Succeeded
    )
    
    $date = Get-Date -Format s 
    $fdate = Get-Date -Format dd-MM-yyyy

    $ScriptDirectory = $PSScriptRoot
    if((Test-Path -Path $ScriptDirectory\logs) -like "False"){
        New-Item -ItemType Directory -Path "$ScriptDirectory\Logs" | Out-Null
    }
    $LogFile = "$ScriptDirectory\logs\$fdate-Start-VLCLab.log"

    if($ErrorType){
        Write-Host "$date - $nalue" -ForegroundColor Red
        Out-File -InputObject "$date - $nalue" -FilePath $LogFile -Append 
    }
    elseif($WarningType){
        Write-Host "$date - $nalue"  -ForegroundColor Yellow
        Out-File -InputObject "$date - $nalue"  -FilePath $LogFile -Append 
    }
    elseif($Succeeded){
        Write-Host "$date - $nalue"  -ForegroundColor Green
        Out-File -InputObject "$date - $nalue"  -FilePath $LogFile -Append
    }
    else{
        Write-Host "$date - $nalue" 
        Out-File -InputObject "$date - $nalue"  -FilePath $LogFile -Append 
    }
    
}

$begintime = Get-Date 
##Physical ESXI host Settings
$pHost = "alm-esx02.vkb.lan"
$pCredentials = Get-Credential -Message "Enter the credentials of the physical ESXI host."
##Nested Components
$nHosts = @(
        [PSCustomObject]@{Name = "vcf-esxi-1"; IP = "192.168.33.25"}
        [PSCustomObject]@{Name = "vcf-esxi-2"; IP = "192.168.33.26"}
        [PSCustomObject]@{Name = "vcf-esxi-3"; IP = "192.168.33.27"}
        [PSCustomObject]@{Name = "vcf-esxi-4"; IP = "192.168.33.28"}
        [PSCustomObject]@{Name = "vcf-esxi-5"; IP = "192.168.33.29"}
        [PSCustomObject]@{Name = "vcf-esxi-6"; IP = "192.168.33.30"}
)
$nCredentials = Get-Credential -Message "Enter the credentials of the nested ESXI hosts."
$SDDC_Components = "vcenter-mgmt", "nsx-mgmt-1", "sddc-manager", "edge01-mgmt", "edge02-mgmt"



try{
    ##Connecting to physical host
    Connect-VIServer -Server $pHost -Credential $pCredentials -ErrorAction Stop | Out-Null
    write-log -Value "Connected to $pHost"

    ##Starting VCFNodes.
    foreach($n in $nHosts){
    $nHostName = $n.Name
    write-log -Value "Starting Nested ESXI node: $nHostName"
    Start-VM -VM $nHostName -ErrorAction Stop | Out-Null
    }

    ##Checking if VMtool are up and running from the VCF nodes.
    foreach($n in $nHosts){
        $nHostName = $n.Name
        do{
            write-log -Value "Checking if VMtools are up and running on VM: $nHostName"
            $checkVMTools = (Wait-Tools -VM $nHostName -ErrorAction Stop).PowerState
            write-log -Value "VM: $nHostName is online!" -Succeeded
        }while ($checkVMTools -ne "PoweredOn")
    }

    ##Disconnecting from physical host
    Disconnect-VIServer -Server * -Confirm:$false -ErrorAction Stop | Out-Null
    write-log -Value "Disconnected from $pHost"

    ##Remove nested hosts out of maintenance mode
    foreach($n in $nHosts){
        $nHostName = $n.Name
        $nHostIP = $n.IP
        Connect-VIServer -Server $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
        write-log -Value "Connected to $nHostName"
        write-log -Value "Removing nested host: $nHostName out of maintenance mode."
        Set-VMHost -VMHost $nHostIP -State Connected -ErrorAction Stop | Out-Null
        write-log -Value "Host $nHostName is out of maintenance mode." -Succeeded
        Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction Stop | Out-Null
        write-log -Value "Disconnected from $nHostName"
    }

    Start-Sleep -Seconds 10

    ##Starting VCF Components
    foreach($Component in $SDDC_Components){
        foreach($n in $nHosts){
            $nHostName = $n.Name
            $nHostIP = $n.IP
            Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
            write-log -Value "Connected to $nHostName"
            if(Get-VM -Name $Component -ErrorAction SilentlyContinue){
                Start-VM -VM $Component -ErrorAction Stop | Out-Null
                write-log -Value "$Component is started on ESXI host:  $nHostName." -Succeeded
            }else{
                write-log -Value "$Component is not available on ESXI host: $nHostName." -WarningType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction Stop
            write-log -Value "Disconnected from $nHostName"
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