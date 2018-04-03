<#
.SYNOPSIS
  Executes a mimecast API request.

.DESCRIPTION
  Executes a mimecast API request.

.PARAMETER Settings
  The settings hashtable created with either of the new-config or get-config
  functions.

.PARAMETER Uri
  The mimecast API endpoint.

.PARAMETER body
  The body of the request.

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
  Creation Date:  9/2/2016
  Purpose/Change: Initial script development
  References
    [1] How to get Powershell Invoke-Restmethod to return body of http 500 code response. (2013, September 12). Retrieved December 18, 2016, from http://stackoverflow.com/questions/18771424/how-to-get-powershell-invoke-restmethod-to-return-body-of-http-500-code-response

.EXAMPLE
  invoke-MimecastAPI

#>
function Invoke-MimecastAPI
{
    [cmdletBinding(DefaultParameterSetName="All")]
    Param(
        [parameter(Mandatory= $true)]
        [HashTable]$Settings,

        [parameter(Mandatory= $true)]
        [String]$Uri,

        [parameter(Mandatory= $true)]
        [string] $Body,
       
        [parameter(Mandatory= $true,
         ParameterSetName="Proxy")]
        [String]$Proxy,
        
        [parameter(Mandatory= $false,
         ParameterSetName="Proxy")]
        [PSCredential]$ProxyCredential
    )            
    
    $RetValues = @{}  #Holds our return values.
    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)

    <#
        Mimecast requires a unique ID for each call.  It's used in the
        x-mc-req-id header. I assume that's to help prevent replay attacks.
        You need the request if you want Mimecast to check their logs.
        Ref - Authorization, https://community.mimecast.com/docs/DOC-1809
    #>
    $RequestId = [guid]::NewGuid().guid
    write-verbose ($vMsgs.requestID -f $MyInvocation.MyCommand, $RequestID)
   
    <#
        Mimecast API requires an x-mc-date date header in RFC1123 format.
        x-mc-req-id header. I assume that's to help prevent replay and MITM
        attacks. It also forms part of the signature that is used in the
        Authorization header and is a bit like a cryptographic nonce.
    #>
    $RequestDate = ([datetime]::UtcNow).ToString("R")
    write-verbose ($vMsgs.requestDate -f $MyInvocation.MyCommand, $RequestDate)
    
    <#
        Sign the data used in the Authorisation header. The value is the
        hash-based message authentication code (HMAC-SHA1) of the concatenation
        of the request date, request ID, API endpoint URI and the application key
        with a`:' separator between values. The signed data is then base64 encoded.
    #>
    $HashMessage = @($RequestDate,$RequestId,$Uri,$Settings['applicationKey']) -join ":"
    $Sig = get-Signature -key $Settings['SecretKey'] -message $HashMessage
    Write-Verbose ($vMsgs.b64Hash -f $MyInvocation.MyCommand, $Sig)

    <#
        Mimecast requires an Authorization header with a value of the
        {realm} {accessKey}:{Base64 encoded signed Data To Sign} where realm is MC,
        accesskey is the user's accesskey. The base64 encoded signed data comes
        from the get-signature function.
    #>
    $Signature = "MC {0}:{1}" -f $Settings['AccessKey'], $Sig.trim()
    Write-Verbose ($vMsgs.signature -f $MyInvocation.MyCommand, $Signature)
 
    $RequestHeaders = @{
                        "Authorization" = $Signature;
                        "x-mc-app-id" = $Settings['applicationID'];
                        "x-mc-req-id" = $RequestId;
                        "x-mc-date" = $RequestDate;
                        "Content-Type" = "application/json; charset=utf-8";
                       }

    #Mimecast  APi is expecting UTF-8 encoding for everything.
    $PostBody = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $iwrParams = @{
                    "Method" = "Post";
                    "Uri" = ("{0}{1}" -f $Settings['BaseUrl'],$uri);
                    "Body" = $PostBody;
                    "Headers" = $RequestHeaders;
                    "ErrorAction" = "SilentlyContinue";
                  }
    
    if (($Proxy -ne $null) -and ($Proxy -ne [String]::Empty))
    {
        $iwrParams.add("Proxy", $Proxy)
        if ($ProxyCredential -ne $null)
        {
            $iwrParams.add("ProxyCredential", $ProxyCredential)
        }
    }

    foreach ($Header in $RequestHeaders.Keys)
    {
        write-verbose ($vMsgs.iwrHeaders -f $MyInvocation.MyCommand, $Header, $RequestHeaders[$Header])
    }

    $Response = Invoke-WebRequest @iwrParams -ErrorVariable iwrError -UseBasicParsing

    if ($iwrError.Count -ne 0)
    {
        #Bummer! We encountered an error, parse it if possible and return the information.
        if ($iwrError[0].ErrorRecord.exception -is [System.Net.WebException])
        {
            <# Get the body of the response, refer Notes [1] #>
            [System.Net.HttpWebResponse]$Response = $iwrError.ErrorRecord.Exception.Response
            $stream = $response.GetResponseStream()
            $SR = New-Object System.IO.StreamReader($stream)
            $SR.BaseStream.Position = 0
            $SR.DiscardBufferedData()
            $ErrResponse = $SR.ReadToEnd()
            $RetValues.add("Headers",$Response.Headers)
            $RetValues.add("StatusCode",$Response.StatusCode.value__)

            Write-Verbose ($vMsgs.exceptionStatus -f $MyInvocation.MyCommand, $RetValues.StatusCode)
            Write-Verbose ($vMsgs.exceptionContent -f $MyInvocation.MyCommand, $ErrResponse)
            if ($Response.headers["Content-Type"] -eq "application/json")
            {
                $RetValues.add("Output", (ConvertFrom-Json  $ErrResponse))
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
        if ($Response.headers["Content-Type"] -eq "application/json")
        {
            $RetValues.add("Output", (ConvertFrom-Json  $Response.content))
        }
        else
        {
            $RetValues.add("Response", $Response.Content)
        }
        $RetValues.add("StatusCode",$response.StatusCode)
        $RetValues.add("Headers",$Response.Headers)
    }
    write-output $RetValues
}
