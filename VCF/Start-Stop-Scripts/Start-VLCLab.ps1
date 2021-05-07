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
    $LogFile = "$ScriptDirectory\logs\$fdate-Start-VLCLab.log"

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
##Physical ESXI host or vCenter server settings
$pHost = "esxi-1.lab.vkb.lan"
$pCredentials = Get-Credential -Message "Enter the credentials of the physical ESXI host or vCenter server."
##Nested ESXI hosts
$nHosts = @(
        [PSCustomObject]@{Name = "vcf-esxi-1"; IP = "192.168.11.27"}
        [PSCustomObject]@{Name = "vcf-esxi-2"; IP = "192.168.11.28"}
        [PSCustomObject]@{Name = "vcf-esxi-3"; IP = "192.168.11.29"}
        [PSCustomObject]@{Name = "vcf-esxi-4"; IP = "192.168.11.30"}
        [PSCustomObject]@{Name = "vcf-esxi-5"; IP = "192.168.11.31"}
        [PSCustomObject]@{Name = "vcf-esxi-6"; IP = "192.168.11.32"}
)
$nUser = "root"
$nPassword = "VMware1!VMware1!"
$nCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $nUser, (ConvertTo-SecureString -String $nPassword -AsPlainText -Force)
##VCF Components (VM names of the VCF components)
$VCF_Components = "vcenter-mgmt", "nsx-mgmt-1", "sddc-manager", "edge01-mgmt", "edge02-mgmt"

try{
    Write-Log -Value "Starting Start-VLCLab.ps1 script..."
    If($verboseLogging -eq $true){
        Write-Log -Value "Verbose logging enabled."
    }

    ##Connecting to physical host
    $viserver = Connect-VIServer -Server $pHost -Credential $pCredentials -ErrorAction Stop
    Write-Log -Value "Connected to physical ESXI host: $pHost" 

    ##Starting VCFNodes.
    foreach($n in $nHosts){
        $nHostName = $n.Name
        Start-VM -Server $viserver -VM $nHostName -ErrorAction Stop | Out-Null
        Write-Log -Value "Started nested ESXI host: $nHostName" 
    }

    ##Checking if VMtool are up and running from the VCF nodes.
    foreach($n in $nHosts){
        $nHostName = $n.Name
        do{
            Write-Log -Value "Checking VMtools status on nested ESXI host: $nHostName"
            $checkVMTools = (Wait-Tools -Server $viserver -VM $nHostName -ErrorAction Stop).PowerState
            Write-Log -Value "VMtools are running on nested ESXI host: $nHostName" 
        }while ($checkVMTools -ne "PoweredOn")
    }

    ##Disconnecting from physical host
    Disconnect-VIServer -Server $viserver -Confirm:$false -ErrorAction Stop | Out-Null
    Write-Log -Value "Disconnected from physical ESXI host: $pHost"

	##Connect to nested hosts
	$nServers = [System.Collections.Arraylist]@()
    foreach($n in $nHosts){
        $nServer = Connect-VIServer -Server ($n.IP) -Credential $nCredentials -ErrorAction Stop
		[void]$nServers.Add($nServer)
        Write-Log -Value "Connected to nested ESXI host: $($n.Name)" -InfoType
	}
	
    ##Remove nested hosts out of maintenance mode
    foreach($n in $nHosts){
        $nHostName = $n.Name
        $nHostIP = $n.IP
        Write-Log -Value "Removing nested ESXI host: $nHostName out of maintenance mode." -InfoType
        Set-VMHost -Server $nServers -VMHost $nHostIP -State Connected -ErrorAction Stop | Out-Null
        Write-Log -Value "Nested ESXI host: $nHostName is out of maintenance mode." 
    }

    Start-Sleep -Seconds 10

    ##Starting VCF Components
    foreach($Component in $VCF_Components){
		$vm = Get-VM -Server $nServers -Name $Component -ErrorAction SilentlyContinue
		if($vm){
			Start-VM -VM $vm -ErrorAction Stop | Out-Null
			Write-Log -Value "Started $Component on nested ESXI host: $($vm.VMHost)" 
		}else{
			Write-Log -Value "$Component is not available on ESXI hosts: $nServers." -InfoType
        }
    }
	
	##Disconnect from nested hosts
	Disconnect-VIServer -Server $nServers -Force -Confirm:$false -ErrorAction Stop
    Write-Log -Value "Disconnected from nested ESXI hosts: $nServers" -InfoType
	
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