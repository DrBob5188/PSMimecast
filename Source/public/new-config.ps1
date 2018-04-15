<#
.SYNOPSIS
  Create and save a new PSMimecast configuration file.

.DESCRIPTION
  Create and save a new PSMimecast configuration file.

.PARAMETER path
  The path to the config file.

.PARAMETER credential
  A PSCredential object containing the username and password for Mimecast login. 

.PARAMETER keyName
  The name of the container to be used to store the RSA key.

.PARAMETER KeySize
  The size of the RSA key to create.

.PARAMETER useMachineKeys
  Use machine key store for RSA key storage. Default is true. 

.INPUTS
  none

.OUTPUTS
  none.

.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  22/2/2017
  Purpose/Change: Initial script development

.EXAMPLE
  New-Config -path "c:\mimecast\PSMimecast\PSMimecast.xml
  Creates a new config file generating new RSA and AES keys automatically.
#>
function New-Config
{
    [cmdletBinding()]
    Param(
        [parameter(Mandatory= $true)]
        [string]$path,
        [parameter(Mandatory= $true)]
        [PSCredential]$credential,
        [parameter(Mandatory= $false)]
        [String]$keyName="PSMimecast Config Encryption Key",
        [parameter(Mandatory = $false)]
        [int]$KeySize= 2048,
        [parameter(Mandatory = $false)]
        [Switch]$useMachineKeys = $true
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'VerbosePreference'
    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)
   
    $settings = @{
        "username" = $credential.UserName;
        "KeyContainerName" = $keyName;
        "UseMachineKeys" = $useMachineKeys;
        "Encrypted-PasswordEncryptionKey" = [String]::Empty;
        "Encrypted-Password" = [String]::Empty;
        "Encrypted-AccessKey" = [String]::Empty;
        "Encrypted-SecretKey" = [String]::Empty;
        "APIKeyExpiry" = [String]::Empty;
        "LoggingLevel" = "0";
        "LogDirectory" = ".\"
        "BaseUrl" = [String]::Empty
        "applicationId" = "f86a9db0-61be-487d-8d47-f5f3ade86d10"
        "applicationKey" = "05a0ec94-0ca1-417e-b9c9-c3713e34e339"
        "Authtype" = [String]::Empty;
    }

    try
    {
        $aesKey = New-Object byte[] (32) #256 bits of key material for AES-256 encryption with convert-fromSecureString
        $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $csp = New-Object System.Security.Cryptography.CspParameters
        if ($useMachineKeys)
        {
            $csp.Flags = [System.Security.Cryptography.CspProviderFlags]::UseMachineKeyStore
        }
        $csp.KeyContainerName = $keyName
        $rsap = New-Object System.Security.Cryptography.RSACryptoServiceProvider -ArgumentList ($keysize,$csp)
        $rsap.PersistKeyInCsp = $true
    
        $rng.GetBytes($aesKey) 
        $settings["Encrypted-Password"] = ConvertFrom-SecureString -SecureString $credential.Password -Key $aesKey
        $settings["Encrypted-PasswordEncryptionKey"] = [System.Convert]::ToBase64String($rsap.Encrypt($aesKey,$true))
        $rsap.Clear()
        [array]::clear($aesKey, 0, $aesKey.length)

        $doc = New-Object System.Xml.XmlDocument
        $newChild = $doc.CreateElement("configuration")
        $config = $doc.AppendChild($newChild)
        $newChild = $doc.CreateElement("appSettings")
        $baseNode = $config.AppendChild($newChild)

        foreach ($key in $settings.Keys)
        {
            write-verbose ($vMsgs.settings -f $MyInvocation.MyCommand, $key, $settings[$key])
            $newChild = $doc.CreateElement("add")
            write-verbose ($vMsgs.newNode -f $MyInvocation.MyCommand, $newChild.Name )
            $newAttrib = $doc.CreateAttribute("key")
            $newAttrib.Value = $key           
            write-verbose ($vMsgs.newAttrib -f $MyInvocation.MyCommand, $newAttrib.Name, $newAttrib.Value )
            $newChild.Attributes.Append($newAttrib) | Out-Null
            write-verbose ($vMsgs.appendAttrib -f $MyInvocation.MyCommand, $newAttrib.Name, $newAttrib.Value )
            $newAttrib = $doc.CreateAttribute("value")
            $newAttrib.Value = $settings[$key]
            write-verbose ($vMsgs.newAttrib -f $MyInvocation.MyCommand, $newAttrib.Name, $newAttrib.Value )
            $newChild.Attributes.Append($newAttrib) | Out-Null
            write-verbose ($vMsgs.appendAttrib -f $MyInvocation.MyCommand, $newAttrib.Name, $newAttrib.Value )
            $baseNode.AppendChild($newChild)  | Out-Null
            write-verbose ($vMsgs.appendChild -f $MyInvocation.MyCommand, $newChild.Name )
        }
    
        $xmlWs = new-object System.Xml.XmlWriterSettings
        if ($config.ChildNodes[0] -is [System.Xml.XmlDeclaration])
        {
            $xmlWs.OmitXmlDeclaration = $true
        }
        $xmlWs.Indent = $true
        $xmlWs.IndentChars = "  "
        $xmlWs.NewLineHandling = [System.Xml.NewLineHandling]::Replace
        $xmlWS.NewLineChars = "`r`n"
        $sb = new-object System.Text.StringBuilder
        $writer = [System.Xml.XmlWriter]:: Create($sb,$xmlWs)
        $doc.Save($writer)
        $sb.ToString() | out-file $path
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
