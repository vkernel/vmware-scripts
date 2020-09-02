/*
 * Created on Wed Sep 02 2020
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
 */

$Hosts = "10.0.10.100", "10.0.10.101", "10.0.10.102", "10.0.10.103"
$SDDC_Components = "vcenter-mgmt", "nsx-mgmt-1", "sddc-manager"

foreach($h in $hosts){
    Connect-VIServer $h -User "root" -Password "VMware123!"
    if((Get-VMHost -Name $h -ErrorAction SilentlyContinue).ConnectionState -eq "Maintenance"){
        Set-VMHost -VMHost $h -State Connected | Out-Null
        Write-Host "Host $h is out of maintenance mode." -ForegroundColor Green
    }else{
        Write-Host "Host $h was already out of maintenace mode." -ForegroundColor Red
    }
    Disconnect-VIServer -Server * -Force -Confirm:$false
}

Start-Sleep -Seconds 10

foreach($VM in $SDDC_Components){
    foreach($h in $hosts){
        Connect-VIServer $h -User "root" -Password "VMware123!"
        if(Get-VM -Name $VM -ErrorAction SilentlyContinue){
            Start-VM -VM $VM
            Write-Host "$VM is started on $h." -ForegroundColor Green
        }
        Disconnect-VIServer -Server * -Force -Confirm:$false
    }
}

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');