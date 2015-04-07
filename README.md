# cRemoteFile
By default, the [MSFT_xRemoteFile](https://gallery.technet.microsoft.com/xPSDesiredStateConfiguratio-417dc71d) will not check
that a file has already been download during the Test-TargetResource pass. The cRemoteFile resource will __only__ download a
file if it's not present or the MD5 checksum is different/incorrect.

cRemoteFile resource has following properties:

* DestinationPath: Path under which downloaded file should be accessible after operation.
* Uri: Uri of a file which should be downloaded.
* Credential: Specifies credential of a user which has permissions to send the request.
* Checksum: MD5 checksum of the file contained at the Uri location.

#cS3RemoteFile
The cS3RemoteFile resource can download private Amazon Web Services files from S3 with a MD5 checksum.
This resource is handy for files/resources that cannot be made publically available due to electronic distribution rights restrictions.
__This DSC resource requires the [AWS Powershell Tools](http://aws.amazon.com/powershell/) to already be installed on the system executing this resource (obviously the cRemoteFile resource can be used to download the file for installation).__

cS3RemoteFile resource has the following properties:

* DestinationPath: Path under which downloaded file should be accessible after operation.
* Region: AWS region end-point to download the resource.
* BucketName: AWS S3 bucket name containing the S3 resource to download.
* Key: AWS S3 key of the S3 resource to download.
* Credential: Specifies AWS Access Key/Secret of a user which has permissions to download the S3 file.
* Checksum: MD5 checksum of the file contained in S3.

__Note: to download publically accessible AWS S3 files use the cRemoteFile resource instead.__
