<#
.SYNOPSIS
  Log in to retrieve the user's Access Key and Secret Key required to sign
  function level requests.

.DESCRIPTION
  Calls the mimecast /api/login/login endpoint to retrieve the user's Access
  Key and Secret Key required to sign function level requests.

.PARAMETER Settings
  The settings hashtable created with either of the new-config or get-config
  functions.

.PARAMETER Uri
  The mimecast API endpoint.

.PARAMETER Proxy
  Specifies a proxy server for the request, rather than connecting directly
  to the Internet resource. Enter the URI of a network proxy server.
        
.PARAMETER ProxyCredential
  Specifies a user account that has permission to use the proxy server that
  is specified by the Proxy parameter. The default is the current user.

  This parameter is valid only when the Proxy parameter is also used in
  the command. You cannot use the ProxyCredential and 
  ProxyUseDefaultCredentials parameters in the same command.

.INPUTS
  none

.OUTPUTS
  A hashtable containing the following keys
    StatusCode = HTTP statuscode from the Invoke-WebRequest call.
    Headers = The http headers returned from the API call
  and either
    Output =  PSCustomObject returned calling ConvertFrom-JSON on the response body.
  if the returned contenttype is application type is application/json or
    Response = the unconverted response body.


.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  1/2/2016
  Purpose/Change: Initial script development
  References
    [1] How to get Powershell Invoke-Restmethod to return body of http 500 code response. (2013, September 12). Retrieved December 18, 2016, from http://stackoverflow.com/questions/18771424/how-to-get-powershell-invoke-restmethod-to-return-body-of-http-500-code-response

.EXAMPLE
  login -settings $settings
  Logs in to the mimecast api endpoint using the configured username and
  password credential in the settings hashtable.  The credentials are initially
  created using the new-config function.

.LINK
  new-config
#>
function Login
{
    [cmdletBinding(DefaultParameterSetName="All")]
    Param(
        [parameter(Mandatory= $true)]
        [HashTable]$Settings,

        [parameter(Mandatory= $false)]
        [string]$Uri = "/api/login/login",

        [parameter(Mandatory= $true,
         ParameterSetName="Proxy")]
        [String]$Proxy,
        
        [parameter(Mandatory= $false,
         ParameterSetName="Proxy")]
        [PSCredential]$ProxyCredential
    )            

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'VerbosePreference'
    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)
    $RetValues = @{}  #Holds our return values.

    $csp = New-Object System.Security.Cryptography.CspParameters
    if ($Settings['UseMachineKeys'])
    {
        $csp.Flags = [System.Security.Cryptography.CspProviderFlags]::UseMachineKeyStore
    }
    $csp.Flags = $csp.Flags -bor [System.Security.Cryptography.CspProviderFlags]::UseExistingKey
    $csp.KeyContainerName = $Settings['KeyContainerName']
    $rsap = New-Object System.Security.Cryptography.RSACryptoServiceProvider -ArgumentList ($csp)
    $aesKey = $rsap.Decrypt([System.Convert]::FromBase64String($Settings['Encrypted-PasswordEncryptionKey']),$true)
    $Password = ConvertTo-SecureString -String $Settings['Encrypted-Password'] -Key $aesKey
    $rsap.Clear()
    [array]::clear($aesKey, 0, $aesKey.length)
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList ($Settings['UserName'],$Password)

    $RequestId = [guid]::NewGuid().guid
    write-verbose ($vMsgs.requestID -f $MyInvocation.MyCommand, $RequestID)
    $RequestDate = ([datetime]::UtcNow).ToString("R")
    write-verbose ($vMsgs.requestDate -f $MyInvocation.MyCommand, $RequestDate)
    $AuthHeader = "{0} {1}" -f $settings['AuthType'], [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($credential.UserName,$credential.GetNetworkCredential().Password) -join ":"))
    $RequestHeaders = @{
        "Authorization" = $AuthHeader;
        "x-mc-app-id" = $Settings['ApplicationID'];
        "x-mc-req-id" = $RequestId;
        "x-mc-date" = $RequestDate;
        "Content-Type" = "application/json; charset=utf-8";
    };

    $RequestParams = @{
        "Uri" = ("{0}{1}" -f $Settings['BaseURL'], $Uri);
        "ContentType" = "application/json";
        "Headers" = $RequestHeaders;
        "Method" = "Post";
        "ErrorAction" = "SilentlyContinue";
    }

    $PostBody = @{"data" = ,@{"username" = $Settings['Username']}}
    $PostBodyJson = ConvertTo-Json $PostBody
    $PostBodyJson = [System.Text.Encoding]::UTF8.GetBytes($PostBodyJson)
    $RequestParams.add("Body",$PostBodyJson)
 <#
    if (($Proxy -ne $null) -and ($proxy-ne [String]::Empty))
    {
        $iwrParams.add("Proxy", $Proxy)
        if ($ProxyCredential -ne $null)
        {
            $iwrParams.add("ProxyCredential", $ProxyCredential)
        }
    }
  #> 

    foreach ($Header in $RequestHeaders.Keys)
    {
        write-verbose ($vMsgs.iwrHeaders -f $MyInvocation.MyCommand, $Header, $RequestHeaders[$Header] )
    }

    $Response = Invoke-WebRequest @requestParams -ErrorVariable iwrError
    
    if ($iwrError.Count -ne 0)
    {
        #Bummer! We encountered an error, parse it and return the information.
        if ($iwrError[0].ErrorRecord.exception -is [System.Net.WebException])
        {
            <# Get the body of the response, refer Notes [1] #>
            $Response = $iwrError.ErrorRecord.exception.response
            $StatusCode = $response.StatusCode.value__
            $RetValues.add("Headers",$Response.Headers)
            $RetValues.add("StatusCode",$Response.StatusCode.value__)
            $Stream = $Response.GetResponseStream()
            $SR = New-Object System.IO.StreamReader($Stream)
            $SR.BaseStream.Position = 0
            $SR.DiscardBufferedData()
            $ErrResponse = $SR.ReadToEnd()
            Write-Verbose ($vMsgs.exceptionStatus -f $MyInvocation.MyCommand, $RetValues.StatusCode)
            Write-Verbose ($vMsgs.exceptionContent -f $MyInvocation.MyCommand, $ErrResponse)
            if ($Response.headers["Content-Type"] -eq "application/json")
            {
                $RetValues.add("Output", (ConvertFrom-Json $ErrResponse))
            }
            else
            {
                $RetValues.add("Response", $ErrResponse)
            }

        }
    }
    else
    {
        Write-Verbose ($vMsgs.iwrStatus -f $MyInvocation.MyCommand, $Response.StatusCode)
        Write-Verbose ($vMsgs.iwrContent -f $MyInvocation.MyCommand, $Response.Content)
        $RetValues.Add("StatusCode",$Response.StatusCode)
        $RetValues.Add("Headers",$Response.Headers)
        $RetValues.Add("Output",(ConvertFrom-Json  $Response.content))
    }

    if ($RetValues.StatusCode -eq 200)
    {
        $settings['secretKey'] = $RetValues.Output.data.secretKey
        Write-Verbose ($vMsgs.updateSettings -f $MyInvocation.MyCommand, 'secretkey', $RetValues.Output.data.secretKey)
        $settings['accessKey'] = $RetValues.Output.data.accessKey
        Write-Verbose ($vMsgs.updateSettings -f $MyInvocation.MyCommand, 'accesskey', $RetValues.Output.data.accessKey)
        $settings['APIKeyExpiry'] = ([datetime]::UtcNow).AddMilliseconds($RetValues.Output.data.duration)
        Write-Verbose ($vMsgs.updateSettings -f $MyInvocation.MyCommand, 'APIKeyExpiry', ([datetime]::UtcNow).AddMilliseconds($RetValues.Output.data.duration))
    }
    write-output ($RetValues)
}
