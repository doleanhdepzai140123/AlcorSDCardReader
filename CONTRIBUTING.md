# Contributing

Thanks for helping expand the reader catalog. A report that identifies a reader is
valuable even if macOS testing is not available; label its evidence level accurately and
do not describe an untested model as supported.

## Before opening an issue or pull request

1. Check [existing reader profiles](profiles/README.md) and open issues.
2. For Windows-only identity data, follow the [Windows report guide](docs/WINDOWS_REPORT.md).
3. For a new hardware profile, follow [Adding a reader](docs/ADDING_A_READER.md) and copy
   [the profile template](profiles/READER_PROFILE_TEMPLATE.md).
4. Review every attached report for serials and other private identifiers.

## Profile requirements

- Keep one record per distinct reader/controller identity.
- Record USB VID:PID, configuration/interface, and exact SCSI inquiry values when
  available. Preserve spaces and distinguish unavailable data from an empty value.
- Describe the exact macOS version/build, computer, bootloader, and USB-port mapping used.
- Document every model-specific personality key and quirk. Explain copied Apple values
  with a source or observed evidence.
- Mark untested properties, paths, SSDTs, and macOS versions as unverified.
- Do not broaden the shipped AU6366 match by changing only its VID/PID.

## ACPI and binary files

- Keep machine-specific ACPI paths in per-machine OpenCore properties or clearly scoped
  documentation, not in a shared kext personality.
- Include SSDT source (`.dsl`) whenever a compiled `.aml` is contributed.
- Explain why a table is necessary, its scope, whether `SRST`/`SPWR` already exists, and
  the hardware evidence for any reset/power implementation.
- Never submit a no-op method as a universal fix or overwrite a platform's real method.

## Pull request checklist

- Use the repository's English documentation style.
- Keep changes focused and explain the test setup in the pull request template.
- Include the macOS validation results, or clearly mark the contribution as data-only.
- Remove USB serials, SMBIOS serials, MLB values, UUIDs, usernames, and unrelated EFI
  files from logs and attachments.
- Keep third-party notices and licensing compatible with the MIT-licensed project.

The project uses GitHub issue forms to collect reader reports and bugs. Please do not
upload a complete EFI folder or an unredacted `config.plist`.
