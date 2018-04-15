<#
.SYNOPSIS
  Downloads and saves the Siem Logs.

.DESCRIPTION
  Downloads the SIEM logs and saves them to the specified logpath. Mimecast
  return a paging token in the response headers that is used for bookmarking
  the last file returned. The paging token is stored in the specified log path
  in a file named page_token. If the token file is missing then the oldest logs
  available will be retrieved.

.PARAMETER Settings
  The settings hashtable created with either of the new-config or get-config
  functions.

.PARAMETER Uri
  The mimecast API endpoint to call.

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
    Content = the unconverted response body.
    Output =  PSCustomObject returned calling ConvertFrom-JSON on the
        response body if conversion from JSON was successful.

.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  25/4/2017
  Purpose/Change: Initial script development

.EXAMPLE
  Get-SiemLogs -settings $settings -logpath c:\mc-logs
  Returns all the MTA logs for the last 7 days or if a page_token file that has
  been written from a previous successful call to Get_SiemLogs then the files
  from that point are retrieved.
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
       
        [parameter(Mandatory= $true)]
        [string] $LogPath,
       
        [parameter(Mandatory= $true,
         ParameterSetName="Proxy")]
        [String]$Proxy,
        
        [parameter(Mandatory= $false,
         ParameterSetName="Proxy")]
        [PSCredential]$ProxyCredential
    )            
    
    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'VerbosePreference'
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
        $Response = Invoke-MimecastAPI -Settings $Settings -Uri $Uri -Body $postbody
        foreach ($Header in $Response.headers.Keys)
        {
            write-verbose ($vMsgs.responseHeader -f $MyInvocation.MyCommand, $Header, $Response.Headers[$Header])
        }
        switch ($Response.StatusCode)
        {
            429
                {
                    #Mimecast invoked rate limiting on us.
                    write-verbose ($vMsgs.rateLimit -f $MyInvocation.MyCommand, $Response.Headers['X-RateLimit-Reset'])
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
                        try
                        {
                            $Output = ConvertFrom-Json $Response.content
                        }
                        catch [System.ArgumentException]
                        {
                            Write-Verbose ($vMsgs.convertRetry -f $MyInvocation.MyCommand, $Uri)
                        }

                        if ($null -eq $Output)
                        {
                            #Cater for a bug in the Mimecast API where the response headers are broken by a blank line and
                            #end up in the content stream. Only affects the '/api/audit/get-siem-logs' endpoint.
                            Try
                            {
                                $Response.add("Output", (ConvertFrom-Json  ($Response.content -split "`r`n`r`n")[-1] ))
                                write-verbose ($vMsgs.noFilesLeft -f $MyInvocation.MyCommand, $Response.Output.meta.isLastToken)
                            }
                            Catch [System.ArgumentException]
                            {
                                Write-Verbose ($vMsgs.convertFail -f $MyInvocation.MyCommand, $Response.Content)
                            }
                        }
                        else
                        {
                            write-verbose ($vMsgs.noFilesLeft -f $MyInvocation.MyCommand, $Response.Output.meta.isLastToken)
                            $Response.add("Output", $Output)
                        }
                        $MoreLogs = $false
                    }
                    elseif ($Response.headers["Content-Type"] -eq 'application/octet-stream')
                    {

                        write-verbose ($vMsgs.saveToken -f $MyInvocation.MyCommand, $response.headers["mc-siem-token"], $PageToken)
                        Set-Content -LiteralPath $PageToken -Value $response.headers["mc-siem-token"]
                        if ($response.headers["Content-Disposition"] -match '(?:filename="([^"]+)")')
                        {
                            $fileName = join-path -Path $LogPath -ChildPath $Matches[1]
                            add-Content  -path "$fileName" -Value $Response.Content -Encoding Byte 
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
