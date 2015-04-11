## Dot source all (nested) .ps1 files in the , excluding tests
$moduleRoot = Split-Path -Parent $PSCommandPath;
Get-ChildItem -Path $moduleRoot -Exclude '*.Tests.ps1','*.psm1','*.mof' |
    ForEach-Object {
        Write-Verbose ('Dot sourcing ''{0}''.' -f $_.FullName);
        . $_.FullName;
    }

Export-ModuleMember -Function *-TargetResource;
