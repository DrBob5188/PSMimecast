# PSMimecast
### Warning
This module isn't finished or properly tested. Things like proxy support have been coded but not tested. Logging is not implemented, only verbose messages are implemented at this stage. Nevertheles you may find it useful as a starting point. The module was intended to support internationalisation, but only the verbose messages have been coded in this fashion.

###What does it do?
The module is just just a Powershell wrapper for the Mimecast API.  Not all the API endpoints have been coded but the Invoke-MimecastApi function takes care of most of the complexity of calling the mimecast API. If you need one of the uncoded api endpoints, take a look at the Mimecast developer doco and make the call with Invoke-MimecastApi.

The module defines functions new-config, save-config and get-config to manage the configuration file and settings.  The sensitive information such as user login password and api keys are encrypted using an AES 256 key.  The AES key  is encrypted using an RSA 2048 bit key before being saved to the config file.  The generation of the RSA and AES keys is done in the New-Config  function.  No crypto knowledge is required.

###Getting started
Create a mimecast account to be used for API access.  See steps 1-5 of https://community.mimecast.com/docs/DOC-2144
Load the module.

```import-module <path to module>\PSMimecast.psm1```

Create a config file, entering the email address and the password of the mimecast user account created in step 1 when prompted for a credential.
```
New-Config -path C:\mimecast\PSMimecast.xml -credential (get-credential) -verbose
```
Run the following script to login to Mimecast, obtain the API keys and save them to the settings file

```
$settings = get-config -path C:\scripts\mimecast\PSMimecast\PSMimecast.xml -Verbose
if (($settings['BaseUrl'] -eq [String]::Empty) -or ($null -eq $settings['BaseUrl']))
{
    $r = DiscoverAuthentication -Settings $settings -Verbose
    if ($r.StatusCode -eq 200)
    {
        $settings['BaseUrl'] = $r.Output.data.region.api
    }
    else
    {
        Write-Verbose ("Couldn't get the hostname of the regional api server")
        Return
    }
}

if (($settings['AuthType'] -eq [String]::Empty) -or ($null -eq $settings['AuthType']))
{
    $r = DiscoverAuthentication -Settings $settings -BaseURL $settings['BaseUrl'] -Verbose
    if ($r.StatusCode -eq 200)
    {
        $settings['AuthType'] = $r.Output.data.authenticate
    }
    else
    {
        Write-Verbose ("Couldn't get the authentication type for the user")
        Return
    }
}

if (($null -eq ($settings['APIKeyExpiry'] -as [Datetime])) -or
    (($settings['APIKeyExpiry'] -as [Datetime]) -lt [datetime]::UtcNow)
   )
{
    $r = login -Settings $settings -Verbose
    if ($r.StatusCode -ne 200)
    {
        write-verbose ("Login Failure")
        return
    }
 
}
ConvertTo-EncryptedApiKey -Settings $settings -Verbose 
Save-Config -settings $settings -Verbose -path C:\mimecast\PSMimecast\PSMimecast.xml
```
