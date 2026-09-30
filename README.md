# Linux Packer Templates for Tart

Repository with Packer templates to build [Tart VMs](https://github.com/openai/tart).

See a full list of VMs available [here](https://github.com/orgs/cirruslabs/packages?repo_name=linux-image-templates).

## Fedora KDE Plasma

`task fedora:build` provisions a Fedora 44 KDE Plasma desktop at 2560x1440 (QHD), autologin via `plasmalogin`. Build order:

```sh
task fedora:base    # downloads the Fedora aarch64 cloud image and creates the base Tart VM
task fedora:build    # provisions KDE Plasma via customizations/fedora-kde.yml
task fedora:run      # tart run fedora-44-kde
task fedora:verify   # runs customizations/fedora-kde-verify.yml against a running VM
```

Tart runs Linux guests through Apple's Virtualization.framework, which only exposes a 2D virtio-gpu, so this VM renders with software GL (llvmpipe). For 3D-accelerated video/GL work, `task fedora:utm` converts the built disk to qcow2 and creates a UTM VM using QEMU's `virtio-gpu-gl-pci` device, which UTM renders through its ANGLE/Metal backend. Both paths share the same provisioned disk; only the display hardware differs.
