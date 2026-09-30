#!/usr/bin/osascript
-- Create a UTM QEMU VM with virgl 3D acceleration from a Tart-built disk image.
--
-- Usage: osascript utm-create.applescript <name> <qcow2-path> <cpu-cores> <memory-gb>
--
-- UTM copies the qcow2 into its own bundle on creation, so the source file
-- passed here can be deleted afterwards. "virtio-gpu-gl-pci" is the hardware
-- string QEMU's virtio-gpu-gl-pci device expects; UTM's ANGLE/Metal backend
-- renders it, unlike Tart's Virtualization.framework virtio-gpu, which is 2D
-- only.
--
-- UTM's scripting dictionary has no "sound" property on qemu configuration
-- (only name/icon/notes/architecture/machine/memory/cpu cores/hypervisor/
-- uefi/directory share mode/drives/network interfaces/serial ports/displays/
-- qemu additional arguments), so the sound device is set by patching
-- config.plist directly after creation. If UTM was already running when this
-- VM was created, UTM caches the config in memory and won't see the patched
-- Sound entry until it's fully quit and reopened (a VM restart alone is not
-- enough) -- this script does not do that automatically since it could stop
-- other running VMs.

on run argv
    set vmName to item 1 of argv
    set qcow2Path to item 2 of argv
    set cpuCores to (item 3 of argv) as integer
    set memoryGB to (item 4 of argv) as integer
    set memoryMiB to memoryGB * 1024

    tell application "UTM"
        make new virtual machine with properties {backend:qemu, configuration:{name:vmName, icon:"fedora", architecture:"aarch64", memory:memoryMiB, cpu cores:cpuCores, drives:{{source:POSIX file qcow2Path, interface:VirtIO}}, network interfaces:{{mode:shared}}, displays:{{hardware:"virtio-gpu-gl-pci", dynamic resolution:true}}}}
    end tell

    set configPlist to (POSIX path of (path to home folder)) & "Library/Containers/com.utmapp.UTM/Data/Documents/" & vmName & ".utm/config.plist"
    do shell script "plutil -replace Sound -json '[{\"Hardware\":\"virtio-sound-pci\"}]' " & quoted form of configPlist

    log "Sound device set to virtio-sound-pci. If UTM was already open, quit and reopen it before starting " & vmName & " for the sound device to take effect."
end run
