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
    $fdate = Get-Date -Format dd-MM-yyyy

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

$begintime = Get-Date 
##Physical ESXI host Settings
$pHost = "alm-esx02.vkb.lan"
$Credentials = Get-Credential -Message "Enter the credentials of the physical ESXI host."
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
$vCLS = $true


try{
    ##Stoping vCLS
    if($vCLS -eq $true){
        foreach($n in $nHosts){
            $nHostName = $n.Name
            $nHostIP = $n.IP
            Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
            write-log -Value "Connected to $nHostName"
            $vCLSnodes = Get-VM | Where-Object{$_.Name -like "vCLS*"}
            foreach($vCLSnode in $vCLSnodes){
                if(Get-VM -Name $vCLSnode -ErrorAction SilentlyContinue | Where-Object{$_.PowerState -like "PoweredOn"}){
                Shutdown-VMGuest -VM $vCLSnode -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                write-log -Value "$vCLSnode is powered off on ESXI host:  $nHostName." -Succeeded
                }elseif(Get-VM -Name $vCLSnode -ErrorAction SilentlyContinue | Where-Object{$_.PowerState -like "PoweredOff"}){
                    write-log -Value "$vCLSnode is already powered off on ESXI host: $nHostName." -WarningType
                }else{
                    write-log -Value "$vCLSnode is not available on ESXI host: $nHostName." -WarningType
                }
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            write-log -Value "Disconnected from nested host: $nHostName"
        }
    }else{
        write-log -Value "vCLS switch is turned off in the configuration." -WarningType
    }

    ##Stoping VCF Components
    foreach($Component in $SDDC_Components){
        foreach($n in $nHosts){
            $nHostName = $n.Name
            $nHostIP = $n.IP
            Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
            write-log -Value "Connected to $nHostName"
            if(Get-VM -Name $Component -ErrorAction SilentlyContinue | Where-Object{$_.PowerState -like "PoweredOn"}){
                Shutdown-VMGuest -VM $Component -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                write-log -Value "$Component is powered off on ESXI host: $nHostName." -Succeeded
            }else{
                write-log -Value "$Component is not available on ESXI host: $nHostName." -WarningType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            write-log -Value "Disconnected from nested host: $nHostName"
        }
    }

    ##Checking if the VCF Components are powered off
    foreach($Component in $SDDC_Components){
        foreach($n in $nHosts){
            $nHostName = $n.Name
            $nHostIP = $n.IP
            Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
            write-log -Value "Connected to $nHostName"
            if(Get-VM -Name $Component -ErrorAction SilentlyContinue){
                write-log -Value "Checking powerstate of component: $Component"
                do{
                    $checkComponent = (Get-VM -Name $Component).PowerState 
                }while ($checkComponent -ne "PoweredOff")
                write-log -Value "The powerstate of component: $Component is PoweredOff." -Succeeded
            }else{
                write-log -Value "$Component is not available on ESXI host: $nHostName." -WarningType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            write-log -Value "Disconnected from nested host: $nHostName"
        }
    }

    ##Put nested hosts in maintenace mode
    foreach($n in $nHosts){
        $nHostName = $n.Name
        $nHostIP = $n.IP
        Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
        write-log -Value "Connected to nested host: $n"
        if((Get-VMHost -Name $nHostIP -ErrorAction SilentlyContinue).ConnectionState -eq "Connected"){
            Set-VMHost -VMHost $nHostIP -State "Maintenance" -VsanDataMigrationMode NoDataMigration -ErrorAction Stop| Out-Null
            write-log -Value "Nested host: $nHostName has been put in maintenance mode!" -Succeeded
        }else{
            write-log -Value "Nested host: $nHostName was already in maintenace mode!"  -WarningType
        }
        Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
        write-log -Value "Disconnected from nested host: $nHostName"
    }

    ##Poweroff nested hosts
    foreach($n in $nHosts){
        $nHostName = $n.Name
        $nHostIP = $n.IP
        Connect-VIServer $nHostIP -Credential $nCredentials | Out-Null
        Stop-VMHost -VMHost $nHostIP -Confirm:$false -ErrorAction Stop | Out-Null
        write-log -Value "Powered off nested host: $nHostName!" -Succeeded
        Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
        write-log -Value "Disonnected from nested host: $nHostName." 
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