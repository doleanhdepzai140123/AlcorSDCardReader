# Porting the AU6366 profile to another machine

The included kext contains AU6366 hardware data and no machine-specific ACPI path. The
included `SSDT-SDCR.aml` is for the maintainer's test machine and is not portable as-is.
Each OpenCore setup must supply its own xHCI `acpi-path`, and each machine may need a
separately scoped SSDT. Reuse the AU6366 personality only after confirming the target
reader has the same USB and SCSI identity.

For GUI-based OpenCore edits, follow [Install and configure with OCAT](INSTALLATION_OCAT.md).
For a different reader controller, use [Adding a reader](ADDING_A_READER.md) instead of
editing the AU6366 profile in place.

## 1. Confirm the reader

Run the read-only inventory script from the repository root:

```sh
bash tools/probe-machine.sh
```

Confirm that the microSD reader itself reports USB vendor/product IDs `058F:6366`.
Identify its `bConfigurationValue` and `bInterfaceNumber`; do not take the first USB IDs
shown in a system-wide listing. If the reader is a different model, stop here and follow
[Adding a reader](ADDING_A_READER.md). The AU6366 SCSI quirks and inquiry match cannot be
assumed for another device.

## 2. Confirm the SCSI identity

The current fourth personality matches the strings:

| Field | AU6366 value |
| --- | --- |
| Vendor Identification | `Multiple` |
| Product Identification | `Card  Reader` (two spaces) |

Compare the target device's inquiry data exactly, including spacing and padding. Update
the match only when the target is known to be the same AU6366 variant and the match has
been verified. A matching inquiry string alone does not prove that Apple's driver
supports a different controller.

## 3. Find the target controller path

Inspect the ACPI plane and locate the xHCI controller that owns the reader's USB port:

```sh
ioreg -lw0 -p IOACPIPlane -r -c IOACPIPlatformDevice | grep -E '"(name|acpi-path)"'
```

The tested system used:

```text
IOACPIPlane:/_SB/PCI0@0/GP17@80001/XHC1@4
```

The corresponding ASL scope was `\_SB.PCI0.GP17.XHC1`. Names and `_ADR` values differ
across firmware. Match the ACPI device to the controller and USB port; do not select an
`XHC` name by convention alone.

## 4. Inject the ACPI path through OpenCore

Find the PCI device path for the xHCI controller. The OpenCore `DeviceProperties -> Add`
key uses the canonical PCI path, while its `acpi-path` value uses the IORegistry ACPI
path. `gfxutil -f XHC1` can help print the PCI path; replace `XHC1` with the controller
name shown by your own IORegistry. For the maintainer's test machine only, the values
are:

```xml
<key>PciRoot(0x0)/Pci(0x8,0x1)/Pci(0x0,0x4)</key>
<dict>
    <key>acpi-path</key>
    <string>IOACPIPlane:/_SB/PCI0@0/GP17@80001/XHC1@4</string>
</dict>
```

Replace both with your controller's paths, and merge this entry into the existing
`DeviceProperties -> Add` dictionary. Do not replace other device properties. OpenCore
accepts a plist string as a null-terminated property value. After boot, use `ioreg` to
confirm that the intended xHCI service exposes the expected `acpi-path`. The Apple
driver's parent-chain lookup is private behavior, so this shared-bundle arrangement must
be verified on the target machine.

The [Windows preflight report](WINDOWS_REPORT.md) may derive a candidate PCI path from
PnP location paths. It cannot establish the matching IORegistry ACPI path; treat its PCI
result as a clue to verify, not a ready-to-install configuration.

The read-only probe script prints `acpi-path` entries it finds in the IOService plane.
Match the surrounding service name to your xHCI controller; do not rely on the property
appearing somewhere in the registry under an unrelated device.

## 5. Check existing ACPI behavior before adding a stub

The example SSDT defines `SRST` to return `Zero`. Before adapting it:

1. Inspect the target controller and related ACPI devices for existing `SRST` or `SPWR`
   methods.
2. Determine whether the slot needs power or reset sequencing and where that behavior is
   implemented.
3. Do not add a duplicate method or replace a real method with this no-op.
4. If a no-op is genuinely appropriate, update the SSDT `Scope` to the exact controller
   path and compile the source with `iasl -ve SSDT-SDCR.dsl`.

The source is a template for the tested case, not a proof that an arbitrary controller can
safely use a no-op. If the target needs real GPIO, PMIC, or firmware methods, this table
must implement the correct behavior or not be used.

## 6. Keep the injected property and SSDT paths aligned

Set the `acpi-path` property in OpenCore to the target controller's IORegistry path. In
the SSDT source, set the `Scope` to the same ACPI device. These values use different
formats: OpenCore gets the full `IOACPIPlane:/...` path; the ASL scope is the dotted ACPI
namespace path.

The shipped `SSDT-SDCR.aml` remains the binary for the test machine. Compile a new AML
after changing the DSL; do not distribute a retargeted AML as if it were universal.

## 7. Validate on the target

After adding the kext and the machine-specific AML to OpenCore and rebooting, verify:

- the interface is claimed by Apple's card-reader stack;
- the driver nub starts and the expected UMC/SBC services appear;
- `system_profiler SPCardReaderDataType` shows the reader;
- cards can be mounted, read, written, ejected, and detected again after reinsertion.

Record the macOS version/build and exact reader identity. A successful result on one
machine does not establish support on all systems using that reader model.

## 8. About sharing one kext bundle

The kext bundle omits `acpi-path`; the per-machine OpenCore property described above is
the intended way to keep the same AU6366 kext bundle across machines. OpenCore documents
device-property injection, but Apple's parent-chain lookup is private behavior. Confirm
that the property appears on the expected registry service and that the Apple driver
resolves it to the intended ACPI object before treating the setup as verified.

The ACPI table may still need a per-machine scope even if the kext bundle is shared.
There is no tested, universal SSDT in this repository.
