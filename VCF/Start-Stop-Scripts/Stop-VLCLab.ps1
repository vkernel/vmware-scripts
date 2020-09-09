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
    $VMs = Get-VM -ErrorAction Stop| Where-Object{($_.Name -notlike "vcenter-mgmt") -and ($_.PowerState -like "PoweredOn")}
    foreach($VM in $VMs){
        Shutdown-VMGuest -VM $VM -Confirm:$false -ErrorAction Stop
    }

    ##Check if all VMs besides vCenter are powered off.
    foreach($VM in $VMs){
        Do
        { 
            $check = Get-VM -Name $VM -ErrorAction Stop
            if($check.PowerState -like "PoweredOn"){
                Write-Host "The following VM is still powered on:" $check.name 
                start-Sleep -Seconds 5
            }
            else{
                Write-Host "The following VM is powered off:" $check.name 
            }
        } 
          while($check.PowerState -ne "PoweredOff") 
    }

    Shutdown-VMGuest -VM $vCenterVM -Confirm:$false -ErrorAction Stop | Out-Null
    Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction SilentlyContinue

    ##Shutdown vCenter Server.
    foreach($n in $nHosts){
        Connect-VIServer $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
        $check = Get-VM -Name $vCenterVM -ErrorAction SilentlyContinue
            if ($check){
                Do
                { 
                    $check2 = Get-VM -Name $vCenterVM -ErrorAction SilentlyContinue
                    if($check2.PowerState -like "PoweredOn"){
                    Write-Host "The following VM is still powered on:" $check2.name 
                    start-Sleep -Seconds 5
                }
                else{
                        Write-Host "The following VM is powered off on host: $n" $check2.name 
                    }
                } 
                  while($check2.PowerState -ne "PoweredOff") 
            }else{
                Write-Host "vCenter doesn't run on host:" $n -ForegroundColor Red
            }
            
    }
  
    Start-Sleep -Seconds 10

    ##Put nested hosts in maintenace mode
    foreach($n in $nHosts){
        Connect-VIServer $n -Credential $nHost_Credentials -ErrorAction Stop | Out-Null
        if((Get-VMHost -Name $n -ErrorAction SilentlyContinue).ConnectionState -eq "Connected"){
            Set-VMHost -VMHost $n -State "Maintenance" -VsanDataMigrationMode NoDataMigration | Out-Null
            Write-Host "Host $n in maintenance mode gezet!" -ForegroundColor Green
        }else{
            Write-Host "Host $n was al in maintenance mode!" -ForegroundColor Red
        }
        Disconnect-VIServer -Server * -Force -Confirm:$false
    }

    ##Poweroff nested hosts
    foreach($n in $nHosts){
        Connect-VIServer $n -User "root" -Password "VMware123!"
        Stop-VMHost -VMHost $n -Confirm:$false
        Write-Host "Host $n uitgeschakeld!" -ForegroundColor Red
        Disconnect-VIServer -Server * -Force -Confirm:$false
    }
}catch{
    $ErrorMessage = $_.Exception.Message
    write-log -Value $ErrorMessage -ErrorType
}
   

    
    
    

    





Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');