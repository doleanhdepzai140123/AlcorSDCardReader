# How the AU6366 profile works

## Scope

This note describes the behavior observed for the Alcor AU6366 (`058F:6366`) on the
maintainer's ASUS VivoBook M513UA-EJ710W running macOS Ventura 13.7.8 (`22H730`). It is
not a specification for all Alcor readers or all macOS releases.

The project does not include executable driver code. Its kext bundle contributes
`IOKitPersonalities` that name classes in Apple's `AppleUSBCardReader` bundle. Apple
documents personalities as dictionaries used to match devices; the USB- and SCSI-family
keys and private Apple classes used here are implementation-specific.

## Match chain

The AU6366 appears as a USB mass-storage device. The profile asks Apple's card-reader
stack to claim the device at each layer:

```text
USB host interface
  -> AppleUSBCardReaderInterfaceNub
  -> AppleUSBCardReaderDriverNub
  -> AppleUSBCardReaderUMC
  -> AppleUSBCardReaderSBC
  -> SCSI logical unit reported as a card reader
```

The four personalities are in
[`AlcorSDCardReader.kext/Contents/Info.plist`](../AlcorSDCardReader.kext/Contents/Info.plist).
Their exact identifiers and interface numbers identify the tested AU6366 only.

## Personality roles

1. **Interface nub.** Matches USB vendor `0x058F`, product `0x6366`, configuration 1,
   interface 0 and marks the slot as internal. The machine-specific `acpi-path` is
   supplied by OpenCore `DeviceProperties`, not embedded in this kext bundle.
2. **Driver nub.** Matches the interface nub and supplies storage characteristics used
   by Apple's card-reader stack.
3. **UMC.** Matches the driver nub and takes precedence over Apple's generic AU6366 entry
   on the tested system. This profile carries the associated AU6366 SCSI characteristics
   observed in Apple's device-specific personality.
4. **SBC.** Matches SCSI inquiry data reported by the AU6366 firmware: vendor
   `Multiple`, product `Card  Reader` (two spaces). This was the class observed to
   populate System Information's Card Reader section.

The `IOProbeScore` values and match results were observed on the test system. They are not
guaranteed to win on other macOS releases, hardware revisions, or against other reader
profiles.

## Why there is an SSDT

On the test system, the reader's USB connector is mapped as Internal (`UsbConnector =
255`). The Apple stack's internal-port path expects an ACPI controller object with a
reset or power method. `SSDT-SDCR.dsl` adds `SRST` under the test controller's ACPI scope.
The method returns `Zero` and performs no hardware operation.

That no-op was used for the test machine's slot, which required no explicit reset or
power sequencing. It is not a generic substitute for platform power control. A different
machine may use a different controller path, already define `SRST`, or require a real
power/reset sequence. Inspect and validate the target ACPI implementation before using
or adapting the table. See [Porting](PORTING.md).

## What “native” means here

The reader's electrical and software transport remains USB. The profile changes which
macOS IOKit driver classes claim it and how macOS reports the SCSI logical unit. It does
not provide a native SD host-controller driver or change the device into a PCI/SD bus
device.

## Extending to another reader

Do not copy the AU6366 personality and replace only its IDs. Another Alcor model can have
different interfaces, inquiry strings, Apple competition, and required quirks. The
AppleUSBCardReader stack may not support it at all. Gather the evidence described in
[Adding a reader](ADDING_A_READER.md) before creating a separate profile.

## References

- [Apple: IOKitPersonalities](https://developer.apple.com/documentation/bundleresources/information-property-list/iokitpersonalities)
- [Apple: Driver and Device Matching](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Matching/Matching.html)
