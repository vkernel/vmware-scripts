<#
 * Created on Mon Jan 15 2024
 *
 * The MIT License (MIT)
 * Copyright (c) 2024 DAngelo Karijopawiro
 * Website: https://vkernel.nl
 * GitHub: https://github.com/vkernel
 * File: Configure-VcIdentitySourceLdaps.ps1
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

Function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [switch]$ErrorType,
        [switch]$SuccessType
    )
    
    $date = Get-Date -Format s 
    $fdate = Get-Date -Format dd-MM-yyyy
    $currentFolder = Get-Location
    $logFile = "$currentFolder\logs\logfile.txt"

    if ((Test-Path -Path "$currentFolder\Logs") -like "False") {
        New-Item -ItemType Directory -Path "$currentFolder\Logs" | Out-Null
    }

    if ($ErrorType) {
        Write-Host "$date - ERROR: $Value" -ForegroundColor Red
        Out-File -InputObject "$date - ERROR: $Value" -FilePath $LogFile -Append -Encoding utf8
    }
    elseif ($SuccessType) {
        Write-Host "$date - SUCCESS: $Value" -ForegroundColor Green
        Out-File -InputObject "$date - SUCCESS: $Value" -FilePath $LogFile -Append -Encoding utf8
    } else {
        Write-Host "$date - INFO: $Value" -ForegroundColor White
        Out-File -InputObject "$date - INFO: $Value"  -FilePath $LogFile -Append -Encoding utf8
    }
    
}

Function Configure-VcIdentitySourceLdaps {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$vcenter,
        [Parameter(Mandatory=$true)][string]$vcenter_username,
        [Parameter(Mandatory=$true)][string]$vcenter_password,
        [Parameter(Mandatory=$true)][string]$vcenter_root_password,
        [Parameter(Mandatory=$true)][string]$primary_server_url,
        [string]$secondary_server_url,
        [Parameter(Mandatory=$true)][string]$domain,
        [Parameter(Mandatory=$true)][string]$domain_user,
        [Parameter(Mandatory=$true)][string]$domain_password,
        [Parameter(Mandatory=$true)][string]$base_user_dn,
        [Parameter(Mandatory=$true)][string]$base_group_dn
        )
    
    try {
            $currentFolder = Get-Location
            $certFilePathSource = "$currentFolder\ldaps.cer"
            $certFilePathDestination = "/tmp/ldaps.cer"
            $tempBashFileSource = "$currentFolder\bash.sh"
            $tempBashFileDestination = "/tmp/bash.sh"

            # Connect to vCenter Server
            Connect-VIServer -Server $vcenter -User $vcenter_username -Password $vcenter_password -ErrorAction Stop | Out-Null
            Write-Log -Value "Successfully connected to $($vcenter)" -SuccessType -ErrorAction Stop

            # Query vCenter VM that matches FQDN as hostname
            $vCenterVM = Get-VM | Where-Object {$_.ExtensionData.Guest.hostname -eq $vcenter} -ErrorAction Stop
        
            # Retrieve certificate from domain controller
            $getRootCert = "openssl s_client -connect $($primary_server_url -replace "ldaps://") -showcerts"
            $output = Invoke-VMScript -ScriptText $getRootCert -vm $vCenterVM -GuestUser "root" -GuestPassword $vcenter_root_password -ErrorAction Stop

            # Define the begin and end markers
            $beginMarker = "-----BEGIN CERTIFICATE-----"
            $endMarker = "-----END CERTIFICATE-----"

            # Initialize variables to store certificate positions
            $beginIndex = 0
            $endIndex = 0
            $certificates = @()

            # Find all occurrences of begin and end markers
            while (($beginIndex = $output.ScriptOutput.IndexOf($beginMarker, $endIndex)) -ne -1) {
                $beginIndex += $beginMarker.Length
                $endIndex = $output.ScriptOutput.IndexOf($endMarker, $beginIndex)
                $endIndex += $endMarker.Length + 2
    
                if ($endIndex -ne -1) {
                    # Include the begin and end markers in the certificate
                    $certificate = $output.ScriptOutput.Substring($beginIndex - $beginMarker.Length, $endIndex - $beginIndex + $endMarker.Length)
                    $certificates += $certificate
                }
            }

            # Output the extracted certificates
            foreach ($cert in $certificates) {
                Write-Log -Value "Certificate:" -ErrorAction Stop
                Write-Log -Value $cert -ErrorAction Stop
            }

            # Select the last certificate in the chain (if needed)
            $lastCertificate = $certificates[-1]
            Write-Log -Value "Last Certificate:" -ErrorAction Stop
            Write-Log -Value $lastCertificate -ErrorAction Stop
            # Export ldaps certificate
            $lastCertificate | Out-File -FilePath $certFilePathSource -Encoding ascii -ErrorAction Stop 
            # Copy certificate to vCenter server
            Copy-VMGuestFile -VM $vCenterVM -Source $certFilePathSource -Destination $certFilePathDestination -LocalToGuest -GuestUser "root" -GuestPassword $vcenter_root_password -Force -ErrorAction Stop

            # Checking if secondary server url is used.
            if ($secondary_server_url) {
                $FileOutput = "/opt/vmware/bin/sso-config.sh -add_identity_source -type adldap -baseUserDN $base_user_dn -baseGroupDN $base_group_dn -domain $domain -alias $($domain.split('.')[0]) -username $domain_user -password $domain_password -primaryURL $primary_server_url -secondaryURL $secondary_server_url -useSSL true -sslCert $certFilePathDestination"
            } else {
                $FileOutput = "/opt/vmware/bin/sso-config.sh -add_identity_source -type adldap -baseUserDN $base_user_dn -baseGroupDN $base_group_dn -domain $domain -alias $($domain.split('.')[0]) -username $domain_user -password $domain_password -primaryURL $primary_server_url -useSSL true -sslCert $certFilePathDestination"
            }

            # Create bash file to configure SSO on the vCenter server
            $FileOutput | Out-File -FilePath "bash.sh" -ErrorAction Stop -Force -Encoding ascii

            # Copy bash file to the vCenter server
            Copy-VMGuestFile -VM $vCenterVM -Source $tempBashFileSource -Destination $tempBashFileDestination -LocalToGuest -GuestUser "root" -GuestPassword $vcenter_root_password -Force -ErrorAction Stop

            Write-Log -Value "Configuring execution permissions on /tmp/bash.sh file." -ErrorAction Stop
            $setPermission = "chmod +x $tempBashFileDestination"
            $output = Invoke-VMScript -ScriptText $setPermission -vm $vCenterVM -GuestUser "root" -GuestPassword $vcenter_root_password -ErrorAction Stop

            # Configure SSO on the vCenter Server
            $configureSso = "/tmp/bash.sh"
            $output = Invoke-VMScript -ScriptText $configureSso -vm $vCenterVM -GuestUser "root" -GuestPassword $vcenter_root_password -ErrorAction Stop
            if($output.ScriptOutput -like "*ERROR*"){
                Write-Log -Value $output.ScriptOutput -ErrorType -ErrorAction Stop
                return
            }else{
                Write-Log -Value "SSO has been configured successfully on vCenter $vcenter_fqdn" -SuccessType -ErrorAction Stop
            }

            # Removing temporary bash file and ldaps.cer from source.
            Write-Log -Value "Performing cleanup of temp files on source and destination" 
            $tempBashFileSource | Remove-Item -Force -Confirm:$false
            $certFilePathSource | Remove-Item -Force -Confirm:$false
            $removeTempFiles = "rm $certFilePathDestination $tempBashFileDestination"

            $output = Invoke-VMScript -ScriptText $removeTempFiles -vm $vCenterVM -GuestUser "root" -GuestPassword $vcenter_root_password -ErrorAction Stop
            
            # Disconnecting from vCenter Server.
            Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction Stop

        } catch {
            Write-Log -Value $_ -ErrorType -ErrorAction Stop
        }

}

# Example using script
Configure-VcIdentitySourceLdaps -vcenter "vc01.lab.lan" -vcenter_username "administrator@vsphere.local" -vcenter_password "VMware1!" -base_user_dn "dc=lab,dc=lan" -base_group_dn "dc=lab,dc=lan" -vcenter_root_password "VMware1!" -domain "lab.lan" -domain_user "administrator@lab.lan" -domain_password "VMware1!" -primary_server_url "ldaps://ldc01.lab.lan:636" -secondary_server_url "ldaps://ldc02.lab.lan:636" 

