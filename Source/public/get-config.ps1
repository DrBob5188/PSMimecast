<#
.SYNOPSIS
  Reads the PSMimecast configuration file.

.DESCRIPTION
  Reads the mimecast configuration file.

.PARAMETER path
  The path to the config file.

.INPUTS
  none

.OUTPUTS
  Hashtable of key and value pairs.

.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  1/2/2016
  Purpose/Change: Initial script development
  References: 
    Creating and Using a Configuration File for Your PowerShell Scripts. (2006, June 14).
        Retrieved February 1, 2016, from https://rkeithhill.wordpress.com/2006/06/01/creating-and-using-a-configuration-file-for-your-powershell-scripts/

.EXAMPLE
  get-config  -path "c:\mimecast\PSMimecast\PSMimecast.xml
  Retrieves the xml serialised config into a settings hashtable suitable for
  passing to other PSMimecast module functions.
#>
function get-Config
{
    [cmdletBinding()]
    Param(
        [parameter(Mandatory= $true)]
        [ValidateScript({Test-Path $_})]
        [string]$path
    )            

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'VerbosePreference'
    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)
    $appSettings = @{}
    $config = [xml](get-content $path)
    $xpath = "/configuration/appSettings/add[string-length(@key)!=0 and @value]"
    foreach ($addNode in $config.SelectNodes($xpath))
    {
        if ($addNode.Value.Contains(‘,’))
        {
            # Array case
            $value = $addNode.Value.Split(‘,’)
            for ($i = 0; $i -lt $value.length; $i++)
            { 
                $value[$i] = $value[$i].Trim() 
            }
        }
        else
        {
            # Scalar case
            $value = $addNode.Value
        }
        $appSettings[$addNode.Key] = $value
    }
    Write-Output ($appSettings)
}

#$settings = get-Config -path "C:\scripts\mimecast\PSMimecast\t5.xml"
#$settings
