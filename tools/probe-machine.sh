#!/bin/bash
# Read-only inventory for diagnosing the Alcor card-reader profile.
# Run with: bash tools/probe-machine.sh

set -u

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script requires macOS (ioreg and system_profiler)." >&2
    exit 1
fi

section() {
    printf '\n== %s ==\n' "$1"
}

section "macOS"
sw_vers

section "USB devices and reader identity"
echo "Shows USB node names and selected identity/port properties; serial numbers are omitted."
/usr/sbin/ioreg -p IOUSB -w0 -l 2>/dev/null | /usr/bin/awk '
    index($0, "+-o ") { current = $0 }
    /"(idVendor|idProduct|bConfigurationValue|bInterfaceNumber|USB Vendor Name|USB Product Name|locationID|UsbConnector)"[[:space:]]*=/ {
        if (current != "" && current != printed) {
            print current
            printed = current
        }
        print
    }
'

section "ACPI controller paths and reset/power methods"
/usr/sbin/ioreg -lw0 -p IOACPIPlane -r -c IOACPIPlatformDevice 2>/dev/null |
    /usr/bin/grep -E '"(name|acpi-path|_ADR|SRST|SPWR)"' || true

section "acpi-path properties visible in the IOService plane"
/usr/sbin/ioreg -lw0 -p IOService -r 2>/dev/null |
    /usr/bin/grep -B 5 '"acpi-path" =' || true

section "Apple card-reader service registry entries"
for service_class in \
    com_apple_driver_AppleUSBCardReaderInterfaceNub \
    com_apple_driver_AppleUSBCardReaderDriverNub \
    com_apple_driver_AppleUSBCardReaderUMC \
    com_apple_driver_AppleUSBCardReaderSBC
do
    echo "-- ${service_class} --"
    /usr/sbin/ioreg -lw0 -p IOService -r -c "$service_class" 2>/dev/null |
        /usr/bin/grep -E '"(IOClass|IOProbeScore|idVendor|idProduct|Vendor Identification|Product Identification)"' || true
done

section "Card Reader report"
/usr/sbin/system_profiler SPCardReaderDataType 2>/dev/null || true

echo
echo "Review this output and remove identifying hardware details before sharing it publicly."
