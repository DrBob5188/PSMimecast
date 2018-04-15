<#
.SYNOPSIS
  Encrypts the API Access Keys.

.DESCRIPTION
  Uses the settings passed from a call to load config to obtain the AES key
  and encrypts the API keys using that key.
  The settings hashtable is updated with the encrypted values and can be persisted with a call to Save-Config

.PARAMETER Settings
  A hashtable of configuration settings obtained from a call to config file.

.INPUTS
  none

.OUTPUTS
  none.

.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  29/4/2017
  Purpose/Change: Initial script development

.EXAMPLE
  ConvertTo-EncryptedApiKey  -settings $Settings
  Encrypts the secretKey and accessKey in the settings hashtable adding entries
  to the hashtable so that it can be saved using the save-config function

.LINK
  save-config

#>
function ConvertTo-EncryptedApiKey
{
    [cmdletBinding()]
    Param(
        [parameter(Mandatory= $true)]
        [HashTable]$Settings
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'VerbosePreference'
    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)

    #Validate Mandatory Settings are present
    if  (
            ( -not $Settings.ContainsKey('KeyContainerName')) -or
            ( -not $Settings.ContainsKey('Encrypted-PasswordEncryptionKey'))
        )
    {
        Write-Verbose ($vMsgs.ArgException -f $MyInvocation.MyCommand, 'KeyContainerName', 'Encrypted-PasswordEncryptionKey')
        $e = New-Object System.ArgumentException ($vMsgs.ArgException -f $MyInvocation.MyCommand, 'KeyContainerName', 'Encrypted-PasswordEncryptionKey')
        throw $e
    }

    Try
    {
        Write-Verbose ($vMsgs.initCSP -f $MyInvocation.MyCommand)
        $csp = New-Object System.Security.Cryptography.CspParameters
        if ($Settings['UseMachineKeys'] -eq $true)
        {
            $csp.Flags = [System.Security.Cryptography.CspProviderFlags]::UseMachineKeyStore
        }
        $csp.Flags = $csp.Flags -bor [System.Security.Cryptography.CspProviderFlags]::UseExistingKey;
        $csp.KeyContainerName = $Settings['KeyContainerName']
        Write-Verbose ($vMsgs.rsaProvider -f $MyInvocation.MyCommand)
        $rsap = New-Object System.Security.Cryptography.RSACryptoServiceProvider -ArgumentList ($csp)
        Write-Verbose ($vMsgs.decryptAES -f $MyInvocation.MyCommand)
        $AesKey = $rsap.Decrypt([System.Convert]::FromBase64String($settings['Encrypted-PasswordEncryptionKey']),$true)
        Write-Verbose ($vMsgs.encryptAPIKeys -f $MyInvocation.MyCommand)
        $SecureAccessKey = ConvertTo-SecureString -Force -AsPlainText -String $Settings['accessKey']
        $SecureSecretKey = ConvertTo-SecureString -Force -AsPlainText -String $Settings['secretKey']
        $Settings['Encrypted-AccessKey'] = ConvertFrom-SecureString -SecureString $SecureAccessKey -Key $AesKey
        $Settings['Encrypted-SecretKey'] = ConvertFrom-SecureString -SecureString $SecureSecretKey -Key $AesKey
    }
    finally
    {
       if ($null -ne $rsap)
        {
            $rsap.Clear()
        }
        if ($null -ne $AesKey)
        {
            [array]::clear($AesKey, 0, $AesKey.length)
        }
    }
}
