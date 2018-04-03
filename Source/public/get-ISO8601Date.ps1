﻿<#
.SYNOPSIS
  Formats a date into ISO8601 format.

.DESCRIPTION
  Formats a date into ISO8601 format.

.PARAMETER date <DateTime>
  The date to be converted.

.PARAMETER fractionalSeconds <switch>
  Include decimal fraction of seconds 

.PARAMETER convertToUTC <switch>
  Convert the date to UTC before formatting as a string 

.INPUTS
  none

.OUTPUTS
  System.String - The datetime formatted in ISO8601.

.NOTES
  Version:        1.0
  Author:         Robert Thomson
  Creation Date:  14/2/2016
  Purpose/Change: Initial script development

.EXAMPLE
  get-ISO8601Date  -date (get-date) -convertToUTC

#>

function Get-ISO8601Date
{
    [cmdletBinding()]
    Param(
        [parameter(Mandatory= $true)]
        [datetime]$date,
        [parameter(Mandatory= $false)]
        [switch]$fractionalSeconds,
        [parameter(Mandatory= $false)]
        [switch]$convertToUTC
    )

    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)

    Write-Verbose ($vMsgs.inputDate -f $MyInvocation.MyCommand, $date.ToString())

    if ($convertToUTC)
    {
        Write-Verbose ($vMsgs.toUTC -f $MyInvocation.MyCommand, $convertToUTC)
        $dt = $date.ToUniversalTime()
    }
    else
    {
        $dt = $date
    }

    if ($fractionalSeconds)
    {
        Write-Verbose ($vMsgs.fractional -f $MyInvocation.MyCommand, $fractionalSeconds)
        Write-Output ($dt.ToString("o"))
    }
    else
    {
        Write-Output ($dt.ToString("yyyy-MM-ddTHH:mm:sszzz"))
    }
}
