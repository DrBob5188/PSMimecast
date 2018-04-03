<#
.SYNOPSIS
  Downloads and saves the Siem Logs.

.DESCRIPTION
  Executes a mimecast API request.

.PARAMETER Settings
  The settings hashtable created with either of the new-config or get-config
  functions.

.PARAMETER Uri
  The mimecast API endpoint.

.PARAMETER LogType
  The LogType to retrieve. Mimecast currently only supports MTA.

.PARAMETER LogPath
  The path to which the log files will be saved.

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
  Creation Date:  25/4/2017
  Purpose/Change: Initial script development

.EXAMPLE
  invoke-MimecastAPI

#>
function Get-SiemLogs
{
    [cmdletBinding(DefaultParameterSetName="All")]
    Param(
        [parameter(Mandatory= $true)]
        [HashTable]$Settings,

        [parameter(Mandatory= $false)]
        [String]$Uri = '/api/audit/get-siem-logs',

        [parameter(Mandatory= $false)]
        [string] $LogType = 'MTA',
       
        [parameter(Mandatory= $false)]
        [string] $LogPath = 'c:\scripts\mimecast\logs\',
       
        [parameter(Mandatory= $true,
         ParameterSetName="Proxy")]
        [String]$Proxy,
        
        [parameter(Mandatory= $false,
         ParameterSetName="Proxy")]
        [PSCredential]$ProxyCredential
    )            
    
    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)
    $PageToken = Join-Path -Path $LogPath -ChildPath 'page_token'
    $MoreLogs = $true
    do
    {
        if (Test-Path -LiteralPath $PageToken)
        {
            $logToken = Get-Content $PageToken | Out-String
            write-verbose ($vMsgs.loadToken -f $MyInvocation.MyCommand, $logToken, $PageToken)
            $body = [PSCustomObject]@{"data" = ,[PSCustomObject]@{"type" = $LogType;"token" = $logToken}}           
        }
        else
        {
            write-verbose ($vMsgs.noTokenFile -f $MyInvocation.MyCommand, $PageToken)
            $body = [PSCustomObject]@{"data" = ,[PSCustomObject]@{"type" = $LogType;}}

        }

        $postbody = ConvertTo-Json $body
        $Response = Invoke-MimecastAPI -Settings $Settings -Uri $Uri -Body $postbody -verbose
        switch ($Response.StatusCode)
        {
            429
                {
                    #Mimecast invoked rate limiting on us.
                    if ($Response.Headers['X-RateLimit-Reset'])
                    {
                        sleep -Milliseconds $Response.Headers['X-RateLimit-Reset']
                    }
                    else
                    {
                        sleep -Seconds 60
                    }
                    break
                }

            200
                {
                    if ($Response.headers["Content-Type"] -eq 'application/json')
                    {
                        #We've reached the end of the log files download
                        write-verbose ($vMsgs.noFilesLeft -f $MyInvocation.MyCommand, $response.output.meta.isLastToken)
                        $MoreLogs = $false
                    }
                    elseif ($Response.headers["Content-Type"] -eq 'application/octet-stream')
                    {
                        write-verbose ($vMsgs.saveToken -f $MyInvocation.MyCommand, $response.headers["mc-siem-token"], $PageToken)
                        Set-Content -LiteralPath $PageToken -Value $response.headers["mc-siem-token"]
                        if ($response.headers["Content-Disposition"] -match '(?:filename="([^"]+)")')
                        {
                            $fileName = join-path -Path $LogPath -ChildPath $matches[1]
                            add-Content  -path "$fileName" -Value $response.Response -Encoding Byte 
                            write-verbose ($vMsgs.saveLog -f $MyInvocation.MyCommand, $fileName)
                        } 
                        else
                        {
                            write-verbose ($vMsgs.noFilename -f $MyInvocation.MyCommand, $response.headers["Content-Disposition"])
                        }
                     }
                    else
                    {
                        write-verbose ($vMsgs.unknownContent -f $MyInvocation.MyCommand, $response.headers["Content-Type"])
                    }
                    break
                }

            default
                {
                    $MoreLogs = $false
                }
        }
    } while($MoreLogs)
    write-output $Response
}
