$Hosts = "10.0.10.100", "10.0.10.101", "10.0.10.102", "10.0.10.103"
$vCenter = "vcenter-mgmt.vkernelblog.net"


    Connect-VIServer $vCenter -User "administrator@vsphere.local" -Password "VMware123!"
    $VMs = Get-VM | Where-Object{($_.Name -notlike "vcenter-mgmt") -and ($_.PowerState -like "PoweredOn")}
    ##Gracefull shutdown van alle vms behalve vcenter
    foreach($VM in $VMs){
        Shutdown-VMGuest -VM $VM -Confirm:$false
    }

    ##check of de vms uitstaan
    foreach($VM in $VMs){
    Do
    { 
        $check = Get-VM -Name $VM
        if($check.PowerState -like "PoweredOn"){
            Write-Host "De volgende VM staat nog aan:" $check.name 
        }
        else{
            Write-Host "De volgende VM staat uit:" $check.name 
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
                    Write-Host "De volgende VM staat nog aan:" $check2.name 
                }
                else{
                        Write-Host "De volgende VM staat uit:" $check2.name 
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