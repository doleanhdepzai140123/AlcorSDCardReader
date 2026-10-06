[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Alcor-Windows-Report.md'),
    [string]$AcpiPath,
    [string]$PciDevicePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PnpData {
    param(
        [Parameter(Mandatory = $true)][string]$InstanceId,
        [Parameter(Mandatory = $true)][string]$KeyName
    )

    try {
        $property = Get-PnpDeviceProperty -InstanceId $InstanceId -KeyName $KeyName -ErrorAction Stop
        return @($property.Data)
    }
    catch {
        return @()
    }
}

function Convert-LocationPathToOpenCorePath {
    param([Parameter(Mandatory = $true)][string]$LocationPath)

    $pciPart = ($LocationPath -split '#USBROOT\(', 2)[0]
    $rootMatch = [regex]::Match($pciPart, '(?:^|#)PCIROOT\((?<root>[0-9A-Fa-f]+)\)')
    if (-not $rootMatch.Success) {
        return $null
    }

    $rootNumber = [Convert]::ToInt32($rootMatch.Groups['root'].Value, 16)
    $segments = [System.Collections.Generic.List[string]]::new()
    $segments.Add(('PciRoot(0x{0:x})' -f $rootNumber))

    foreach ($match in [regex]::Matches($pciPart, '(?:^|#)PCI\((?<address>[0-9A-Fa-f]{4})\)')) {
        $address = $match.Groups['address'].Value
        $device = [Convert]::ToInt32($address.Substring(0, 2), 16)
        $function = [Convert]::ToInt32($address.Substring(2, 2), 16)
        $segments.Add(('Pci(0x{0:x},0x{1:x})' -f $device, $function))
    }

    return ($segments -join '/')
}

function ConvertTo-MarkdownCell {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return 'Not reported'
    }

    return (($Value -replace '[\r\n]+', ' ') -replace '\|', '\|')
}

function Escape-XmlText {
    param([Parameter(Mandatory = $true)][string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) -or
    -not (Get-Command Get-PnpDeviceProperty -ErrorAction SilentlyContinue)) {
    throw 'The PnpDevice PowerShell cmdlets are unavailable. Run this script in Windows PowerShell 5.1 or PowerShell 7 on Windows with the PnpDevice module available.'
}

if ($AcpiPath -and ($AcpiPath -notmatch '^IOACPIPlane:/' -or $AcpiPath -match '[\r\n\x00-\x1F]')) {
    throw "AcpiPath must be a single IORegistry path beginning with 'IOACPIPlane:/'."
}

if ($PciDevicePath -and $PciDevicePath -notmatch '^PciRoot\(0x[0-9A-Fa-f]+\)(/Pci\(0x[0-9A-Fa-f]+,0x[0-9A-Fa-f]+\))*$') {
    throw 'PciDevicePath must use OpenCore format, for example PciRoot(0x0)/Pci(0x14,0x0).'
}

$devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop)
$alcorReaders = [System.Collections.Generic.List[object]]::new()
$xhciControllers = [System.Collections.Generic.List[object]]::new()

foreach ($device in $devices) {
    $instanceId = [string]$device.InstanceId
    $friendlyName = [string]$device.FriendlyName
    if ([string]::IsNullOrWhiteSpace($instanceId)) {
        continue
    }

    $isUsbDevice = $instanceId.StartsWith('USB\', [System.StringComparison]::OrdinalIgnoreCase)
    $isXhciCandidate = $friendlyName -match '(?i)xHCI|eXtensible Host Controller'
    if (-not $isUsbDevice -and -not $isXhciCandidate) {
        continue
    }

    $hardwareIds = @(Get-PnpData -InstanceId $instanceId -KeyName 'DEVPKEY_Device_HardwareIds' |
        Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) })

    $usbAlcorIds = @($hardwareIds | Where-Object { $_ -match '^USB\\VID_058F&PID_([0-9A-Fa-f]{4})' })
    if ($usbAlcorIds.Count -gt 0 -or $isXhciCandidate) {
        $locationPaths = @(Get-PnpData -InstanceId $instanceId -KeyName 'DEVPKEY_Device_LocationPaths' |
            Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) })
    }
    else {
        $locationPaths = @()
    }

    if ($usbAlcorIds.Count -gt 0) {
        $pciPaths = [System.Collections.Generic.List[string]]::new()
        foreach ($locationPath in $locationPaths) {
            $openCorePath = Convert-LocationPathToOpenCorePath -LocationPath $locationPath
            if ($openCorePath -and -not $pciPaths.Contains($openCorePath)) {
                $pciPaths.Add($openCorePath)
            }
        }

        $alcorReaders.Add([pscustomobject]@{
            Name = $friendlyName
            Status = [string]$device.Status
            HardwareIds = $usbAlcorIds
            PciPaths = @($pciPaths)
        })
    }

    if ($isXhciCandidate) {
        $pciPaths = [System.Collections.Generic.List[string]]::new()
        foreach ($locationPath in $locationPaths) {
            $openCorePath = Convert-LocationPathToOpenCorePath -LocationPath $locationPath
            if ($openCorePath -and -not $pciPaths.Contains($openCorePath)) {
                $pciPaths.Add($openCorePath)
            }
        }

        $xhciControllers.Add([pscustomobject]@{
            Name = $friendlyName
            HardwareIds = $hardwareIds
            PciPaths = @($pciPaths)
        })
    }
}

$systemModel = 'Not reported'
$windowsVersion = 'Not reported'
try {
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $modelParts = @([string]$computer.Manufacturer, [string]$computer.Model) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($modelParts.Count -gt 0) {
        $systemModel = $modelParts -join ' '
    }
}
catch { }

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $windowsVersion = '{0} (version {1}, build {2})' -f $os.Caption, $os.Version, $os.BuildNumber
}
catch { }

$readerPciPaths = @($alcorReaders | ForEach-Object { $_.PciPaths } | Where-Object { $_ } | Sort-Object -Unique)
$selectedPciPath = $null
if ($PciDevicePath) {
    $selectedPciPath = $PciDevicePath
}
elseif ($readerPciPaths.Count -eq 1) {
    $selectedPciPath = $readerPciPaths[0]
}

$fullOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [System.IO.Path]::GetDirectoryName($fullOutputPath)
if (-not [System.IO.Directory]::Exists($outputDirectory)) {
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
}

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add('# Alcor Reader Windows Preflight Report')
$reportLines.Add('')
$reportLines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')))
$reportLines.Add('')
$reportLines.Add('> This is a read-only Windows Plug and Play inventory. It does not change the registry, device configuration, OpenCore EFI, or firmware.')
$reportLines.Add('')
$reportLines.Add('## System')
$reportLines.Add('')
$reportLines.Add(('- Windows: {0}' -f (ConvertTo-MarkdownCell $windowsVersion)))
$reportLines.Add(('- Computer model: {0}' -f (ConvertTo-MarkdownCell $systemModel)))
$reportLines.Add('')
$reportLines.Add('## Alcor USB devices (VID 058F)')
$reportLines.Add('')
$reportLines.Add('| Device | Status | USB hardware ID | Derived OpenCore PCI path |')
$reportLines.Add('| --- | --- | --- | --- |')
if ($alcorReaders.Count -eq 0) {
    $reportLines.Add('| No present USB device with VID 058F was found | — | — | — |')
}
else {
    foreach ($reader in $alcorReaders) {
        $pathsText = if ($reader.PciPaths.Count -gt 0) { $reader.PciPaths -join '<br>' } else { 'Not derivable from Windows location path' }
        foreach ($hardwareId in $reader.HardwareIds) {
            $reportLines.Add(('| {0} | {1} | `{2}` | `{3}` |' -f
                (ConvertTo-MarkdownCell $reader.Name),
                (ConvertTo-MarkdownCell $reader.Status),
                (ConvertTo-MarkdownCell $hardwareId),
                $pathsText))
        }
    }
}
$reportLines.Add('')
$reportLines.Add('## Detected xHCI controllers')
$reportLines.Add('')
if ($xhciControllers.Count -eq 0) {
    $reportLines.Add('No controller name containing `xHCI` was reported by Windows. Controller naming varies by driver and vendor.')
}
else {
    foreach ($controller in $xhciControllers) {
        $reportLines.Add(('- **{0}**' -f (ConvertTo-MarkdownCell $controller.Name)))
        if ($controller.HardwareIds.Count -gt 0) {
            $reportLines.Add(('  - Hardware ID: `{0}`' -f (ConvertTo-MarkdownCell ([string]$controller.HardwareIds[0]))))
        }
        if ($controller.PciPaths.Count -gt 0) {
            $reportLines.Add(('  - Derived PCI path: `{0}`' -f ($controller.PciPaths -join '`, `')))
        }
    }
}
$reportLines.Add('')
$reportLines.Add('## What this report can and cannot establish')
$reportLines.Add('')
$reportLines.Add('- Windows may expose USB hardware IDs and device-tree location paths. The PCI path above is derived from those location paths and should be checked against the actual xHCI controller before use.')
$reportLines.Add('- Windows PnP data does not establish the macOS `IOACPIPlane` path, SCSI inquiry strings, Apple driver matching behavior, or whether an SSDT reset/power method is safe.')
$reportLines.Add('- Only Alcor AU6366 (`058F:6366`) has a verified profile in this repository. Other VID 058F devices are candidates for community investigation, not confirmed compatible models.')
$reportLines.Add('')

$fragmentPath = $null
if ($AcpiPath -and $selectedPciPath) {
    $escapedAcpiPath = Escape-XmlText $AcpiPath
    $escapedPciPath = Escape-XmlText $selectedPciPath
    $fragmentPath = [System.IO.Path]::ChangeExtension($fullOutputPath, '.DeviceProperties.plist')
    $fragment = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DeviceProperties</key>
    <dict>
        <key>Add</key>
        <dict>
            <key>$escapedPciPath</key>
            <dict>
                <key>acpi-path</key>
                <string>$escapedAcpiPath</string>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
"@
    $fragment | Set-Content -LiteralPath $fragmentPath -Encoding UTF8

    $reportLines.Add('## OpenCore / OCAT reference fragment')
    $reportLines.Add('')
    $reportLines.Add(('A partial plist was written to `{0}`.' -f [System.IO.Path]::GetFileName($fragmentPath)))
    $reportLines.Add('Merge only its `DeviceProperties -> Add` entry into your existing OpenCore configuration in OCAT. Do not replace your full `config.plist` with this partial file. The ACPI path is supplied by the user and is not discovered or validated by Windows.')
    $reportLines.Add('')
}
elseif ($AcpiPath -and -not $selectedPciPath) {
    $reportLines.Add('## OpenCore / OCAT reference fragment')
    $reportLines.Add('')
    $reportLines.Add('No unique PCI path could be selected. Re-run with `-PciDevicePath` set to the xHCI PCI path from this report and the correct known `-AcpiPath` to produce a reference plist.')
    $reportLines.Add('')
}
elseif ($PciDevicePath -and -not $AcpiPath) {
    $reportLines.Add('## OpenCore / OCAT reference fragment')
    $reportLines.Add('')
    $reportLines.Add('A PCI path was supplied, but no `-AcpiPath` was provided. Windows PnP cannot safely infer the macOS IORegistry ACPI path, so no plist fragment was generated.')
    $reportLines.Add('')
}
else {
    $reportLines.Add('## OpenCore / OCAT reference fragment')
    $reportLines.Add('')
    $reportLines.Add('No plist fragment was generated. Windows can often provide a PCI path, but the matching macOS `IOACPIPlane` path must come from a known-good macOS report for this exact machine/controller.')
    $reportLines.Add('')
}

$reportLines.Add('## Privacy')
$reportLines.Add('')
$reportLines.Add('This report omits PnP instance IDs, device serial numbers, Windows user names, and system serial numbers. Review the model and hardware details before sharing publicly.')

$reportLines | Set-Content -LiteralPath $fullOutputPath -Encoding UTF8

Write-Output ('Report written: {0}' -f $fullOutputPath)
if ($fragmentPath) {
    Write-Output ('OCAT reference plist written: {0}' -f $fragmentPath)
}
