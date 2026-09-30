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

on run argv
    set vmName to item 1 of argv
    set qcow2Path to item 2 of argv
    set cpuCores to (item 3 of argv) as integer
    set memoryGB to (item 4 of argv) as integer
    set memoryMiB to memoryGB * 1024

    tell application "UTM"
        make new virtual machine with properties {backend:qemu, configuration:{name:vmName, architecture:"aarch64", memory:memoryMiB, cpu cores:cpuCores, drives:{{source:POSIX file qcow2Path, interface:VirtIO}}, network interfaces:{{mode:shared}}, displays:{{hardware:"virtio-gpu-gl-pci", dynamic resolution:true}}}}
    end tell
end run
