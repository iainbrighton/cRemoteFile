$here = Split-Path -Parent $MyInvocation.MyCommand.Path;
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".");
. "$here\$sut";

[System.Byte[]] $testFileBytes = @(35,32,99,82,101,109,111,116,101,70,105,108,101,10,67,111,109,109,117,110,117,105,116,121,32,80,111,119,101,114,115,104,101,108,108,32,68,101,115,105,114,101,100,32,83,116,97,116,101,32,67,111,110,102,105,103,117,114,97,116,105,111,110,32,114,101,115,111,117,114,99,101,32,116,111,32,100,111,119,110,108,111,97,100,32,114,101,109,111,116,101,32,111,114,32,65,87,83,32,83,51,32,102,105,108,101,115,32,119,105,116,104,32,97,32,99,104,101,99,107,115,117,109,10);

Describe 'cRemoteFile\Get-TargetResource' {
    $testDriveRootPath = (Get-PSDrive -Name TestDrive).Root;
    $testFilePath = "$testDriveRootPath\README.md";
    $testFileChecksum = '401093CED51779B997248EFC3C419F15';
    $resourceParams = @{
        DestinationPath = $testFilePath;
        Uri = 'https://raw.githubusercontent.com/iainbrighton/cRemoteFile/fe9f5ff66ed6b0366aaa33c25576171766499d47/README.md';
    }

    It 'Returns a hashtable.' {
        $result = Get-TargetResource @resourceParams;
        $result -is [System.Collections.Hashtable] | Should Be $true;
    }

    It 'Returns no checksum with a non-existent destination file.' {
        $result = Get-TargetResource @resourceParams;
        [System.String]::IsNullOrEmpty($result.Checksum) | Should Be $true;
    }

    It 'Creates and returns a checksum where only the destination file exists.' {
        ## Recreate source file
        $testFileBytes | Set-Content -Path $testFilePath -Encoding Byte;
        $result = Get-TargetResource @resourceParams;
        $result.Checksum | Should Be $testFileChecksum;
        Test-Path -Path "$testFilePath.md5" -PathType Leaf | Should Be $true;
    }

} #end describe Get-TargetResource

Describe 'cRemoteFile\Test-TargetResource' {
    $testDriveRootPath = (Get-PSDrive -Name TestDrive).Root;
    $testFilePath = "$testDriveRootPath\README.md";
    $testFileChecksum = '401093CED51779B997248EFC3C419F15';
    $resourceParams = @{
        DestinationPath = $testFilePath;
        Uri = 'https://raw.githubusercontent.com/iainbrighton/cRemoteFile/fe9f5ff66ed6b0366aaa33c25576171766499d47/README.md';
    }

    It 'Returns a boolean.' {
        $result = Test-TargetResource @resourceParams;
        $result -is [System.Boolean] | Should Be $true;
    }

    It 'Returns false when destination file does not exist.' {
        Test-TargetResource @resourceParams | Should Be $false;
    }

    It 'Returns false when the destination file does exist with an invalid checksum.' {
        $resourceParams['Checksum'] = $testFileChecksum;
        $testFileBytes | Set-Content -Path $testFilePath -Force;
        
        Test-TargetResource @resourceParams | Should Be $false;
    }

    It 'Returns false when the destination file does not exist, but the checksum file does exist.' {
        Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue;
        Test-TargetResource @resourceParams | Should Be $false;
    }

    It 'Returns true when the destination file does exist with no checksum specified.' {
        $resourceParams['Checksum'] = '';
        $testFileBytes | Set-Content -Path $testFilePath -Force;
        Remove-Item -Path "$testFilePath.md5" -Force -ErrorAction SilentlyContinue;
        
        Test-TargetResource @resourceParams | Should Be $true;
    }

    It 'Returns true when the destination file does exist with a missing checksum file.' {
        $resourceParams['Checksum'] = $testFileChecksum;
        $testFileBytes | Set-Content -Path $testFilePath -Encoding Byte -Force;
        Remove-Item -Path "$testFilePath.md5" -Force -ErrorAction SilentlyContinue;

        Test-TargetResource @resourceParams | Should Be $true;
    }

    It 'Returns true when the destination file does exist with a matching checksum file.' {
        $resourceParams['Checksum'] = $testFileChecksum;
        $testFileBytes | Set-Content -Path $testFilePath -Encoding Byte -Force;
        (Get-FileHash -Path $testFilePath -Algorithm MD5) | Select-Object -ExpandProperty Hash | Set-Content -Path "$testFilePath.md5" -Force;
        
        Test-TargetResource @resourceParams | Should Be $true;
    }

} #end describe Test-TargetResource

Describe 'cRemoteFile\Set-TargetResource' {
    $testDriveRootPath = (Get-PSDrive -Name TestDrive).Root;
    $testFilePath = "$testDriveRootPath\README.md";
    $testFileChecksum = '401093CED51779B997248EFC3C419F15';

    Mock -CommandName 'InvokeWebClientDownload' -Verifiable -MockWith {
        $testFileBytes | Set-Content -Path $testFilePath -Encoding Byte -Force;
    }

    It 'Invokes InvokeWebClientDownload and creates a checksum file.' {
        $resourceParams = @{
            DestinationPath = $testFilePath;
            Uri = 'https://raw.githubusercontent.com/iainbrighton/cRemoteFile/fe9f5ff66ed6b0366aaa33c25576171766499d47/README.md';
        }
        Set-TargetResource @resourceParams;
        Test-Path -Path "$testFilePath.md5" | Should Be $true;
        Assert-VerifiableMocks;
    }

    It 'Throws UriValidationFailure.' {
        $resourceParams = @{
            DestinationPath = $testFilePath;
            Uri = 'ftp://raw.githubusercontent.com/iainbrighton/cRemoteFile/fe9f5ff66ed6b0366aaa33c25576171766499d47/README.md';
        }
        { Set-TargetResouce @resourceParams } | Should Throw;
    }

    It 'Throws DestinationPathSchemeValidationFailure.' {
        $resourceParams = @{
            DestinationPath = 'file://c:/README.md';
            Uri = 'https://raw.githubusercontent.com/iainbrighton/cRemoteFile/fe9f5ff66ed6b0366aaa33c25576171766499d47/README.md';
        }
        { Set-TargetResouce @resourceParams } | Should Throw;
    }

    It 'Throws DestinationPathIsUncFailure.' {
        $resourceParams = @{
            DestinationPath = '\\server\share\README.md';
            Uri = 'https://raw.githubusercontent.com/iainbrighton/cRemoteFile/fe9f5ff66ed6b0366aaa33c25576171766499d47/README.md';
        }
        { Set-TargetResouce @resourceParams } | Should Throw;
    }

    It 'Throws DestinationPathParentNotExistsFailure.' {
        $resourceParams = @{
            DestinationPath = "$((Get-PSDrive -Name TestDrive).Root)\NonExistent\README.md";
            Uri = 'https://raw.githubusercontent.com/iainbrighton/cRemoteFile/fe9f5ff66ed6b0366aaa33c25576171766499d47/README.md';
        }
        { Set-TargetResouce @resourceParams } | Should Throw;
    }

    It 'Throws DestinationPathIsExistingDirectoryFailure.' {
        $resourceParams = @{
            DestinationPath = (Get-PSDrive -Name TestDrive).Root;
            Uri = 'https://raw.githubusercontent.com/iainbrighton/cRemoteFile/fe9f5ff66ed6b0366aaa33c25576171766499d47/README.md';
        }
        { Set-TargetResouce @resourceParams } | Should Throw;
    }

} #end describe Set-TargetResource
