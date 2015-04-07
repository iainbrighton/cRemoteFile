data localizedData {
# culture="en-US"
ConvertFrom-StringData @'
AWSPowerShellModuleNotFoundError=The AWS Powershell module cannot be found. Ensure the AWS PowerShell Tools for PowerShell are installed and discoverable.
InvalidDestinationPathSchemeError=Specified DestinationPath is not valid: "{0}". DestinationPath should be absolute path.
DestinationPathParentNotExistsError=Specified DestinationPath is not valid: "{0}". DestinationPath's parent should exist.
DestinationPathIsExistingDirectoryError=Specified DestinationPath is not valid: "{0}". DestinationPath should not point to the existing directory.
DestinationPathIsUncError=Specified DestinationPath is not valid: "{0}". DestinationPath should be local path instead of UNC path.
'@
}

# The Get-TargetResource function is used to fetch the status of file specified in DestinationPath on the target machine.
function Get-TargetResource {
    [CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $DestinationPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Region,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $BucketName,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Key,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Checksum
    )

    # Check whether DestinationPath is existing file
    $isFileExists = $false;
    $pathItemType = GetPathItemType -Path $DestinationPath;
    switch ($pathItemType) {
        'File' {
            Write-Debug "DestinationPath: '$DestinationPath' already exists - comparing checksum";
            $checksumPath = '{0}.md5' -f $DestinationPath;
            if (-not (Test-Path -Path $checksumPath)) {
                ## As it can take a long time to calculate the checksum, write it out to disk for future reference
                Write-Debug "Destination file exists without checksum?! Creating checksum '$checksumPath' file";
                $fileHash = Get-FileHash -Path $DestinationPath -Algorithm MD5 -ErrorAction Stop | Select-Object -ExpandProperty Hash;
                Write-Verbose "Writing checksum '$fileHash' to file '$checksumPath'";
                $fileHash | Set-Content -Path $checksumPath -Force;
            }
            
            Write-Verbose "Looking for '$checksumPath' MD5 checksum file";
            if (Test-Path -Path $checksumPath) {
                Write-Debug "MD5 checksum file '$checksumPath' found";
                $md5Checksum = (Get-Content -Path $checksumPath -Raw).Trim();
                Write-Debug "Discovered MD5 checksum '$md5Checksum'";
                if ($md5Checksum -eq $Checksum) {
                    Write-Verbose "Checksum matches specified '$Checksum' checksum";
                    $isFileExists = $true;
                }
                else {
                    Write-Verbose "Checksum does not match specified '$Checksum' checksum";
                }
            }
            else {
                Write-Debug "MD5 checksum file '$checksumPath' not found";
            }
        }
        'Directory' {
            # We expect DestinationPath to point to a file. Therefore fileExists should be false even if it exists but is directory.
            Write-Debug "DestinationPath: '$DestinationPath' is existing directory on the machine although should be file";
        }
        'NotExists' {
            Write-Debug "DestinationPath: '$DestinationPath' doesn't exist on the machine";
        }
        Default {
            Write-Debug "DestinationPath: '$DestinationPath' has unknown type: '$pathItemType'";
        }
    } #end switch pathItemType
    
    $ensure = 'Absent';
    if ($isFileExists) {
        $ensure = 'Present';
    }
    $returnValue = @{
        DestinationPath = $DestinationPath;
        Region = $Region;
        BucketName = $BucketName;
        Key = $Key;
        Checksum = $md5Checksum;
        Ensure = $ensure; 
    }
    return $returnValue;

} #end function Get-TargetResource

# The Set-TargetResource function is used to download file found under Uri location to DestinationPath
# Additional parameters can be specified to configure web request
function Set-TargetResource {
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $DestinationPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Region,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $BucketName,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Key,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Checksum,
        [Parameter()] [System.Management.Automation.PSCredential] $Credential
	)

    # Validate DestinationPath scheme
    if (-not (CheckUriScheme -Uri $DestinationPath -Scheme 'file')) {
        $errorMessage = $($LocalizedData.InvalidDestinationPathSchemeError) -f $DestinationPath;
        Throw-InvalidDataException -ErrorId "DestinationPathSchemeValidationFailure" -ErrorMessage $errorMessage;
    }

    # Validate DestinationPath is not UNC path
    if ($DestinationPath.StartsWith("\\")) { 
        $errorMessage = $($LocalizedData.DestinationPathIsUncError) -f $DestinationPath;
        Throw-InvalidDataException -ErrorId "DestinationPathIsUncFailure" -ErrorMessage $errorMessage;
    }

    # Validate DestinationPath's parent directory exists
    $destinationPathParent = Split-Path $DestinationPath -Parent;
    if (-not (Test-Path $destinationPathParent)) {
        $errorMessage = $($LocalizedData.DestinationPathParentNotExistsError) -f $DestinationPath;
        Throw-InvalidDataException -ErrorId "DestinationPathParentNotExistsFailure" -ErrorMessage $errorMessage;
    }

    # Validate DestinationPath's leaf is not an existing folder
    if (Test-Path $DestinationPath -PathType Container) {
        $errorMessage = $($LocalizedData.DestinationPathIsExistingDirectoryError) -f ${DestinationPath} 
        Throw-InvalidDataException -ErrorId "DestinationPathIsExistingDirectoryFailure" -ErrorMessage $errorMessage;
    }

    # Validate that the AWS Powershell module is installed/discoverable.
    $awsToolsPath = "$env:ProgramFiles\AWS Tools\PowerShell\AWSPowerShell";
    if ([System.Environment]::Is64BitOperatingSystem) {
        $awsToolsPath = "${env:ProgramFiles(x86)}\AWS Tools\PowerShell\AWSPowerShell";
    }
    $awsToolsManifestPath = Join-Path -Path $awsToolsPath -ChildPath 'AWSPowerShell.psd1';
    if (-not (Test-Path -Path $awsToolsManifestPath)) {
        $errorId = "ModuleNotFound"; 
        $errorMessage = $LocalizedData.AWSPowerShellModuleNotFoundError;
        ThrowInvalidOperationException -ErrorId $errorId -ErrorMessage $errorMessage;
    }
    
    try {
        Import-Module -Name $awsToolsManifestPath -Force -ErrorAction Stop -Verbose:$false -Debug:$false;
        $readS3ObjectParams = @{
            Region = $Region;
            AccessKey = $Credential.UserName;
            SecretKey = $Credential.GetNetworkCredential().Password;
            BucketName = $BucketName;
            Key = $Key;
            File = $DestinationPath;
        }
        Write-Verbose "Downloading S3 file '$BucketName\$Key'";
        [ref] $null = Read-S3Object @readS3ObjectParams -ErrorAction Stop;
        $checksumPath = '{0}.md5' -f $DestinationPath;
        $fileHash = Get-FileHash -Path $DestinationPath -Algorithm MD5 -ErrorAction Stop | Select-Object -ExpandProperty Hash;
        Write-Verbose "Writing checksum '$fileHash' to file '$checksumPath'";
        $fileHash | Set-Content -Path $checksumPath -Force;
    }
    catch {
        throw "Set-TargetResouce failed. $_";
    }

} #end function Set-TargetResource

# The Test-TargetResource function is used to validate if the DestinationPath exists on the machine.
function Test-TargetResource {
    [CmdletBinding()]
	[OutputType([System.Boolean])]
	param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $DestinationPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Region,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $BucketName,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Key,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Checksum,
        [Parameter()] [System.Management.Automation.PSCredential] $Credential
	)

    # Remove Credentials from parameters as it is not parameter of Get-TargetResource function
    [ref] $null = $PSBoundParameters.Remove("Credential");
    $resource = Get-TargetResource @PSBoundParameters;
    if ($Checksum -eq $resource.Checksum) {
        return $true;
    }
    else {
        return $false;
    }
    ##TODO: What about ensure?!

} #end function Test-TargetResource

#region Private Functions

# Gets type of the item which path points to. 
# Returns: File, Directory, Other or NotExists
function GetPathItemType {
    param (
        [Parameter(Mandatory)] [System.String] $Path
    )
    $pathType = $null;
    if (Test-Path $Path) {
        $pathItem = Get-Item $Path;
        $pathItemType = $pathItem.GetType().Name;
        if ($pathItemType -eq "FileInfo") {
            $pathType = "File";
        }
        elseif ($pathItemType -eq "DirectoryInfo") {
            $pathType = "Directory";
        }
        else {
            $pathType = "Other";
        }
    }
    else  {
        $pathType = "NotExists";
    }
    return $pathType
} #end function GetPathItemType

# Checks whether given URI represents specific scheme
# Most common schemes: file, http, https, ftp
# We can also specify logical expressions like: [http|https]
function CheckUriScheme {
    param (
        [Parameter(Mandatory)] [System.String] $Uri,
        [Parameter(Mandatory)] [System.String] $Scheme
    )
    $newUri = $Uri -as [System.URI];
    return $newUri.AbsoluteURI -ne $null -and $newUri.Scheme -match $Scheme;
}

# Throws terminating error of category InvalidData with specified errorId and errorMessage
function ThrowInvalidDataException {
    param(
        [Parameter(Mandatory)] [System.String] $ErrorId,
        [Parameter(Mandatory)] [System.String] $ErrorMessage
    )
    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidData;
    $exception = New-Object -TypeName 'System.InvalidOperationException' -ArgumentList $ErrorMessage;
    $errorRecord = New-Object -TypeName 'System.Management.Automation.ErrorRecord' -ArgumentList $exception, $ErrorId, $errorCategory, $null;
    throw $errorRecord;
}

# Throws terminating error of category InvalidOperation with specified errorId and errorMessage
function ThrowInvalidOperationException {
    param(
        [Parameter(Mandatory)] [System.String] $ErrorId,
        [Parameter(Mandatory)] [System.String] $ErrorMessage
    )
    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation;
    $exception = New-Object -TypeName 'System.InvalidOperationException' -ArgumentList $ErrorMessage;
    $errorRecord = New-Object -TypeName 'System.Management.Automation.ErrorRecord' -ArgumentList $exception, $ErrorId, $errorCategory, $null;
    throw $errorRecord;
}

#endregion Private Functions

Export-ModuleMember -Function *-TargetResource;
