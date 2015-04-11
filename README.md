Included DSC Resources
======================
* cRemoteFile
* cS3RemoteFile

These custom Desired State Configuration (DSC) resources utilise .NET stream objects and overcome the OutOfMemoryException errors incurred by the in-built Invoke-WebRequest or Read-S3Object Powershell cmdlets.

cRemoteFile
===========
By default, the [MSFT_xRemoteFile](https://gallery.technet.microsoft.com/xPSDesiredStateConfiguratio-417dc71d) will not check
that a file has already been download during the Test-TargetResource pass. The cRemoteFile resource will __only__ download a
file if it's not present or the MD5 checksum is different/incorrect.
###Syntax
```
cRemoteFile [string]
{
    DestinationPath = [string]
    Uri = [string]
    [Checksum = [string]]
    [Credential = [PSCredential]]
```
###Properties
* DestinationPath: Fully-qualified path under which downloaded file should be accessible after operation.
* Uri: HTTP/HTTPS location fo the file which should be downloaded.
* Checksum: The optional MD5 checksum used to verify the local file.
* Credential: Specifies optional credential of a user which has permissions to send the request.

###Configuration
```
Configuration cRemoteFileExample {
    Import-DscResource -ModuleName cRemoteFile
    cRemoteFile MyExampleFile {
        DestinationPath = 'C:\Resources\output.txt'
        Uri = 'http://uri_to_download_from.com/example.txt'
        Checksum = '4767B1052744A0469348BAF3406DA944'
    }
}
```

cS3RemoteFile
=============
The cS3RemoteFile resource can download a private Amazon Web Services file from S3 - complete with a MD5 checksum.
This resource is handy for files/resources that cannot be made publically available due to electronic distribution rights restrictions.
__This DSC resource requires the [AWS Powershell Tools](http://aws.amazon.com/powershell/) to already be installed on the system executing this resource (obviously the cRemoteFile resource could be used to download the file for installation).__
###Syntax
```
cS3RemoteFile [string]
{
    DestinationPath = [string]
    Region = [string]
    BucketName = [string]
    Key = [string]
    Credential = [PSCredential]
    [Checksum = [string]]
```
###Properties
* DestinationPath: Fully-qualified path under which downloaded file should be accessible after operation.
* Region: AWS S3 region end-point containing the resource to download.
* BucketName: AWS S3 bucket name containing the resource to download.
* Key: AWS S3 resource key/name to download.
* Credential: Specifies AWS credential of a user which has permissions to send the request. The Credential object property username must be the AWS Access Key and the password the AWS Key Secret.
* Checksum: The optional MD5 checksum used to verify the local file.

###Configuration
```
Configuration cS3RemoteFileExample {
    Import-DscResource -ModuleName cRemoteFile
    cS3RemoteFile MyExampleS3File {
        DestinationPath = 'C:\Resources\output.txt'
        Region = 'eu-central-1'
        BucketName = 'MyAwsS3Bucket'
        Key = 'example.txt'
        Credential = (Get-Credential -Credential 'MyAwsAccessKey')
        Checksum = '4767B1052744A0469348BAF3406DA944'
    }
}
```
__Note: to download publically accessible AWS S3 files use the cRemoteFile resource instead.__
