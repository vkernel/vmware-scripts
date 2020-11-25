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
function Write-Log{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [switch]$ErrorType,
        [switch]$InfoType
    )
    
    $date = Get-Date -Format s 
    $fdate = Get-Date -Format dd-MM-yyyy

    $ScriptDirectory = $PSScriptRoot
    if((Test-Path -Path $ScriptDirectory\logs) -like "False"){
        New-Item -ItemType Directory -Path "$ScriptDirectory\Logs" | Out-Null
    }
    $LogFile = "$ScriptDirectory\logs\$fdate-Stop-VLCLab.log"

    if($verboseLogging -eq $true){
        if($ErrorType){
        Write-Host "$date - ERROR: $Value" -ForegroundColor Red
        Out-File -InputObject "$date - ERROR: $Value" -FilePath $LogFile -Append 
        }
        elseif($InfoType){
            Write-Host "$date - INFO: $Value" -ForegroundColor White
            Out-File -InputObject "$date - INFO: $Value"  -FilePath $LogFile -Append 
        }
        else{
            Write-Host "$date - INFO: $Value" -ForegroundColor Green
            Out-File -InputObject "$date - INFO: $Value"  -FilePath $LogFile -Append 
        }
    }else{
        if($ErrorType){
            Write-Host "$date - ERROR: $Value" -ForegroundColor Red
            Out-File -InputObject "$date - ERROR: $Value" -FilePath $LogFile -Append 
        }
        elseif($InfoType){
            #nothing to log
        }else{
            Write-Host "$date - INFO: $Value" -ForegroundColor Green
            Out-File -InputObject "$date - INFO: $Value"  -FilePath $LogFile -Append 
        }
    } 
}

##Settings
$begintime = Get-Date
$verboseLogging = $false  #$true or $false
$vCLS = $true  #$true or $false
##Physical ESXI host or vCenter server settings
$pHost = "esxi-1.lab.vkb.lan"
$pCredentials = Get-Credential -Message "Enter the credentials of the physical ESXI host or vCenter server."
##Nested hosts
$nHosts = @(
        [PSCustomObject]@{Name = "vcf-esxi-1"; IP = "192.168.11.27"}
        [PSCustomObject]@{Name = "vcf-esxi-2"; IP = "192.168.11.28"}
        [PSCustomObject]@{Name = "vcf-esxi-3"; IP = "192.168.11.29"}
        [PSCustomObject]@{Name = "vcf-esxi-4"; IP = "192.168.11.30"}
        [PSCustomObject]@{Name = "vcf-esxi-5"; IP = "192.168.11.31"}
        [PSCustomObject]@{Name = "vcf-esxi-6"; IP = "192.168.11.32"}
)
$nUser = "root"
$nPassword = "VMware1!VKB!"
$nCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $nUser, (ConvertTo-SecureString -String $nPassword -AsPlainText -Force)
##VCF Components (VM names of the components)
$VCF_Components = "vcenter-mgmt", "nsx-mgmt-1", "sddc-manager", "edge01-mgmt", "edge02-mgmt"

try{
    Write-Log -Value "Starting Stop-VLCLab.ps1 script..."
    If($verboseLogging -eq $true){
        Write-Log -Value "Verbose logging enabled."
    }

    ##Stoping VCF Components
    foreach($Component in $VCF_Components){
        foreach($n in $nHosts){
            $nHostName = $n.Name
            $nHostIP = $n.IP
            Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
            Write-Log -Value "Connected to nested ESXI host: $nHostName" -InfoType
            if(Get-VM -Name $Component -ErrorAction SilentlyContinue | Where-Object{$_.PowerState -like "PoweredOn"}){
                Shutdown-VMGuest -VM $Component -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                Write-Log -Value "$Component is powered off on nested ESXI host: $nHostName." 
            }else{
                Write-Log -Value "$Component is not available on ESXI host: $nHostName." -InfoType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            Write-Log -Value "Disconnected from nested ESXI host: $nHostName" -InfoType
        }
    }

    ##Stoping vCLS
    if($vCLS -eq $true){
        foreach($n in $nHosts){
            $nHostName = $n.Name
            $nHostIP = $n.IP
            Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
            Write-Log -Value "Connected to nested ESXI host: $nHostName" -InfoType
            $vCLSnodes = Get-VM | Where-Object{$_.Name -like "vCLS*"}
            foreach($vCLSnode in $vCLSnodes){
                if(Get-VM -Name $vCLSnode -ErrorAction SilentlyContinue | Where-Object{$_.PowerState -like "PoweredOn"}){
                Shutdown-VMGuest -VM $vCLSnode -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                Write-Log -Value "$vCLSnode is powered off on nested ESXI host: $nHostName." 
                }elseif(Get-VM -Name $vCLSnode -ErrorAction SilentlyContinue | Where-Object{$_.PowerState -like "PoweredOff"}){
                    Write-Log -Value "$vCLSnode is already powered off on nested ESXI host: $nHostName." -InfoType
                }else{
                    Write-Log -Value "$vCLSnode is not available on nested ESXI host: $nHostName." -InfoType
                }
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            Write-Log -Value "Disconnected from nested ESXI host: $nHostName" -InfoType
        }
    }else{
        Write-Log -Value "vCLS switch is not enabled in the setings." -InfoType
    }

    ##Checking if the VCF Components are powered off
    foreach($Component in $VCF_Components){
        foreach($n in $nHosts){
            $nHostName = $n.Name
            $nHostIP = $n.IP
            Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
            Write-Log -Value "Connected to nested ESXI host: $nHostName" -InfoType
            if(Get-VM -Name $Component -ErrorAction SilentlyContinue){
                Write-Log -Value "Checking powerstate of VCF component: $Component"
                do{
                    $checkComponent = (Get-VM -Name $Component).PowerState 
                }while ($checkComponent -ne "PoweredOff")
                Write-Log -Value "Powerstate is PoweredOff for VCF component: $Component." 
            }else{
                Write-Log -Value "VCF componenten: $Component is not available on nested ESXI host: $nHostName." -InfoType
            }
            Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
            Write-Log -Value "Disconnected from nested ESXI host: $nHostName" -InfoType
        }
    }

    ##Put nested hosts in maintenace mode
    foreach($n in $nHosts){
        $nHostName = $n.Name
        $nHostIP = $n.IP
        Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop | Out-Null
        Write-Log -Value "Connected to nested ESXI host: $nHostName" -InfoType
        if((Get-VMHost -Name $nHostIP -ErrorAction SilentlyContinue).ConnectionState -eq "Connected"){
            Set-VMHost -VMHost $nHostIP -State "Maintenance" -VsanDataMigrationMode NoDataMigration -ErrorAction Stop| Out-Null
            Write-Log -Value "Nested ESXI host: $nHostName has been put in maintenance mode!" 
        }
        Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
        Write-Log -Value "Disconnected from nested ESXI host: $nHostName" -InfoType
    }

    ##Poweroff nested hosts
    foreach($n in $nHosts){
        $nHostName = $n.Name
        $nHostIP = $n.IP
        Connect-VIServer $nHostIP -Credential $nCredentials -ErrorAction Stop| Out-Null
        Write-Log -Value "Connected to nested ESXI host: $nHostName" -InfoType
        Stop-VMHost -VMHost $nHostIP -Confirm:$false -ErrorAction Stop | Out-Null
        Write-Log -Value "Powered off nested ESXI host: $nHostName!" 
        Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
        Write-Log -Value "Disconnected from nested ESXI host: $nHostName" -InfoType
    }
}catch{
    $ErrorMessage = $_.Exception.Message
    Write-Log -Value $ErrorMessage -ErrorType
}

$endtime = Get-Date
$ElapsedTime = New-TimeSpan –Start $begintime –End $endtime 
$ElapsedTimeOutput = 'Duration: {0:mm} min {0:ss} sec' -f $ElapsedTime
Write-Log -Value "$ElapsedTimeOutput" 

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');