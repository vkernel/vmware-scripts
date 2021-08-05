<#
 * Created on Thur Jul 29 2021
 *
 * The MIT License (MIT)
 * Copyright (c) 2021 DAngelo Karijopawiro
 * Website: https://vkernelblog.com
 * GitHub: https://github.com/vkernelblog
 * File: Set-HostCustomizations.ps1
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

$StartTime = (Get-Date).ToShortDateString()+", "+(Get-Date).ToLongTimeString()
$Script_location = Split-Path $script:MyInvocation.MyCommand.Path 
$Inputfile = "$Script_location\HostCustomizations-InputFile.csv"
$vCenter = Read-Host -Prompt "Enter the vCenter FQDN"

Function Write-Log{
    param(
        [Parameter(Mandatory=$true)]$Value = $Value,
        [Switch]$Warning,
        [Switch]$Error
    )

    $Date = Get-Date -Format dd-MM-yyyy
    $Time = Get-date -Format HH:mm:ss

    $LogFolder = Split-Path $script:MyInvocation.MyCommand.Path 
        if(Test-Path -Path "$LogFolder\logs"){
    }else{
        New-Item -ItemType Directory -Path "$LogFolder\logs" | Out-Null
    }

    $LogFile = "$LogFolder\logs\$Date-hostcustomization.log" 


    if($Warning){
        $Message = "$Date $Time WARNING: $Value"
        $Message | Out-File -FilePath $LogFile -Append -Force
        Write-Host $Message -ForegroundColor Yellow
    }
    elseif($Error){
        $Message = "$Date $Time ERROR: $Value"
        $Message | Out-File -FilePath $LogFile -Append -Force
        Write-Host $Message -ForegroundColor Red
    }
    else{
        $Message = "$Date $Time INFO: $Value"
        $Message | Out-File -FilePath $LogFile -Append -Force
        Write-Host $Message 
        
    }

}

try{
    $CSV_data = Import-Csv -Path $Inputfile -Delimiter ";" -ErrorAction Stop
    Write-Log -Value "Connecting to $vCenter"
    Connect-VIServer $vCenter -ErrorAction Stop | Out-Null
    Write-Log -Value "Connected to $vCenter"
    $n = 0
    foreach($c in $CSV_data){
        $esxiHost = Get-VMHost -Name $c.name -ErrorAction Stop
        $hostProfileManagerView = Get-View "HostProfileManager" 
        $answerFile = New-Object VMware.Vim.AnswerFileOptionsCreateSpec 
        $RequiredInputs = @()

        if($c.'ProfilePath-Management-vmk'){
            $Managementvmk = @{
            ProfilePath = $C.'ProfilePath-Management-vmk';
            IP = $c.'Management IPAddress';
            Subnet = $c.'Management SubnetMask'
            }

            $RequiredInputs += $Managementvmk
        }
        if($c.'ProfilePath-vMotionA-vmk'){
            $vMotionAvmk = @{
            ProfilePath = $C.'ProfilePath-vMotionA-vmk';
            IP = $c.'vMotion-A IPAddress';
            Subnet = $c.'vMotion-A SubnetMask'
            }

            $RequiredInputs += $vMotionAvmk
        }
        if($c.'ProfilePath-vMotionB-vmk'){
            $vMotionBvmk = @{
            ProfilePath = $C.'ProfilePath-vMotionB-vmk';
            IP = $c.'vMotion-B IPAddress';
            Subnet = $c.'vMotion-B SubnetMask'
            }

            $RequiredInputs += $vMotionBvmk
        }
        if($c.'ProfilePath-VSAN-vmk'){
            $VSANvmk = @{
            ProfilePath = $c.'ProfilePath-VSAN-vmk';
            IP = $c.'VSAN IPAddress';
            Subnet = $c.'VSAN SubnetMask'
            }

            $RequiredInputs += $VSANvmk
        }

        Write-Log -Value "Configuring host customizations for ESXi host $esxiHost" 

        foreach($r in ($RequiredInputs | ForEach-Object{[pscustomobject]$_})){
            $propPath = New-Object VMware.Vim.ProfilePropertyPath 
            $propPath.ProfilePath = $r.ProfilePath
            $propPath.PolicyId = "IpAddressPolicy"
 
            $addr = New-Object VMware.Vim.KeyAnyValue
            $addr.key = "address"
            $addr.value = $r.IP
            $mask = New-Object VMware.Vim.KeyAnyValue
            $mask.key = "subnetmask"
            $mask.value = $r.Subnet
 
            $param = New-Object VMware.Vim.ProfileDeferredPolicyOptionParameter
            $param.InputPath = $propPath
            $param.Parameter += $addr
            $param.Parameter += $mask
            $answerFile.UserInput += $param
    
            $hostProfileManagerView.UpdateAnswerFile($esxiHost.ExtensionData.MoRef, $answerFile)

             Write-Log -Value "Configured the following IP configuration and profile path $r on ESXi host $esxiHost"
        }

        $n++
        $AnswerFileStatus = $hostProfileManagerView.CheckAnswerFileStatus($esxiHost.ExtensionData.MoRef)

        if($AnswerFileStatus.status -eq "valid"){
            Write-Log -Value "Answer file status is valid on ESXi host $esxiHost"  
        }else{
            Write-Log -Value "Answer file status is not valid on ESXi host $esxiHost"            
        } 
    }

    if($n -gt 1){
        $info = "hosts"
    }else{
        $info = "host"
    }

    Write-Log -Value "Host customization successfully configured on $n ESXi $info"
    Write-Log -Value "Complete the remediation process manually from the vCenter GUI on the ESXi $info"
}catch{
    $ErrorMessage = $_.Exception.Message
    Write-Log -Value $ErrorMessage.Substring(19) -Error
}finally{
    $EndTime = (Get-Date).ToShortDateString()+", "+(Get-Date).ToLongTimeString()
    $TimeTaken = New-TimeSpan -Start $StartTime -End $EndTime

    Write-Log -Value  ($Footer = @"

$("-"*79)
Start Time          : $StartTime
End Time            : $EndTime
Total runtime       : $TimeTaken
$("-"*79)
"@)

}

Write-Host "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")