# Exporting a Tart VM to UTM for 3D acceleration

Tart runs Linux guests through Apple's Virtualization.framework, which only exposes a 2D virtio-gpu — every Tart-run Linux VM renders in software (llvmpipe), regardless of how it was provisioned. `task fedora:utm` works around this by converting the same disk Tart built into a UTM/QEMU VM using the `virtio-gpu-gl-pci` device, which UTM renders through its ANGLE/Metal backend. This gives 3D-accelerated GL inside the guest (video, KWin compositing, general desktop use). Both VMs share the same provisioned disk; only the display hardware differs, and the Tart VM is left untouched.

## Prerequisites

- UTM.app installed (`/Applications/UTM.app`).
- Grant Automation permission the first time you run this: macOS will prompt when `osascript` first drives UTM, or if it doesn't, add it manually under System Settings → Privacy & Security → Automation → (your terminal) → UTM.

## Normal usage

```sh
task fedora:utm
```

This runs two steps, defined in `taskfiles/fedora.yml`:

```sh
qemu-img convert -p -f raw -O qcow2 ~/.tart/vms/fedora-44-kde/disk.img .cache/images/fedora-44-kde-utm.qcow2
osascript scripts/utm-create.applescript "fedora-44-kde" ".cache/images/fedora-44-kde-utm.qcow2" "8" "16"
```

It creates a new UTM VM named after the source Tart VM, with 8 CPU cores, 16 GB RAM, `virtio-gpu-gl-pci`, `virtio-sound-pci`, the Fedora icon, and dynamic resolution enabled. UTM copies the qcow2 into its own VM bundle on creation, so the intermediate file under `.cache/images/` can be deleted afterward — it isn't referenced again.

UTM's scripting dictionary has no "sound" property, so the sound device is set by patching the new VM's `config.plist` directly (see `scripts/utm-create.applescript`) right after creation. **If UTM was already running when the VM was created, quit and fully reopen UTM before starting the VM** — UTM caches each VM's config in memory once loaded, and a patched-on-disk plist isn't picked up until UTM itself restarts (stopping/starting the VM alone isn't enough). This also means: if `kernel-modules` (see below) is missing on a VM built before this fix, no `virtio-sound-pci` selection will produce audio — install `kernel-modules` in the guest and reboot it first.

## Targeting a different VM or resizing

The task's vars (`VM_NAME`, `CPUS`, `MEMORY_GB`, `RESOLUTION`) can be overridden two ways:

```sh
task fedora:utm VM_NAME=my-other-vm CPUS=4 MEMORY_GB=8
```

```sh
export VM_NAME=my-other-vm
task fedora:utm
```

**An inline prefix does *not* work** — `VM_NAME=my-other-vm task fedora:utm` silently falls back to the default:

```sh
VM_NAME=my-other-vm task fedora:utm   # still uses fedora-44-kde, not my-other-vm
```

Why: `taskfiles/fedora.yml` is included into the root Taskfile under the `fedora:` namespace. Task's `task <task> KEY=value` CLI-var syntax only overrides a variable declared at the *root* Taskfile's own scope — it doesn't reach into a namespaced included file's `vars:` block. `taskfiles/fedora.yml`'s vars are written as self-referencing defaults (`VM_NAME: '{{.VM_NAME | default "fedora-44-kde"}}'`) specifically so that both the CLI-var form and a plain shell `export` work; a bare inline-prefixed assignment on the same command line as `task` is what doesn't reach it.

One exception: the display resolution var is named `RESOLUTION`, not `DISPLAY`. Task auto-imports any ambient OS environment variable whose name matches a `vars:` entry — and `DISPLAY` is a standard X11 variable that XQuartz or an X11-forwarded SSH session commonly sets already, which would silently override the VM's resolution with an unrelated value. `RESOLUTION` avoids that collision.

## Running the AppleScript directly

Useful if you already have a qcow2 and want to skip the Tart conversion step:

```sh
osascript scripts/utm-create.applescript <vm-name> <qcow2-path> <cpu-cores> <memory-gb>
```

```sh
osascript scripts/utm-create.applescript fedora-44-kde /path/to/disk.qcow2 8 16
```

## Verifying 3D acceleration and audio in the guest

Once the UTM VM is running and you've logged in, the same check used to confirm the Tart VM is running software rendering also confirms the opposite here:

```sh
eglinfo | grep "EGL driver name"
```

On the Tart VM this reports `EGL driver name: kms_swrast` (software rendering). On the UTM VM with `virtio-gpu-gl-pci` it reports `EGL driver name: virtio_gpu` — both confirmed from live builds. If the UTM VM still reports `kms_swrast`, the guest fell back to software rendering and the display device isn't taking effect (check that the VM was actually created with `virtio-gpu-gl-pci`, not a default display, via UTM's VM settings). `mesa-vulkan-drivers` and `mesa-dri-drivers` are already installed by `customizations/fedora-kde.yml`.

For audio, confirm the card is visible to the kernel and to PipeWire:

```sh
cat /proc/asound/cards
wpctl status
```

Expect `virtio-snd - VirtIO SoundCard` and a `Virtio 1.0 sound (QEMU) Stereo` sink/source under `wpctl status`'s Audio section. If `/proc/asound/cards` is empty, `kernel-modules` is missing from the guest — Fedora Cloud's base image ships only `kernel-modules-core`, which has no sound drivers at all (`virtio_snd`, `snd-hda-intel`, etc. all live in `kernel-modules`). `customizations/fedora-kde.yml` installs it; a VM built before that fix needs `sudo dnf -y install kernel-modules` and a reboot.

## Cleaning up

Deleting the UTM VM is a normal UTM operation (VM list → right-click → Delete, or `utmctl delete <name>` if scripting) and does not touch the Tart VM or its disk. Re-running `task fedora:utm` against the same `VM_NAME` creates a fresh UTM VM from the Tart disk's current state; it does not update an existing UTM VM in place.
