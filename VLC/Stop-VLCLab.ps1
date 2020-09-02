/*
 * Created on Wed Sep 02 2020
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
 */


$Hosts = "10.0.10.100", "10.0.10.101", "10.0.10.102", "10.0.10.103"
$vCenter = "vcenter-mgmt.vkernelblog.net"


    Connect-VIServer $vCenter -User "administrator@vsphere.local" -Password "VMware123!"
    $VMs = Get-VM | Where-Object{($_.Name -notlike "vcenter-mgmt") -and ($_.PowerState -like "PoweredOn")}
    ##Gracefull shutdown off all VMs except vCenter.
    foreach($VM in $VMs){
        Shutdown-VMGuest -VM $VM -Confirm:$false
    }

    ##Check if all VMs besides vCenter are powered off.
    foreach($VM in $VMs){
    Do
    { 
        $check = Get-VM -Name $VM
        if($check.PowerState -like "PoweredOn"){
            Write-Host "The following VM is still powered on:" $check.name 
        }
        else{
            Write-Host "The following VM is powered off:" $check.name 
        }
    } 
      while($check.PowerState -ne "PoweredOff") 
    }
    
    $vCenter = "vcenter-mgmt"
    Shutdown-VMGuest -VM $vCenter -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction SilentlyContinue

    foreach($h in $hosts){
        Connect-VIServer $h -User "root" -Password "VMware123!"
        $check = Get-VM -Name $vCenter -ErrorAction SilentlyContinue
            if ($check){
                Do
                { 
                    $check2 = Get-VM -Name $vCenter -ErrorAction SilentlyContinue
                    if($check2.PowerState -like "PoweredOn"){
                    Write-Host "The following VM is still powered on:" $check2.name 
                }
                else{
                        Write-Host "The following VM is powered off on host $h:" $check2.name 
                    }
                } 
                  while($check2.PowerState -ne "PoweredOff") 
            }else{
                Write-Host "vCenter draait niet op host:" $h -ForegroundColor Red
            }
            
    }
  

Start-Sleep -Seconds 10


foreach($h in $hosts){
    Connect-VIServer $h -User "root" -Password "VMware123!"
    if((Get-VMHost -Name $h -ErrorAction SilentlyContinue).ConnectionState -eq "Connected"){
        Set-VMHost -VMHost $h -State "Maintenance" -VsanDataMigrationMode NoDataMigration | Out-Null
        Write-Host "Host $h in maintenance mode gezet!" -ForegroundColor Green
    }else{
        Write-Host "Host $h was al in maintenance mode!" -ForegroundColor Red
    }
    Disconnect-VIServer -Server * -Force -Confirm:$false
}

foreach($h in $hosts){
    Connect-VIServer $h -User "root" -Password "VMware123!"
    Stop-VMHost -VMHost $h -Confirm:$false
    Write-Host "Host $h uitgeschakeld!" -ForegroundColor Red
    Disconnect-VIServer -Server * -Force -Confirm:$false
}


Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');