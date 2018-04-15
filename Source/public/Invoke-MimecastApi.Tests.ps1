
Import-Module C:\scripts\mimecast\PSMimecast\PSMimecast.psm1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

$command = Get-Command -Name Invoke-MimecastApi


InModuleScope PSMimecast {

    . "c:\scripts\mimecast\psmimecast\public\helptests.tests.ps1"
    
    Describe $command.Name {

        ## Helper functions

        if ($ShowDebugText)
        {
            Mock "Write-Debug" {
                Write-Host "       [DEBUG] $Message" -ForegroundColor Yellow
            }
        }

        function defParam($command, $name)
        {
            It "Has a -$name parameter" {
                $command.Parameters.Item($name) | Should Not BeNullOrEmpty
            }
        }

        function ShowMockInfo($functionName, [String[]] $params) {
            if ($ShowMockData)
            {
                Write-Host "       Mocked $functionName" -ForegroundColor Cyan
                foreach ($p in $params) {
                    Write-Host "         [$p]  $(Get-Variable -Name $p -ValueOnly)" -ForegroundColor Cyan
                }
            }
        }

        Context "Sanity checking" {

            defParam $command 'Settings'
            defParam $command 'Uri'
            defParam $command 'Body'
        }

        Context "Behavior testing" {

            $testUri = '/api/audit/get-siem-logs'
            $testSettings = @{
                "AccessKey"=[convert]::ToBase64String([System.text.encoding]::utf8.GetBytes("ABC123"))
                "SecretKey"=[convert]::ToBase64String([System.text.encoding]::utf8.GetBytes("DEF456"))
                "APIKEY"="keyme"
            }
            $testBody = "blah"

#            Mock -CommandName Get-Signature -MockWith {}

            Mock Invoke-WebRequest {
                ShowMockInfo 'Invoke-WebRequest' -Params 'Uri','Method'
                # if ($ShowMockData)
                # {
                #     Write-Host "       Mocked Invoke-WebRequest" -ForegroundColor Cyan
                #     Write-Host "         [Uri]     $Uri" -ForegroundColor Cyan
                #     Write-Host "         [Method]  $Method" -ForegroundColor Cyan
                # }
            }



            It "Sends the Content-Type header of application/json and UTF-8" {
                { Invoke-MimecastApi -Settings $testSettings -URI $testUri -body $testBody} | Should Not Throw
                Assert-MockCalled -CommandName Invoke-WebRequest -ParameterFilter {$Headers.Item('Content-Type') -eq 'application/json; charset=utf-8'} -Scope It
            }

            It "Uses the -UseBasicParsing switch for Invoke-WebRequest" {
                { Invoke-MimecastAPi -Settings $testSettings -URI $testUri -body $testBody} | Should Not Throw
                Assert-MockCalled -CommandName Invoke-WebRequest -ParameterFilter {$UseBasicParsing -eq $true} -Scope It
            }

        }
    }
}
