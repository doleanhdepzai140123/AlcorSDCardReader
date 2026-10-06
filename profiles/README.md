# Reader profiles

This directory records hardware-specific evidence. A profile is not a promise that every
device from a vendor works; it describes one reader identity and the tests performed on
it.

| Reader | USB ID | Profile status | Evidence |
| --- | --- | --- | --- |
| Alcor AU6366 | `058F:6366` | Verified on one setup | [AU6366 profile](AU6366.md) |
| Other Alcor readers | Not listed yet | Unverified | Start with the [profile template](READER_PROFILE_TEMPLATE.md) and [Adding a reader](../docs/ADDING_A_READER.md). |

Use one profile record per distinct controller/firmware identity. Keep these labels
separate:

- **Reported**: hardware details collected, but the kext behavior has not been tested.
- **Experimental**: a test was attempted; results and known failures are documented.
- **Verified**: the listed hardware and software combination passed the macOS checks in
  the profile record.

Only a maintainer-reviewed, evidence-backed profile should be called verified. A Windows
PnP report can help identify a reader, but cannot establish Apple driver compatibility.
