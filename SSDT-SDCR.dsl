/*
 * SSDT-SDCR.dsl
 *
 * Test-machine ACPI companion for AlcorSDCardReader.kext.
 *
 * This table is specific to the ACPI namespace shown below. It adds an SRST
 * no-op because the Apple card-reader stack expects SRST or SPWR for a reader
 * mapped as an internal USB port. A no-op is appropriate only when the slot
 * needs no power or reset sequencing. Do not install this table blindly on
 * another computer or over an existing method.
 *
 * Keep this scope in sync with the `acpi-path` value supplied through that
 * machine's OpenCore DeviceProperties. For another machine, inspect its ACPI
 * tree, check for existing methods, confirm the required hardware behavior,
 * then compile a machine-specific AML.
 *
 * Build with ACPICA iasl:
 *     iasl -ve SSDT-SDCR.dsl
 */

DefinitionBlock ("", "SSDT", 2, "ACDT", "SDCRDR", 0x00000000)
{
    Scope (\_SB.PCI0.GP17.XHC1)
    {
        Method (SRST, 0)
        {
            Return (Zero)
        }
    }
}
