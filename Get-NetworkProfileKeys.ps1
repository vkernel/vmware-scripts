<#
 * Created on Thur Jul 29 2021
 *
 * The MIT License (MIT)
 * Copyright (c) 2021 DAngelo Karijopawiro
 * Website: https://vkernelblog.com
 * GitHub: https://github.com/vkernelblog
 * File: Get-NetworkProfileKeys.ps1
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

$vCenter = Read-Host -Prompt "Enter vCenter FQDN"
$FirstHost = Read-Host -Prompt "Enter the first ESXi FQDN"

Connect-VIServer -Server $vCenter

Function Copy-Property ($From, $To, $PropertyName ="*"){
    foreach ($p in Get-Member -In $From -MemberType Property -Name $propertyName){
        trap {
            Add-Member -In $To -MemberType NoteProperty -Name $p.Name -Value $From.$($p.Name) -Force
            continue
        }
    $To.$($P.Name) = $From.$($P.Name)
    }
}

$hp = get-vmhost -Name $FirstHost | Get-VMHostProfile
$spec = New-Object VMware.Vim.HostProfileCompleteConfigSpec
Copy-Property -From $hp.ExtensionData.Config -To $spec

$begin = 'network.dvsHostNic["'
$end = '"].ipConfig'

$keys = $spec.ApplyProfile.Network.DvsHostNic.key
foreach($k in $keys){
    Write-Host "$begin$k$end"
}

Write-Host "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")