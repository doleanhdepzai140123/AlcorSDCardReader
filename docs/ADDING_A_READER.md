# Adding a reader model

The codeless kext in this repository contains an AU6366 profile. A different Alcor reader
may use a different USB interface, SCSI identity, quirk set, or controller behavior; it
may not work with Apple's `AppleUSBCardReader` stack at all. Treat each controller/firmware
identity as a separate profile and build evidence before adding matching personalities.

## 1. Identify the exact device

On Windows, run the [PnP inventory tool](WINDOWS_REPORT.md). It can collect USB hardware
IDs and candidate PCI topology. On macOS, run:

```sh
bash tools/probe-machine.sh
```

Record the reader's own `idVendor`, `idProduct`, `bConfigurationValue`, and
`bInterfaceNumber`. Confirm these belong to the card-reader interface, not a hub or a
different USB device. Use a known-good USB map and record the connector type.

## 2. Collect the SCSI inquiry identity on macOS

The stock AU6366 profile uses these SCSI fields:

| Field | AU6366 value |
| --- | --- |
| Peripheral Device Type | `0` |
| Vendor Identification | `Multiple` |
| Product Identification | `Card  Reader` (two spaces) |
| Inquiry Length | `36` |

Collect the target reader's SCSI peripheral type, vendor, product, and revision from its
logical-unit registry entry or another trustworthy SCSI inquiry tool. Preserve exact
spacing and padding. Windows' generic PnP report does not collect this data.

## 3. Check Apple support and matching behavior

On the target macOS version:

1. Confirm `AppleUSBCardReader` and the relevant class names exist in Apple's installed
storage-driver bundles.
2. Observe which Apple personality or generic mass-storage class claims each interface
and SCSI service before adding a profile.
3. Determine the exact match keys required at each layer. Do not assume the AU6366's
personality chain, probe scores, UMC quirks, timeouts, or SCSI fields are transferable.
4. Record the OS version/build and focused `ioreg` evidence for the original and modified
match results.

Apple's driver classes and personalities are private implementation details. If the
required class is absent or the match chain cannot be substantiated, report the reader as
unsupported or unknown rather than generating a broad match.

## 4. Add a separate profile

Use [`profiles/READER_PROFILE_TEMPLATE.md`](../profiles/READER_PROFILE_TEMPLATE.md) to
record the model and evidence. Keep the existing AU6366 personalities intact. If a new
profile is justified:

1. Add uniquely named personalities to a separate profile variant or add a new clearly
   named group to the codeless kext.
2. Match the narrowest verified USB identity, including VID, PID, configuration, and
   interface where appropriate.
3. Add SCSI matching only for exact inquiry values observed from that model.
4. Add only quirks supported by evidence for that reader; do not copy the AU6366 values
   just because the vendor is Alcor.
5. Record probe-score reasoning and the stock competing personality on the tested OS.
6. Keep the per-machine xHCI ACPI path outside the shared profile; see [Porting](PORTING.md).

The profile template is a documentation form, not an installable plist. Do not put
placeholder IDs or wildcard matches in a kext that users could load.

### Values that are hardware-specific

When the evidence supports a new personality chain, these are the values a maintainer
must review in `AlcorSDCardReader.kext/Contents/Info.plist`:

| Property | Source of the value | Guidance |
| --- | --- | --- |
| `idVendor` / `idProduct` | USB descriptor, decimal in the plist | Convert from the reader's VID:PID; scope every USB-tier match to the actual interface. |
| `bConfigurationValue` / `bInterfaceNumber` | USB descriptor | Match the mass-storage interface used by the reader, not a hub or another interface. |
| `Vendor Identification` / `Product Identification` | SCSI INQUIRY data | Preserve exact bytes/spacing as reported. Do not infer them from the USB product name. |
| `Peripheral Device Type` / `Inquiry Length` | SCSI INQUIRY data | Confirm the device type and data length from the target device. |
| `SCSI Device Characteristics` | Verified Apple personality or tested behavior | Copy only characteristics shown to apply to this controller; document the source. |
| `IOProbeScore` | Observed competing matches on the target macOS build | Do not raise scores blindly. Explain which stock match must be displaced and why. |
| `Physical Interconnect Location` | USB port map | Use `Internal` only when that reader port is actually mapped as internal. |

Class names and the four-tier provider chain can remain only when those Apple classes are
present and the provider relationships have been confirmed on the target macOS build.
The `acpi-path` is machine-specific and belongs in the OpenCore device properties. ACPI
scope and method behavior belong in a separately reviewed, machine-specific SSDT.

## 5. Review ACPI requirements separately

Determine whether the Apple driver requires an ACPI reset/power method for this reader's
port. Inspect the xHCI ACPI namespace and existing methods. If an SSDT is required:

- scope it to the target machine's controller;
- implement the real hardware behavior if reset or power sequencing is needed;
- do not duplicate or shadow an existing `SRST`/`SPWR` method;
- submit the `.dsl` source with the compiled `.aml` and clearly mark the target setup.

The shipped no-op `SRST` table is specific to the maintainer's test setup. It is not a
starter table for another controller.

## 6. Test and report honestly

Test the complete card lifecycle: insert, mount, read, write, eject, reinsert, and—where
practical—sleep/wake. Capture whether Apple's interface, driver nub, UMC, and SBC services
start and whether System Information reports a card reader. Record failures and known
limitations, not just the successful state.

Submit the record with the profile template. Data collected only on Windows should be
marked **Reported**; use **Experimental** for incomplete macOS results; reserve **Verified**
for a named machine, reader revision, and OS build that passed the documented checks.
Review logs for USB serials, SMBIOS serials, MLB values, UUIDs, usernames, and unrelated
EFI contents before sharing.
