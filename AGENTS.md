# AGENTS.md

## Build boundaries

- This is VM image infrastructure, not a Python application; `pyproject.toml` and `uv.lock` supply Ansible tooling (Python 3.13).
- The root Packer template clones `vm_base_name`, attaches `cloud-init.iso`, installs `99_cirruslabs.cfg`, runs `customizations/mate-desktop.yml`, then cleans guest identity and disables cloud-init. The MATE playbook requires `customizations/vars.yml`.
- Runner templates are separate Packer roots: run commands from `customizations/linux-runner/` or `customizations/linux-runner-gpu/` because their provisioner paths are relative. The GPU template clones `ghcr.io/cirruslabs/ubuntu-runner-amd64:latest`; it is not the local Ubuntu/MATE build.
- The root template's `playbook` variable selects the provisioner (default `customizations/mate-desktop.yml`); `taskfiles/fedora.yml` overrides it to `customizations/fedora-kde.yml`. Both playbooks share the identity-cleanup and `cloud-init.disabled` shell provisioners in `cloud-init.pkr.hcl`, which are now distro-agnostic (`command -v apt-get`/`dnf` guards) instead of apt-only.
- Tart's Linux guests run on Apple's Virtualization.framework, which only exposes a 2D virtio-gpu — there is no 3D acceleration in a Tart-run VM regardless of playbook. `taskfiles/fedora.yml`'s `utm` task re-exports the same provisioned disk to a UTM/QEMU VM (`virtio-gpu-gl-pci`) for that.

## Local commands

- Local ISO tasks require macOS `hdiutil`; Tart's documented host is Apple Silicon on macOS 13+. Use mise-managed versions from `.tool-versions`; make the Ansible environment's executables available on `PATH` for Packer.
- Run Task commands from the repository root. `task --list` lists entrypoints; the root Taskfile loads `.env`.
- Configure ignored `variables.pkrvars.hcl` from `variables.pkrvars.hcl.example`. The example selects Debian despite the Ubuntu-specific MATE provisioner and omits required `ssh_username`, `ssh_password`, and `display`; cloud-init fixtures provision `admin` / `admin`.
- Build order: `task packer:init` (runs `packer init -upgrade .`), then `task packer:build` (generates the ISO and passes `-var-file="variables.pkrvars.hcl"`).
- Inspect/run the actual output with `task tart:list` and `task tart:run -- <vm_name>`. Images live in Tart's VM store, not `build/ubuntu-custom`, despite the build task's `generates` declaration.

## Task and provisioning traps

- ISO generation depends on `packer:clean`, which removes `build/*`, `cloud-init.iso`, and `cidata/`. Do not treat ISO regeneration as a read-only check.
- `packer:without-admin` depends on both the no-admin ISO task and `build`, but `build` itself depends on the admin-group ISO task. For a no-admin fixture, run `task packer:iso-only-no-admin`, then invoke `packer build -var-file="variables.pkrvars.hcl" .` directly; the root MATE provisioner remains Ubuntu-specific.
- `task packer:test` rebuilds and hardcodes cloning `ubuntu` to `ubuntu-test`; it is a manual VM launch, not an automated test suite, and does not honor a different configured VM name.
- Preserve `dhcp-identifier: mac` in both `cloud-init/network-config` and `99_cirruslabs.cfg`: it makes macOS DHCP leases discoverable by `tart ip`.
- `99_cirruslabs.cfg` disables cloud-init data sources to preserve growpart, but the root template later creates `/etc/cloud/cloud-init.disabled`. Account for this discrepancy when changing disk-growth or first-boot behavior.

## Verification and CI

- Non-building HCL checks: `packer fmt -check -recursive .` and `packer validate -syntax-only .`. After plugin initialization and ISO generation, use `packer validate -var-file="variables.pkrvars.hcl" .` for full root-template validation. Validate runner roots separately with `-var 'vm_name=<name>'`.
- `customizations/linux-runner/test.sh` is executed inside the provisioned guest with `bash -l`; it only checks that `ANDROID_HOME` is set. Running it on the host does not validate an image.
- `.cirrus.yml` builds cloud disks from scratch: download QCOW2 → convert to raw → generate a `cidata` ISO with `mkisofs` → `tart create --linux` → replace the VM disk → root Packer → optional runner Packer. Distro fixtures and architecture selections are defined there; registry pushes occur only for cron builds.
- CI's root `packer build -var vm_name="$VM_ID" .` omits required SSH/display variables and leaves `vm_base_name` at its Ubuntu registry default despite creating a VM from a distro disk first. Reconcile these inputs when changing the root build; local Task and CI builds are not equivalent.
- For Tart documentation, use Context7 library `/openai/tart`; the Packer plugin source remains `github.com/cirruslabs/tart` as declared in `providers.pkr.hcl`.
