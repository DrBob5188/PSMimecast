$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "get-signature" {
<#
    From RFC2202 Test Cases for HMAC-MD5 and HMAC-SHA-1
    test_case =     1
    key =           0x0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b
    key_len =       20
    data =          "Hi There"
    data_len =      8
    digest =        0xb617318655057264e28bc0b6fb378c8ef146be00
    base64 digest   thcxhlUFcmTii8C2+zeMjvFGvgA=
#>
    It "signs data using the hmac-sha1 algorithm and returns a base64 encode hash value" {
        [byte[]]$k = @(,0x0b*20)
        get-Signature -key ([System.convert]::ToBase64String($k)) -message "Hi There" | Should Be "thcxhlUFcmTii8C2+zeMjvFGvgA="
    }
<#
    From RFC2202 Test Cases for HMAC-MD5 and HMAC-SHA-1
    test_case =     2
    key =           "Jefe"
    key_len =       4
    data =          "what do ya want for nothing?"
    data_len =      28
    digest =        0xeffcdf6ae5eb2fa2d27416d5f184df9c259a7c79
    base64 digest   7/zfauXrL6LSdBbV8YTfnCWafHk=
#>
    It "signs data using the hmac-sha1 algorithm and returns a base64 encode hash value" {
        [byte[]]$k = [System.Text.Encoding]::UTF8.GetBytes("Jefe")
        get-Signature -key ([System.convert]::ToBase64String($k)) -message "what do ya want for nothing?" | Should Be "7/zfauXrL6LSdBbV8YTfnCWafHk="
    }
}
