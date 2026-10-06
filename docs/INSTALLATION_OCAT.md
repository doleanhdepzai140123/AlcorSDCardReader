# OpenCore installation with OCAT

This guide describes the OpenCore configuration nodes to edit in OpenCore Auxiliary
Tools (OCAT). Menu labels can move between OCAT releases, but the OpenCore nodes and
values below are the ones that matter. Start with a backup of the EFI you actually boot.

> **Use the shipped binaries only on the verified setup.** The included kext profile is
> for AU6366 (`058F:6366`). The included `SSDT-SDCR.aml` is scoped to the maintainer's
> ASUS VivoBook M513UA-EJ710W only. Do not install that AML on another computer.

## Before editing

1. Make a backup of the current EFI folder.
2. Confirm that your USB map contains the card-reader port. The verified setup maps it as
   Internal (`UsbConnector = 255`). An incorrect port map can prevent the expected match.
3. Confirm the reader's exact USB ID. On macOS, run
   [`tools/probe-machine.sh`](../tools/probe-machine.sh); on Windows, use the
   [Windows report tool](WINDOWS_REPORT.md). The profile in this repository is for
   `058F:6366` only.
4. Identify the PCI device path and macOS `IOACPIPlane` path for the xHCI controller that
   owns the reader's port. Do not copy another computer's paths. A Windows-derived PCI
   path is only a candidate; Windows cannot confirm the matching macOS ACPI path.

## 1. Copy the kext bundle

Copy the entire `AlcorSDCardReader.kext` directory from this repository to:

```text
EFI/OC/Kexts/AlcorSDCardReader.kext
```

Do not copy only `Contents/Info.plist`; the bundle directory is the kext.

## 2. Add the kext in OCAT

Open the active `config.plist` in OCAT. Navigate to **Kernel → Add** and add an entry for
the bundle. If OCAT has created an entry by scanning the Kexts folder, select it and check
every value below:

| OpenCore field | Value |
| --- | --- |
| `Arch` | `Any` |
| `BundlePath` | `AlcorSDCardReader.kext` |
| `Enabled` | `True` |
| `ExecutablePath` | Empty string |
| `PlistPath` | `Contents/Info.plist` |
| `MinKernel` | Empty string |
| `MaxKernel` | Empty string |

This is a codeless kext, so `ExecutablePath` must stay empty.

## 3. Add the per-machine `acpi-path`

In OCAT, open **DeviceProperties → Add**. Add a dictionary whose key is the PCI path of
the xHCI controller. Inside that dictionary, add `acpi-path` as a **String** whose value
is the complete IORegistry path from the target macOS installation:

```text
DeviceProperties
└── Add
    └── PciRoot(0x0)/Pci(0x8,0x1)/Pci(0x0,0x4)    [Dictionary]
        └── acpi-path                              [String]
            IOACPIPlane:/_SB/PCI0@0/GP17@80001/XHC1@4
```

The paths above are **only the maintainer's ASUS test-machine values**. Replace both
values on every other system. Preserve all existing device-property entries in the
`Add` dictionary. Do not replace the entire `DeviceProperties` section with the example.

OpenCore converts a plist string in device properties to a null-terminated byte
sequence. The Apple stack's lookup of this private property is not a public API, so after
boot confirm in `ioreg` that the property appears on the intended controller service.
See [Porting](PORTING.md) for path discovery and the limits of the shared-bundle method.

## 4. Decide whether an SSDT is needed

The supplied `SSDT-SDCR.aml` adds a no-op `SRST` under `\_SB.PCI0.GP17.XHC1`. It is
**not a generic table**. The method returns `Zero` and performs no power or reset work.

Before adding any ACPI table:

1. Inspect the target controller's ACPI namespace and check whether `SRST` or `SPWR` is
   already present.
2. Determine whether the slot requires real reset or power sequencing.
3. Never add a duplicate method or replace working firmware behavior with a no-op.
4. If a machine-specific table is needed, adapt `SSDT-SDCR.dsl` only after confirming the
   correct scope and safe method behavior, then compile it with ACPICA `iasl`.

For a table you have built and reviewed, copy its AML to `EFI/OC/ACPI/`. In OCAT, add an
entry under **ACPI → Add** and set `Path` to that AML filename and `Enabled` to `True`.
Keep the source DSL alongside the generated AML in your own working files.

## 5. Save and validate

Save the active `config.plist` in OCAT. Validate it with `ocvalidate` from the same
OpenCore release as the EFI. A structurally valid config does not prove the hardware
paths or ACPI method are correct. Keep your backup available and be prepared to disable
the new Kernel and ACPI entries separately if boot or reader behavior regresses.

Reboot, insert a card, and verify all of the following on macOS:

- the Apple card-reader interface, driver nub, UMC, and SBC services appear in IORegistry;
- `system_profiler SPCardReaderDataType` lists the reader;
- the card mounts, reads, writes, ejects, and is detected again after reinsertion.

For a new reader model, do not reuse the AU6366 UMC quirks or SBC inquiry match without
the evidence described in [Adding a reader](ADDING_A_READER.md).
