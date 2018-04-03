<#
.SYNOPSIS
  Creates a signature for a request to the mimecast REST API.

.DESCRIPTION
  All requests to the Mimecast API except login must include the date and
  time (x-mc-date) of the request, a unique request id (x-mc-req-id),
  your Mimecast ApplicationID and a signature in the request headers.

  This function computes the HMACSHA1 hash and returns it as
  a base64 encoded string.

.PARAMETER message <String>
  The data to be hashed.

.PARAMETER key <String>
  The key to be used in the keyed-hashing function. 

.INPUTS
  none

.OUTPUTS
  System.String - The base64 encoded result of the HMAC function.

.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  1/2/2016
  Purpose/Change: Initial script development

.EXAMPLE
  get-Signature  -message "Message to Hash" -key "secretkey"

#>

function Get-Signature
{
    [cmdletBinding()]
    Param(
        [parameter(Mandatory= $true)]
        [string]$message,
        [parameter(Mandatory= $true)]
        [String]$key
    )            

    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)
    Write-Verbose ($vMsgs.messageContent -f $MyInvocation.MyCommand, $message)
    write-verbose ($vMsgs.b64Key -f $MyInvocation.MyCommand, $key)
    $keyBytes = [System.Convert]::FromBase64String($key)
    write-verbose ($vMsgs.keyBytes -f $MyInvocation.MyCommand, ([System.BitConverter]::ToString($keyBytes)))
    $hmacSha1 = new-object System.Security.Cryptography.HMACSHA1 -ArgumentList @(,$keyBytes)
    $digest = $hmacSha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($message))
    write-verbose ($vMsgs.hashBytes -f $MyInvocation.MyCommand,([System.BitConverter]::ToString($digest)))
    $signature = [System.Convert]::ToBase64String($digest)
    write-verbose ($vMsgs.b64HashBytes -f $MyInvocation.MyCommand, $signature)
    Write-Output ($signature)
}

