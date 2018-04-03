<#
.SYNOPSIS
  Saves the PSMimecast configuration file.

.DESCRIPTION
  Saves the mimecast configuration file.

.PARAMETER path <String>
  The path to the config file.

.PARAMETER settings <hashtable>
  The key and value pairs to be persisted in the config file. 

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
  Save-Config  -path "c:\mimecast\PSMimecast\PSMimecast.xml -settings

#>

function Save-Config
{
    [cmdletBinding()]
    Param(
        [parameter(Mandatory= $true)]
        [ValidateScript({
            if (Test-Path -Path (Split-Path -Parent $_ -OutVariable Parent) -PathType Container)
            {
                $true
            }
            else
            {
                throw "'$Parent' is not a valid directory"
            }
        })]
        [string]$path,

        [parameter(Mandatory= $true)]
        [hashtable]$settings,

        [parameter(Mandatory=$false)]
        [String[]]$UnsafeKeys = ('secretKey','accessKey'),

        [parameter(Mandatory=$false)]
        [switch]$RemoveUnsafeKeys=$true
    )

    Import-LocalizedData -BindingVariable vMsgs -FileName ("{0}.psd1" -f $MyInvocation.MyCommand)
    $doc = New-Object System.Xml.XmlDocument
    $newChild = $doc.CreateElement("configuration")
    $config = $doc.AppendChild($newChild)
    $newChild = $doc.CreateElement("appSettings")
    $baseNode = $config.AppendChild($newChild)
    foreach ($key in $settings.Keys)
    {
        if ($RemoveUnsafeKeys -and ($UnsafeKeys -contains $key))
        {
            continue
        }
        write-verbose ($vMsgs.settings -f $MyInvocation.MyCommand, $key, $settings[$key])
        $node = $baseNode.SelectSingleNode("add[@key='$key']")
        if ($node -ne $null)
        {
            write-verbose ($vMsgs.nodeFound -f $MyInvocation.MyCommand, $key, $node.Attributes["value"].Value )
            $node.Attributes["value"].Value = $settings[$key]
            write-verbose ($vMsgs.nodeUpdated -f $MyInvocation.MyCommand, $key, $settings[$key] )
        }
        else
        {
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
