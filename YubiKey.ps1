# Import lib dependancies 
if ((Test-Path -Path .\Yubico.YubiKey.dll) -and (Test-Path -Path .\Yubico.Core.dll)) {
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

# SIG # Begin signature block
# MIINSwYJKoZIhvcNAQcCoIINPDCCDTgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHOm1m1q7quNiYf3yw4tyiJVo
# pxWgggqNMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0B
# AQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# Q29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# +NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ
# 1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0
# sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6s
# cKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4Tz
# rGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg
# 0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUH
# AQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYI
# KwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYE
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06
# GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5j
# DhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgC
# PC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIy
# sjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4Gb
# T8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIFVTCC
# BD2gAwIBAgIQDOzRdXezgbkTF+1Qo8ZgrzANBgkqhkiG9w0BAQsFADByMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBMB4XDTIwMDYxNDAwMDAwMFoXDTIzMDYxOTEyMDAwMFowgZEx
# CzAJBgNVBAYTAkFVMRgwFgYDVQQIEw9OZXcgU291dGggV2FsZXMxFDASBgNVBAcT
# C0NoZXJyeWJyb29rMRowGAYDVQQKExFEYXJyZW4gSiBSb2JpbnNvbjEaMBgGA1UE
# CxMRRGFycmVuIEogUm9iaW5zb24xGjAYBgNVBAMTEURhcnJlbiBKIFJvYmluc29u
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwj7PLmjkknFA0MIbRPwc
# T1JwU/xUZ6UFMy6AUyltGEigMVGxFEXoVybjQXwI9hhpzDh2gdxL3W8V5dTXyzqN
# 8LUXa6NODjIzh+egJf/fkXOgzWOPD5fToL7mm4JWofuaAwv2DmI2UtgvQGwRhkUx
# Y3hh0+MNDSyz28cqExf8H6mTTcuafgu/Nt4A0ddjr1hYBHU4g51ZJ96YcRsvMZSu
# 8qycBUNEp8/EZJxBUmqCp7mKi72jojkhu+6ujOPi2xgG8IWE6GqlmuMVhRSUvF7F
# 9PreiwPtGim92RG9Rsn8kg1tkxX/1dUYbjOIgXOmE1FAo/QU6nKVioJMNpNsVEBz
# /QIDAQABo4IBxTCCAcEwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1Dlgw
# HQYDVR0OBBYEFOh6QLkkiXXHi1nqeGozeiSEHADoMA4GA1UdDwEB/wQEAwIHgDAT
# BgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0
# cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwTAYD
# VR0gBEUwQzA3BglghkgBhv1sAwEwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cu
# ZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEwgYQGCCsGAQUFBwEBBHgwdjAkBggr
# BgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsGAQUFBzAChkJo
# dHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNzdXJlZElE
# Q29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOC
# AQEANWoHDjN7Hg9QrOaZx0V8MK4c4nkYBeFDCYAyP/SqwYeAtKPA7F72mvmJV6E3
# YZnilv8b+YvZpFTZrw98GtwCnuQjcIj3OZMfepQuwV1n3S6GO3o30xpKGu6h0d4L
# rJkIbmVvi3RZr7U8ruHqnI4TgbYaCWKdwfLb/CUffaUsRX7BOguFRnYShwJmZAzI
# mgBx2r2vWcZePlKH/k7kupUAWSY8PF8O+lvdwzVPSVDW+PoTqfI4q9au/0U77UN0
# Fq/ohMyQ/CUX731xeC6Rb5TjlmDhdthFP3Iho1FX0GIu55Py5x84qW+Ou+OytQcA
# FZx22DA8dAUbS3P7OIPamcU68TGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0ECEAzs0XV3s4G5ExftUKPGYK8wCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFKra7FqVbUTW
# oXHqQBXg0SvZrhBaMA0GCSqGSIb3DQEBAQUABIIBAL2ww4R42xx6zhATSaTQbzFZ
# 7Pvepa+ZYVDj3oAsAL9AY/hpFxLFdvoisDLTqayUGbPTATH/1gm662qVn/M9Zma1
# x8l3ga8fTaE9FuNVEvxS5taHAouW0sFIKij1Pxcv6bcclVRblr5xr+VIWY4q5b6R
# yd7BbKMY071zJVTM1SWdCk54x7r38t3y4wnt5MQHRGlLWxJA8H/CVlw5KlslYqSF
# N86kesDwD1BZAJ2Pb8KIsgZ7ngttynJrTL12eXUFZnj2n8ZoszfzGJ7FzWwGlKG+
# Fh89/biTM3MxhncX466CR3qH2KSZx1bB33v7V+qCIqS/YsiwdEgtvs1gWxgTR0Q=
# SIG # End signature block
