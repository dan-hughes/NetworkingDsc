[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Suppressing this rule because Script Analyzer does not understand Pester syntax.')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }

    <#
        Need to define that variables here to be used in the Pester Discover to
        build the ForEach-blocks.
    #>
    $script:dscResourceFriendlyName = 'DnsServerAddress'
    $script:dscResourceName = "DSC_$($script:dscResourceFriendlyName)"
}

BeforeAll {
    # Need to define the variables here which will be used in Pester Run.
    $script:dscModuleName = 'NetworkingDsc'
    $script:dscResourceFriendlyName = 'DnsServerAddress'
    $script:dscResourceName = "DSC_$($script:dscResourceFriendlyName)"

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:dscModuleName `
        -DSCResourceName $script:dscResourceName `
        -ResourceType 'Mof' `
        -TestType 'Integration'

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')
}

AfterAll {
    # Remove module common test helper.
    Get-Module -Name 'CommonTestHelper' -All | Remove-Module -Force

    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Describe 'DnsServerAddress Integration Tests' {
    BeforeAll {
        # Configure Loopback Adapter
        New-IntegrationLoopbackAdapter -AdapterName 'NetworkingDscLBA'

        $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:dscResourceName)_Static.config.ps1"
        . $configFile
    }

    AfterAll {
        # Remove Loopback Adapter
        Remove-IntegrationLoopbackAdapter -AdapterName 'NetworkingDscLBA'
    }

    Describe "$($script:dscResourceName)_Integration using single address" {
        AfterEach {
            Wait-ForIdleLcm
        }

        It 'Should compile and apply the MOF without throwing' {
            {
                # This is to pass to the Config
                $configData = @{
                    AllNodes = @(
                        @{
                            NodeName       = 'localhost'
                            InterfaceAlias = 'NetworkingDscLBA'
                            AddressFamily  = 'IPv4'
                            Address        = '10.139.17.99'
                            Validate       = $False
                        }
                    )
                }

                & "$($script:dscResourceName)_Config_Static" `
                    -OutputPath $TestDrive `
                    -ConfigurationData $configData
                Start-DscConfiguration -Path $TestDrive `
                    -ComputerName localhost -Wait -Verbose -Force
            } | Should -Not -Throw
        }

        It 'Should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should have set the resource and all the parameters should match' {
            $current = Get-DscConfiguration | Where-Object -FilterScript {
                $_.ConfigurationName -eq "$($script:dscResourceName)_Config_Static"
            }

            $current.InterfaceAlias             | Should -Be 'NetworkingDscLBA'
            $current.AddressFamily              | Should -Be 'IPv4'
            $current.Address.Count              | Should -Be 1
            $current.Address                    | Should -Be '10.139.17.99'
        }
    }

    Describe "$($script:dscResourceName)_Integration using two addresses" {
        AfterEach {
            Wait-ForIdleLcm
        }

        It 'Should compile and apply the MOF without throwing' {
            {
                # This is to pass to the Config
                $configData = @{
                    AllNodes = @(
                        @{
                            NodeName       = 'localhost'
                            InterfaceAlias = 'NetworkingDscLBA'
                            AddressFamily  = 'IPv4'
                            Address        = @('10.139.17.99', '10.139.17.100')
                            Validate       = $False
                        }
                    )
                }

                & "$($script:dscResourceName)_Config_Static" `
                    -OutputPath $TestDrive `
                    -ConfigurationData $configData
                Start-DscConfiguration `
                    -Path $TestDrive `
                    -ComputerName localhost `
                    -Wait `
                    -Verbose `
                    -Force
            } | Should -Not -Throw
        }

        It 'Should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should have set the resource and all the parameters should match' {
            $current = Get-DscConfiguration | Where-Object -FilterScript {
                $_.ConfigurationName -eq "$($script:dscResourceName)_Config_Static"
            }

            $current.InterfaceAlias             | Should -Be 'NetworkingDscLBA'
            $current.AddressFamily              | Should -Be 'IPv4'
            $current.Address.Count              | Should -Be 2
            $current.Address[0]                 | Should -Be '10.139.17.99'
            $current.Address[1]                 | Should -Be '10.139.17.100'
        }
    }

    Describe "$($script:dscResourceName)_Integration using no addresses" {
        BeforeAll {
            $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:dscResourceName)_DHCP.config.ps1"
            . $configFile -Verbose -ErrorAction Stop
        }

        AfterEach {
            Wait-ForIdleLcm
        }

        It 'Should compile and apply the MOF without throwing' {
            {
                # This is to pass to the Config
                $configData = @{
                    AllNodes = @(
                        @{
                            NodeName       = 'localhost'
                            InterfaceAlias = 'NetworkingDscLBA'
                            AddressFamily  = 'IPv4'
                        }
                    )
                }

                & "$($script:dscResourceName)_Config_DHCP" `
                    -OutputPath $TestDrive `
                    -ConfigurationData $configData
                Start-DscConfiguration `
                    -Path $TestDrive `
                    -ComputerName localhost `
                    -Wait `
                    -Verbose `
                    -Force
            } | Should -Not -Throw
        }

        It 'Should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should have set the resource and all the parameters should match' {
            $current = Get-DscConfiguration | Where-Object -FilterScript {
                $_.ConfigurationName -eq "$($script:dscResourceName)_Config_DHCP"
            }

            $current.InterfaceAlias             | Should -Be 'NetworkingDscLBA'
            $current.AddressFamily              | Should -Be 'IPv4'
            $current.Address.Count              | Should -Be 0
            $current.Address                    | Should -BeNullOrEmpty
        }
    }
}
