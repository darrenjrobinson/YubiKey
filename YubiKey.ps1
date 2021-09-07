# Import lib dependancies 
if ((Test-Path -Path .\Yubico.YubiKey.dll) -and (Test-Path -Path .\Yubico.Core.dll) ) {
    if ($PSVersionTable.PSVersion.Major -le 5) { 
        Write-Error "This module requires PowerShell Core 6.x or PowerShell 7.x"
        break   
    }
    elseif ($PSVersionTable.PSVersion.Major -gt 5) { 
        Add-Type -Path .\Yubico.YubiKey.dll 
        Add-Type -Path .\Yubico.Core.dll 
    }
}
else {
    Write-Error "The required 'Yubico.YubiKey.dll' or 'Yubico.Core.dll' is missing from the current directory!" 
    break 
}

function Find-YubiKeyDevices {
    <#
    .SYNOPSIS
        Find and return all connected Yubico YubiKeys.

    .DESCRIPTION
        Find and return all connected Yubico YubiKeys.
        
    .EXAMPLE
        Find-YubiKeyDevices
    #>
    $YubiKeyDevices = $null 
    try {
        $YubiKeyDevices = [Yubico.YubiKey.YubiKeyDevice]::FindAll()
        return $YubiKeyDevices
    }
    catch {
        $_
    }
} 

function Get-YubiKeyDevice {
    <#
    .SYNOPSIS
        Find and return a specific connected Yubico YubiKey.

    .DESCRIPTION
        Find and return a specific connected Yubico YubiKey.

    .PARAMETER SerialNumber
        SerialNumber of the YubiKey. 
        Can be found using Find-YubiKeyDevices
        
    .EXAMPLE
        Get-YubiKeyDevice -SerialNumber 12345
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [int]$SerialNumber
    )
    $YubiKeyDevices, $YubiKeyDevice = $null 
    try {
        $YubiKeyDevices = Find-YubiKeyDevices
        $YubiKeyDevice = $YubiKeyDevices | Where-Object { $_.SerialNumber -eq $SerialNumber } | Select-Object 
        if ($YubiKeyDevice) {
            return $YubiKeyDevice
        }
        else {
            Write-Output "YubiKey Device with SerialNumber '$($SerialNumber)' not found."
        }
    }
    catch {
        $_
    }
}


Function Get-YubiKeyCertificate {
    <#
    .SYNOPSIS
        Find and return a specific certificate from a Yubico YubiKey.

    .DESCRIPTION
        Find and return a specific certificate from a Yubico YubiKey.

    .PARAMETER CertSlot
        Certificate Slot to return the certificate from 
        # Slot 9a 'Authentication'
        # Slot 9c 'Signature'
        # Slot 9d 'KeyManagement'
        # Slot 9e 'CardAuthentication'
        
    .PARAMETER SerialNumber
        SerialNumber of the YubiKey. 
        Can be found using Find-YubiKeyDevices

    .PARAMETER Raw
        [Boolean]Return the certificate as Base64 encoded 
        Defaults to False
        
    .EXAMPLE
        Get-YubiKeyCertificate -CertSlot Authentication -SerialNumber 15464990 
        
    .EXAMPLE
        Get-YubiKeyCertificate -CertSlot Signature -SerialNumber 15464990 

    .EXAMPLE
        Get-YubiKeyCertificate -CertSlot KeyManagement -SerialNumber 15464990 

    .EXAMPLE
        Get-YubiKeyCertificate -CertSlot CardAuthentication -SerialNumber 15464990 

    .EXAMPLE
        Get-YubiKeyCertificate -CertSlot CardAuthentication -SerialNumber 15464990 -Raw $True
    #>

    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateSet('Authentication', 'Signature', 'KeyManagement', 'CardAuthentication')]
        [string]$CertSlot,
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $false)]
        [bool]$Raw = $false
    )

    $YubiKeyDevice = Get-YubiKeyDevice -SerialNumber $SerialNumber
    if ($YubiKeyDevice.SerialNumber -eq $SerialNumber) {
        try {
            $YubiKeyPivConnection = [Yubico.YubiKey.YubiKeyApplication]::Piv
            $YubiKeyConnection = $YubiKeyDevice.Connect($YubiKeyPivConnection)

            if (!$YubiKeyConnection.SelectApplicationData.RawData.IsEmpty) {
                $getData = New-Object Yubico.YubiKey.Piv.Commands.GetDataCommand
                $getData.Tag = $CertSlot        
                $response = $YubiKeyConnection.SendCommand($getData)
        
                if ($response.Status -eq 'Success') {
                    $value = ($response.GetData()).ToArray()
                    $base64String = [Convert]::ToBase64String($value)
                    $trimLength = $base64String.IndexOf('MI')
                    $base64Cert = $base64String.Substring($trimLength)
                    $certDetails = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(, [Convert]::FromBase64String($base64Cert))

                    if ($Raw) {
                        return $base64Cert 
                    }
                    else {
                        return $certDetails
                    }
                }
                elseif ($response.Status -eq 'NoData') {
                    write-output "'$($getData.Tag)' certificate not present on YubiKey $($YubiKeyDevice.FormFactor) device with Serial Number $($YubiKeyDevice.SerialNumber)"
                }
            }
        }
        catch {
            write-output $_.ErrorDetails
        }
    }
    else {
        Write-Error "YubiKey Device with SerialNumber '$($SerialNumber)' not found."
    }
}

