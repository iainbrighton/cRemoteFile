## Dot source all (nested) .ps1 files in the , excluding tests
$moduleRoot = Split-Path -Parent $PSCommandPath;
Get-ChildItem -Path $moduleRoot -Include *.ps1 -Exclude '*.Tests.ps1' -Recurse |
    ForEach-Object {
        Write-Verbose ('Dot sourcing ''{0}''.' -f $_.FullName);
        . $_.FullName;
    }

Export-ModuleMember -Function *-TargetResource
