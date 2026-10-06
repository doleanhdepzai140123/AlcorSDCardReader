# <Manufacturer> <Reader or Controller Model>

> Replace every placeholder. Keep `Reported`, `Experimental`, or `Verified` status
> accurate. Do not mark a profile verified using Windows data alone.

## Status

**Reported / Experimental / Verified** — <brief evidence summary>

## Hardware identity

| Item | Value |
| --- | --- |
| Reader/controller model | <exact label or unknown> |
| USB vendor/product ID | `<VID:PID>` |
| Configuration / interface | `<configuration> / <interface>` |
| USB firmware/revision | <value or unknown> |
| SCSI peripheral device type | <value or unknown> |
| SCSI vendor identification | `<exact value, preserve whitespace>` |
| SCSI product identification | `<exact value, preserve whitespace>` |
| SCSI revision / inquiry length | <value or unknown> |

## Tested environment

| Item | Value |
| --- | --- |
| Computer | <model> |
| CPU/platform | <value> |
| macOS version and build | <value> |
| Bootloader and version | <value> |
| USB map and connector type | <value> |
| xHCI PCI path | <value; redact unique identifiers> |
| xHCI ACPI path | <value; redact unique identifiers> |
| SSDT scope/method | <value, or not required> |

## Kext profile changes

<List the exact USB and SCSI matching keys and any model-specific characteristics.
Explain the evidence for each non-default quirk and probe score.>

## Validation results

- Apple card-reader interface service: <pass/fail/not tested>
- Apple driver nub and UMC/SBC services: <pass/fail/not tested>
- System Information Card Reader entry: <pass/fail/not tested>
- Card insertion, mount, read, write, eject, and reinsertion: <results>
- Sleep/wake behavior, if tested: <results>
- Known regressions or limitations: <details>

## Evidence and privacy review

<Link or summarize focused logs. Remove USB serials, SMBIOS serials, MLB values, UUIDs,
user names, and unrelated EFI data before sharing.>
