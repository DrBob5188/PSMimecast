<#
.SYNOPSIS
  Returns the regional base URL's and supported authentication mechanisms for the given user.

.DESCRIPTION
  Calls the mimecast /api/login/discover-authentication endpoint to get the regional base url
  for further calls.

.PARAMETER Settings
  The settings hashtable created with either of the new-config or get-config
  functions.

.PARAMETER Uri
  The mimecast API endpoint.

.PARAMETER BaseUrl
  The scheme and hostname portion of the url. This is unique for each region.

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
  if the returned contenttype is application/json or
    Response = the unconverted response body.


.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  1/2/2016
  Purpose/Change: Initial script development

.EXAMPLE
  discoverAuthentication  -email dodgyemail@dodgyemail.com.au
  Returns the api host for the specified users region.

#>

function DiscoverAuthentication
{
    [cmdletBinding(DefaultParameterSetName="All")]
    Param(
        [parameter(Mandatory= $true)]
        [HashTable]$Settings,

        [parameter(Mandatory= $false)]
        [string]$Uri = "/api/login/discover-authentication",

        [parameter(Mandatory= $false)]
        [string]$BaseURL = "https://api.mimecast.com",

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
    $RequestId = [guid]::NewGuid().guid
    write-verbose ($vMsgs.requestID -f $MyInvocation.MyCommand, $RequestID)
    $RequestHeaders = @{
        "x-mc-app-id" = $Settings['applicationID'];
        "x-mc-req-id" = $RequestId;
        "Content-Type" = "application/json";
    }

    $RequestParams = @{
        "Uri" = ("{0}{1}" -f $BaseURL, $Uri);
        "ContentType" = "application/json";
        "Headers" = $RequestHeaders;
        "Method" = "Post";
        "ErrorAction" = "SilentlyContinue";
    }

    $PostBody = @{"data" = ,@{"emailAddress" = $Settings['username']}}
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
        write-verbose ($vMsgs.iwrHeaders -f $MyInvocation.MyCommand, $Header, $RequestHeaders[$Header])
    }

    $Response = Invoke-WebRequest @requestParams -ErrorVariable iwrError
    
    if ($iwrError.Count -ne 0)
    {
        #Bummer! We encountered an error, parse it and return the information.
        if ($iwrError[0].ErrorRecord.exception -is [System.Net.WebException])
        {
            $Response = $iwrError.ErrorRecord.exception.response
            $StatusCode = $response.StatusCode.value__
            $RetValues.add("Headers",$Response.Headers)
            $RetValues.add("StatusCode",$Response.StatusCode.value__)
            $RetValues.Add("Response", $Response)
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

    write-output ($RetValues)
}
