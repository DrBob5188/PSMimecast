<#
.SYNOPSIS
  Decrypts the API Keys.

.DESCRIPTION
  Uses the settings passed from a call to load config to obtain the AES key
  and decrypts the API keys using that key.
  The settings hashtable is updated with the decrypted api keys.

.PARAMETER Settings <HashTable>
  A hashtable of configuration settings obtained from a call to Loadconfig file.

.INPUTS
  none

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  29/4/2017
  Purpose/Change: Initial script development

.EXAMPLE
  ConvertFrom-EncryptedApiKey  -settings $Settings -AccessApiKey "YourAccessKey" -SecretApiKey "Your secret key"

#>


function ConvertFrom-EncryptedApiKey
{
    [cmdletBinding()]
    Param(
        [parameter(Mandatory= $true)]
        [HashTable]$Settings
    )

    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)

    #Validate Mandatory Settings are present
    if  (
            ( -not $Settings.ContainsKey('KeyContainerName')) -or
            ( -not $Settings.ContainsKey('Encrypted-PasswordEncryptionKey'))
        )
    {
        $e = New-Object System.ArgumentException ($vMsgs.ArgException -f $MyInvocation.MyCommand, 'KeyContainerName', 'Encrypted-PasswordEncryptionKey')
        throw $e
    }

    try
    {
        $ApiKeys = @{}
        $csp = New-Object System.Security.Cryptography.CspParameters
        if ($Settings['UseMachineKeys'] -eq $true)
        {
            $csp.Flags = [System.Security.Cryptography.CspProviderFlags]::UseMachineKeyStore
        }
        $csp.Flags = $csp.Flags -bor [System.Security.Cryptography.CspProviderFlags]::UseExistingKey;
        $csp.KeyContainerName = $Settings['KeyContainerName']
        $rsap = New-Object System.Security.Cryptography.RSACryptoServiceProvider -ArgumentList ($csp)
        $AesKey = $rsap.Decrypt([System.Convert]::FromBase64String($settings['Encrypted-PasswordEncryptionKey']),$true)
        $ApiKeys['accessKey'] = ConvertTo-SecureString -String $Settings['Encrypted-AccessKey'] -Key $AesKey
        $ApiKeys['secretKey'] = ConvertTo-SecureString -String $Settings['Encrypted-SecretKey'] -Key $AesKey
        $cred = New-object System.Management.Automation.PSCredential ("Placeholder",$ApiKeys['secretKey'])
        $Settings['secretKey'] = $cred.GetNetworkCredential().Password
        $cred = New-object System.Management.Automation.PSCredential ("Placeholder",$ApiKeys['accessKey'])
        $Settings['accessKey'] = $cred.GetNetworkCredential().Password
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
