<div align="center">

# Alcor SD Card Reader for macOS

**A community-maintained codeless IOKit profile for USB-connected Alcor SD readers on Hackintosh.**

![macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![OpenCore](https://img.shields.io/badge/bootloader-OpenCore-blue)
![AU6366](https://img.shields.io/badge/verified-Alcor%20AU6366-brightgreen)
![License](https://img.shields.io/badge/license-MIT-green)
![Written by humans, not AI](https://img.shields.io/badge/written_by_humans-not_ai-red)

[Getting started](#getting-started) · [OCAT guide](docs/INSTALLATION_OCAT.md) · [Reader profiles](profiles/README.md) · [Contribute](CONTRIBUTING.md)

</div>

> **Compatibility is model-specific.** The repository includes one verified profile:
> Alcor AU6366 (`VID:PID 058F:6366`) on the maintainer's ASUS VivoBook M513UA-EJ710W
> with macOS Ventura 13.7.8 (`22H730`). Other Alcor readers, computers, and macOS versions
> are unverified until someone contributes test results.

## What this project does

Some internal USB SD readers appear in macOS as ordinary USB mass-storage devices. This
project provides a **codeless kext**—an `Info.plist` with IOKit matching personalities,
not an executable driver—that asks Apple's existing `AppleUSBCardReader` stack to claim
the tested AU6366 interface and SCSI device. A machine-specific SSDT was needed by the
maintainer's internal-port setup.

Here, “native card-reader support” means that macOS uses its Apple card-reader classes and
reports the device under **System Information → Card Reader**. The hardware remains USB;
this project does not turn it into a native PCI/SD host controller or change the transport.

## Support status

| Reader / setup | Status | Notes |
| --- | --- | --- |
| Alcor AU6366 (`058F:6366`) | **Verified profile included** | ASUS VivoBook M513UA-EJ710W, Ryzen 7 5700U, Ventura 13.7.8 (`22H730`). |
| Other Alcor USB readers | **Community investigation welcome** | No compatibility claim until each reader has its own identity, matching data, and macOS test evidence. |
| Other computer models, macOS releases, or bootloaders | **Unverified** | Paths, ACPI behavior, Apple matching, and driver availability vary. |

The included `SSDT-SDCR.aml` is compiled for the maintainer's test machine. **Do not copy
it to another computer.** The source is provided so an experienced user can study and
adapt the table after checking that machine's ACPI namespace and reset/power behavior.

## Getting started

1. Identify the reader and confirm it matches a profile. On Windows, use the
   [read-only inventory tool](docs/WINDOWS_REPORT.md). On macOS, run
   `bash tools/probe-machine.sh` for USB and driver-registry details; collect exact SCSI
   inquiry strings separately as described in [Adding a reader](docs/ADDING_A_READER.md).
2. If the reader is not the AU6366, follow [Adding a reader](docs/ADDING_A_READER.md).
   Do not make it appear supported by changing only the VID/PID.
3. Follow the [OCAT installation guide](docs/INSTALLATION_OCAT.md). It explains how to
   add the codeless kext and a per-machine `acpi-path` in the existing OpenCore config.
4. Add an SSDT only after inspecting the target controller for existing `SRST`/`SPWR`
   methods and confirming what the SD slot needs. See [Porting](docs/PORTING.md).
5. Reboot and perform the complete card lifecycle checks in the installation guide.

### Quick Windows inventory

From PowerShell opened at the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\windows\New-AlcorWindowsReport.ps1
```

The Markdown report is saved to the Desktop. It can identify present USB devices with
Alcor's known USB vendor ID and show candidate PCI topology. It **cannot** determine
macOS SCSI inquiry strings, Apple's match result, the correct IORegistry ACPI path, or
whether an SSDT stub is safe. See the [Windows report guide](docs/WINDOWS_REPORT.md).

## Repository contents

```text
AlcorSDCardReader.kext/             AU6366 codeless IOKit personalities
SSDT-SDCR.dsl                       Source for the test-machine SSDT
SSDT-SDCR.aml                       Compiled SSDT for the test machine only
profiles/                           Hardware support matrix and profile records
docs/                               OCAT, porting, mechanism, and contribution guides
tools/probe-machine.sh              Read-only macOS inventory
tools/windows/                      Read-only Windows PnP report generator
.github/                            Issue forms and pull-request template
LICENSE                             MIT License
```

## Important limitations

- This is not a standalone driver and does not include executable code.
- Apple's `AppleUSBCardReader` classes and their matching behavior are implementation
  details. They may change or disappear between macOS versions.
- The kext's USB and SCSI match data, copied AU6366 quirks, and personality chain must not
  be assumed to fit another reader—even one sold by Alcor.
- The no-op `SRST` method in the shipped SSDT was used on one test setup. It does no power
  or reset work. It must not shadow a real method or replace required hardware sequencing.
- No Windows report can validate Hackintosh functionality. New profiles need macOS-side
  evidence and real card-operation tests before being listed as verified.

## Documentation

- [Install and configure with OCAT](docs/INSTALLATION_OCAT.md)
- [Supported reader profiles](profiles/README.md)
- [Port the AU6366 profile to another machine](docs/PORTING.md)
- [Add a different reader model](docs/ADDING_A_READER.md)
- [How the AU6366 match chain works](docs/MECHANISM.md)
- [Collect a report from Windows](docs/WINDOWS_REPORT.md)
- [Contributing](CONTRIBUTING.md)

## Contributing

The goal is a **catalog of separately documented and validated reader profiles**, not one
overly broad match that risks claiming unrelated USB storage. Community reports for other
Alcor IDs are welcome. Follow the [contribution guide](CONTRIBUTING.md), remove unique
machine identifiers, and distinguish collected data from working test results.

## License

Distributed under the [MIT License](LICENSE). Apple driver names and other third-party
references remain the property of their respective owners.

## References

- [Apple: `IOKitPersonalities`](https://developer.apple.com/documentation/bundleresources/information-property-list/iokitpersonalities)
- [Apple: Driver and Device Matching](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Matching/Matching.html)
- [OpenCore Configuration](https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.tex)
