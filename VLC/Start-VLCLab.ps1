$Hosts = "10.0.10.100", "10.0.10.101", "10.0.10.102", "10.0.10.103"


foreach($h in $hosts){
    Connect-VIServer $h -User "root" -Password "VMware123!"
    if((Get-VMHost -Name $h -ErrorAction SilentlyContinue).ConnectionState -eq "Maintenance"){
        Set-VMHost -VMHost $h -State Connected | Out-Null
        Write-Host "Host $h uit maintenance gehaald!" -ForegroundColor Green
    }else{
        Write-Host "Host $h was al uit maintenance mode!" -ForegroundColor Red
    }
    Disconnect-VIServer -Server * -Force -Confirm:$false
}

Start-Sleep -Seconds 10

$VMs = "vcenter-mgmt", "nsx-mgmt-1", "sddc-manager"

foreach($VM in $VMs){
    foreach($h in $hosts){
        Connect-VIServer $h -User "root" -Password "VMware123!"
        if(Get-VM -Name $VM -ErrorAction SilentlyContinue){
            Start-VM -VM $VM
            Write-Host "$VM gestart op op $h" -ForegroundColor Green
        }else{
            Write-Host "$VM draait niet op $h" -ForegroundColor Red
        }
        Disconnect-VIServer -Server * -Force -Confirm:$false
    }
}

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');