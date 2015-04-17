data localizedData {
# culture="en-US"
ConvertFrom-StringData @'
InvalidWebUriError=Specified URI is not valid: '{0}'. Only http and https paths are accepted.
InvalidDestinationPathSchemeError=Specified DestinationPath is not valid: '{0}'. DestinationPath should be an absolute path.
DestinationPathParentNotExistsError=Specified DestinationPath is not valid: '{0}'. DestinationPath's parent should exist.
DestinationPathIsExistingDirectoryError=Specified DestinationPath is not valid: '{0}'. DestinationPath should not point to a file - not an existing directory.
DestinationPathIsUncError=Specified DestinationPath is not valid: '{0}'. DestinationPath should be local path instead of UNC path.
Downloading = Downloading: {0}
DownloadStatus = {0:N0} of {1:N0} bytes ({2} %).
'@
}

# The Get-TargetResource function is used to fetch the status of file specified in DestinationPath on the target machine.
function Get-TargetResource {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param (
		[Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $DestinationPath,
		[Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Uri,
        [Parameter()] [AllowNull()] [System.String] $Checksum
        ##TODO: Support Headers and UserAgent
	)   

    # Check whether DestinationPath is existing file
    $isFileExists = $false;
    $pathItemType = GetPathItemType -Path $DestinationPath;
    switch ($pathItemType) {
        'File' {
            Write-Debug "DestinationPath: '$DestinationPath' already exists";
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
    
    $returnValue = @{
        DestinationPath = $DestinationPath;
        Uri = $Uri;
        Checksum = $md5Checksum;
        Ensure = $ensure; 
    }
    return $returnValue;

} #end function Get-TargetResource

# The Test-TargetResource function is used to validate if the DestinationPath exists on the machine.
function Test-TargetResource {
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $DestinationPath,
		[Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Uri,		
		[Parameter()] [System.Management.Automation.PSCredential] $Credential,
        [Parameter()] [AllowNull()] [System.String] $Checksum
	)

    # Remove Credentials from parameters as it is not parameter of Get-TargetResource function
    [ref] $null = $PSBoundParameters.Remove("Credential");
    $resource = Get-TargetResource @PSBoundParameters;

    if ([System.String]::IsNullOrEmpty($Checksum) -and (Test-Path -Path $DestinationPath -PathType Leaf)) {
        return $true;
    }
    elseif ($Checksum -eq $resource.Checksum) {
        return $true;
    }
    return $false;
} #end function Test-TargetResource

function Set-TargetResource {
    [CmdletBinding()]
	param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $DestinationPath,
		[Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Uri,		
		[Parameter()] [System.Management.Automation.PSCredential] $Credential,
        [Parameter()] [AllowNull()] [System.String] $Checksum
	)
    
    # Validate Uri
    if (-not (CheckUriScheme -Uri $Uri -scheme 'http') -and -not (CheckUriScheme -Uri $Uri -Scheme 'https')) {
        $errorMessage = $LocalizedData.InvalidWebUriError -f $Uri; 
        ThrowInvalidDataException -ErrorId 'UriValidationFailure' -ErrorMessage $errorMessage;
    }

    # Validate DestinationPath scheme
    if (-not (CheckUriScheme -Uri $DestinationPath -Scheme 'file')) {
        $errorMessage = $($LocalizedData.InvalidDestinationPathSchemeError) -f $DestinationPath;
        ThrowInvalidDataException -ErrorId 'DestinationPathSchemeValidationFailure' -ErrorMessage $errorMessage;
    }

    # Validate DestinationPath is not UNC path
    if ($DestinationPath.StartsWith('\\')) { 
        $errorMessage = $($LocalizedData.DestinationPathIsUncError) -f $DestinationPath;
        ThrowInvalidDataException -ErrorId 'DestinationPathIsUncFailure' -ErrorMessage $errorMessage;
    }

    # Validate DestinationPath's parent directory exists
    $destinationPathParent = Split-Path -Path $DestinationPath -Parent;
    if (-not (Test-Path $destinationPathParent)) {
        $errorMessage = $($LocalizedData.DestinationPathParentNotExistsError) -f $DestinationPath;
        ThrowInvalidDataException -ErrorId 'DestinationPathParentNotExistsFailure' -ErrorMessage $errorMessage;
    }

    # Validate DestinationPath's leaf is not an existing folder
    if (Test-Path -Path $DestinationPath -PathType Container) {
        $errorMessage = $($LocalizedData.DestinationPathIsExistingDirectoryError) -f ${DestinationPath} 
        ThrowInvalidDataException -ErrorId 'DestinationPathIsExistingDirectoryFailure' -ErrorMessage $errorMessage;
    }

    Write-Verbose "Downloading '$Uri' to '$DestinationPath'";
    $PSBoundParameters.Remove('Checksum')
    InvokeWebClientDownload @PSBoundParameters;
    ## Create the checksum file for future reference
    $checksumPath = '{0}.md5' -f $DestinationPath;
    $fileHash = Get-FileHash -Path $DestinationPath -Algorithm MD5 -ErrorAction Stop | Select-Object -ExpandProperty Hash;
    Write-Verbose "Writing checksum '$fileHash' to file '$checksumPath'";
    $fileHash | Set-Content -Path $checksumPath -Force;
    
} #end function Set-TargetResource

#region Private Functions

function InvokeWebClientDownload {
    param (
        [Parameter(Mandatory)] [System.String] $DestinationPath,
        [Parameter(Mandatory)] [System.String] $Uri,
        [Parameter()] [AllowNull()] [System.Management.Automation.PSCredential] $Credential
    )
    try {
        [System.Net.WebClient] $webClient = New-Object -TypeName 'System.Net.WebClient';
        $webClient.Proxy = [System.Net.WebRequest]::GetSystemWebProxy();
        if ($Credential) {
            $webClient.Credentials = $Credential;
            $webClient.Proxy.Credentials = $Credential;
        }
        else {
            $webClient.UseDefaultCredentials = $true;
            $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials;
        }
        [System.IO.Stream] $inputStream = $webClient.OpenRead($Uri);
        [System.UInt32] $contentLength = $webClient.ResponseHeaders['Content-Length'];
        $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath);
        [System.IO.Stream] $outputStream = [System.IO.File]::Create($path);
        [System.Byte[]] $buffer = New-Object System.Byte[] 4096;
        [System.UInt32] $bytesRead = 0;
        [System.UInt32] $totalBytes = 0;
        do {
            $bytesRead = $inputStream.Read($buffer, 0, $buffer.Length);
            $totalBytes += $bytesRead;
            $outputStream.Write($buffer, 0, $bytesRead);
            ## Avoid divide by zero
            if ($contentLength -gt 0) {
                [System.Byte] $percentComplete = ($totalBytes/$contentLength)*100;
                Write-Progress -Activity ($localizedData.Downloading -f $uri) -PercentComplete $percentComplete -Status ($localizedData.DownloadStatus -f $totalBytes, $contentLength, $percentComplete);
            }
        }
        while ($bytesRead -ne 0)
        $outputStream.Close();
    }
    catch {
        throw "InvokeWebClientDownload failed. $_";
    }
    finally {
        if ($null -ne $outputStream) { $outputStream.Close(); }
        if ($null -ne $inputStream) { $inputStream.Close(); }
        if ($null -ne $webClient) { $webClient.Dispose(); }
    }
} #end function InvokeWebClientDownload

# Gets type of the item which path points to. 
# Returns: File, Directory, Other or NotExists
# Credit - adapted from the MSFT_xRemoteFile resource
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
# Credit - adapted from the MSFT_xRemoteFile resource
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

#endregion Private Functions
