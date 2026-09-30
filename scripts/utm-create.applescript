#!/usr/bin/osascript
-- Create a UTM QEMU VM with 3D acceleration from a Tart-built disk image.
-- Usage: osascript utm-create.applescript <name> <qcow2-path> <cpu-cores> <memory-gb>
-- See docs/development.md and docs/utm.md for the why behind the config.plist patch below.

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
