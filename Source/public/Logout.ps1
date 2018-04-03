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
  discoverAuthentication  -email dodgyemail@dodgyemail.com.au

#>

function Logout
{
    [cmdletBinding(DefaultParameterSetName="All")]
    Param(
        [parameter(Mandatory= $true)]
        [HashTable]$Settings,

        [parameter(Mandatory= $false)]
        [string]$Uri = "/api/login/logout",

        [parameter(Mandatory= $true,
         ParameterSetName="Proxy")]
        [String]$Proxy,
        
        [parameter(Mandatory= $false,
         ParameterSetName="Proxy")]
        [PSCredential]$ProxyCredential
    )            

    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)
    $PostBody = @{"data" = ,@{"accessKey" = $Settings['accessKey']}}
    $PostBodyJson = ConvertTo-Json $PostBody
    $requestParams = @{
        "Settings" = $Settings;
        "Body" = $PostBodyJson;
        "Uri" = $Uri;
    }
    write-verbose ($vMsgs.imaStart -f $MyInvocation.MyCommand, $Uri)
    $Response = Invoke-MimecastAPI @requestParams
    write-verbose ($vMsgs.imaEnd -f $MyInvocation.MyCommand, $Uri)
    if ($Response.StatusCode -eq 200)
    {
        $settings['secretKey'] = [string]::Empty
        $settings['accessKey'] = [string]::Empty
        $settings['APIKeyExpiry'] = [string]::Empty
        $settings['Encrypted-AccessKey'] = [string]::Empty
        $settings['Encrypted-SecretKey'] = [string]::Empty
    }
    write-output ($Response)
}

