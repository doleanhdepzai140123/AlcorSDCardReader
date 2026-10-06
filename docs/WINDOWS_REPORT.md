# Collect a reader report on Windows

This project includes a read-only PowerShell inventory for contributors who no longer
have macOS installed on the target computer. It can collect Windows PnP hardware IDs and
device-tree location paths for Alcor USB devices (`VID 058F`), identify likely xHCI
controllers, and derive a candidate OpenCore PCI path.

It does **not** install drivers or change Windows, firmware, or an OpenCore EFI. Windows
cannot use this report to prove macOS driver matching, SCSI inquiry data, or safe ACPI
reset/power behavior. The AU6366 (`058F:6366`) remains the only verified reader profile;
reports for other IDs are useful for community research, not proof that the profile works.

## Run the report

Open PowerShell in the repository directory and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\windows\New-AlcorWindowsReport.ps1
```

The report is saved to your Desktop as `Alcor-Windows-Report.md`. It contains the detected
Alcor USB hardware IDs, status, derived PCI path, likely xHCI controllers, and limitations.
The script omits PnP instance IDs and serial numbers. Review the report before posting it
publicly.

If Windows blocks the script because of your local policy, inspect the script first and
run it from a normal PowerShell session. The example command uses a process-scoped policy
override for this invocation only; it does not change the system execution policy. No
administrator rights should be needed for this read-only query.

To choose a different output file:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\windows\New-AlcorWindowsReport.ps1 -OutputPath "$env:USERPROFILE\Desktop\Alcor-Windows-Report.md"
```

## Optional OCAT reference plist

The report may include a candidate PCI path, but Windows does not provide the matching
macOS `IOACPIPlane` path in a dependable, portable form. If you already have a verified
ACPI path for this exact machine and controller, pass it explicitly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\windows\New-AlcorWindowsReport.ps1 -AcpiPath 'IOACPIPlane:/_SB/PCI0@0/GP17@80001/XHC1@4'
```

The sample path above belongs only to the maintainer's ASUS test machine. Do not reuse it
on another computer. If the report finds more than one candidate PCI path, pass the xHCI
path you have independently identified:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\windows\New-AlcorWindowsReport.ps1 -AcpiPath 'IOACPIPlane:/your/verified/controller/path' -PciDevicePath 'PciRoot(0x0)/Pci(0x14,0x0)'
```

When both values are supplied, the script writes a partial plist beside the report. Open
your existing `config.plist` in OCAT and merge the entry under `DeviceProperties -> Add`:

```text
DeviceProperties
└── Add
    └── PciRoot(...) / Pci(...)
        └── acpi-path = IOACPIPlane:/...
```

In OCAT, the PCI path is the dictionary key, and `acpi-path` is a **String** property
inside that dictionary. Copy both values from the generated plist. Keep all existing
properties in the `Add` dictionary. **Do not replace your full `config.plist` with the
partial plist.** Check the PCI path against the actual controller, and check the ACPI path
against macOS IORegistry data from that same machine before enabling the property. The
script cannot check whether either value is correct. OCAT labels may vary slightly by
version, but the OpenCore configuration nodes remain `DeviceProperties -> Add`.

## Share results

For a reader that does not match the included AU6366 profile, attach the report to a
discussion or pull request and include the reader's exact model if known. Community
submissions should also add macOS-side evidence when available: interface/configuration
numbers, SCSI inquiry strings, macOS version/build, and confirmation that card insertion,
reading, writing, ejecting, and reinsertion work. See
[Adding a reader](ADDING_A_READER.md).

## Data source and implementation

The script reads Windows Plug and Play properties using `Get-PnpDevice` and
`Get-PnpDeviceProperty`. Microsoft describes `DEVPKEY_Device_LocationPaths` as the
device's location in the PnP tree and documents the property as read-only. These paths
can help identify PCI topology, but they are not macOS ACPI namespace paths.

- [Microsoft: `DEVPKEY_Device_LocationPaths`](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/devpkey-device-locationpaths)
- [Microsoft: `Get-PnpDeviceProperty`](https://learn.microsoft.com/en-us/powershell/module/pnpdevice/get-pnpdeviceproperty)
