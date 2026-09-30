# Development notes

Lessons learned building the Fedora KDE Plasma image and its UTM export, for whoever (human or agent) touches this repo next.

## Task (go-task) quirks

- Task runs `cmds:` scripts through `mvdan/sh`, an embedded POSIX-ish shell, not `/bin/bash` or `/bin/sh`. A few things behave differently from a real shell:
  - An `if COND; then ...; fi` with no `else`, as the *last* statement in a script, returns `COND`'s own exit status when the branch doesn't run — not `0` like POSIX/bash. If that `if` gates something optional (e.g. "delete the VM only if it exists"), and `COND` can legitimately be false, add a trailing `true` after the `fi` or the whole task fails even though nothing went wrong. See `taskfiles/fedora.yml`'s `build` task.
  - `disown` is not available (not a builtin in `mvdan/sh`).
- Task kills the entire process group of a `cmds` script once it finishes. Plain `&`, `nohup ... &`, and even `( ... & )` subshell-wrapped backgrounding all get reaped along with it — the child never survives past the task exiting. The only thing that reliably works is moving the child into its own session with `os.setsid()` before spawning it (a one-line `python3 -c '...'` invocation; see `taskfiles/tart.yml`'s `run` task). `setsid(1)` isn't shipped on macOS, so this needs a real fork/exec, not a shell builtin.
- Nested `includes` (a taskfile included by another included taskfile, not the root) don't reliably run with `ROOT_DIR` as their working directory — cross-namespace task calls (e.g. `fedora:packer:_cloud-init-iso`) can end up executing with the wrong cwd, breaking relative paths. Fix by anchoring every path in the included taskfile to `{{.ROOT_DIR}}` explicitly (don't rely on bare relative paths like `cloud-init/user-data`), and set `dir: "{{.ROOT_DIR}}"` on the include as a second line of defense.
- Command-line var overrides (`task some:task KEY=value`) only reach variables declared at the *root* Taskfile's own `vars:` scope. A variable declared inside a namespaced included file's own `vars:` block (e.g. `taskfiles/fedora.yml`'s `VM_NAME`) is invisible to that mechanism from outside the file.
- Task seeds its template variable namespace from the OS environment first, then overlays `vars:` on top — but only a *self-referencing* `vars:` entry (`FOO: '{{.FOO | default "x"}}'`) sees that seeded value; a plain literal (`FOO: "x"`) always wins regardless of environment. Use the self-referencing form for anything you want overridable by either `task t FOO=x` or `export FOO=x; task t`. A bare `FOO=x task t` (inline prefix on the same command line) does **not** work — that sets an OS env var for the `task` process itself, but Task's variable-seeding happens too early/differently for it to land in `.FOO` the same way `export` does before invocation.
- Corollary gotcha: because Task auto-imports *any* ambient env var whose name matches a `vars:` entry, naming a var the same as a well-known shell/X11 variable silently breaks it for a subset of users. `taskfiles/fedora.yml` originally named its resolution var `DISPLAY`; anyone with XQuartz installed (or an X11-forwarded SSH session) already has `$DISPLAY` set, which silently overrode the VM's resolution. Renamed to `RESOLUTION`. When adding a new overridable var, check it isn't already a common environment variable name.

## UTM / osascript quirks

- `sdef /Applications/UTM.app` can fail in a sandboxed tool context with "You have not agreed to the Xcode license agreements" even when it works fine in a real terminal. Read the dictionary straight from the bundle instead: `/Applications/UTM.app/Contents/Resources/UTM.sdef` (plain XML, no `sdef` binary needed).
- `tell application "UTM" to start "vm-name"` fails with `Can't make "vm-name" into type virtual machine. (-1700)`. The `start`/`stop`/`delete` commands take a virtual machine *specifier*, not a name string: `start (first virtual machine whose name is "vm-name")`.
- UTM's scripting dictionary (`UTM Configuration Suite`) has no "sound" property on `qemu configuration` at all — only `name`/`icon`/`notes`/`architecture`/`machine`/`memory`/`cpu cores`/`hypervisor`/`uefi`/`directory share mode`/`drives`/`network interfaces`/`serial ports`/`displays`/`qemu additional arguments`. There is no scriptable way to set the sound device at VM-creation time. `scripts/utm-create.applescript` works around this by patching the new VM's `config.plist` (`Sound[0].Hardware`) directly with `plutil` right after `make new virtual machine` returns.
- UTM caches each VM's configuration in memory once it's loaded it (which happens as soon as the VM exists in UTM's library, not just when it's running). Editing `config.plist` on disk while UTM.app is already running does **not** take effect — not even after stopping the VM — until UTM.app itself is fully quit and reopened. This bit both the sound-device fix and is worth remembering for any future scripted config patch: `osascript -e 'quit app "UTM"'`, `sleep`, then `open -a UTM` before relying on a plist edit.
- Some QEMU device choices in UTM's picker fail even though the hardware class they need genuinely exists elsewhere in the generated command line. `usb-audio` failed with `No 'usb-bus' bus found for device 'usb-audio'` even though `-device nec-usb-xhci,id=usb-bus` was present in the same invocation — QEMU builds its device tree by processing `-device` flags left to right, and UTM apparently emits the audio device before the controller it needs when that specific hardware string is picked. This isn't fixable from the scripting side; prefer a PCI-based device (`virtio-sound-pci`) that doesn't depend on argument ordering relative to a controller.
- The actual live `qemu-system-aarch64` invocation UTM built can be inspected directly: `ps aux | grep qemu-system`. This is far more informative than `config.plist` for debugging — it shows exact device wiring (e.g. that audio is routed as `-audiodev spice,id=audio0`, meaning UTM's own SPICE-backed window is the thing that has to play it, not raw host CoreAudio).
- `osascript app-scoped commands` need Automation permission (System Settings → Privacy & Security → Automation) granted to whatever process runs `osascript`; macOS prompts for it the first time.

## Fedora / Ansible lessons

- Fedora Cloud's base image ships only `kernel-modules-core` (storage/network essentials) — not `kernel-modules`, which is where `virtio_snd`, `snd-hda-intel`, and effectively every other driver module live. A device showing up in `lspci`/`lsusb` does not mean a driver exists to bind it; check `find /lib/modules/$(uname -r) -iname '*<driver>*'` (or `dnf provides '*/<module>.ko*'`) before assuming a missing feature is a QEMU/UTM problem rather than a missing package.
- `ansible-core` 2.18+'s `ansible.builtin.dnf5` module requires the `python3-libdnf5` bindings, which aren't preinstalled on the Fedora cloud image. Bootstrap it with a raw `ansible.builtin.command: dnf -y install python3-libdnf5` (guarded by `ansible.builtin.package_facts`) before the first `dnf5` task.
- `spice-vdagentd` and its `.socket` are static systemd units with no `[Install]` section. `ansible.builtin.systemd: {name: spice-vdagentd, enabled: true}` silently no-ops on them (`changed: false`, no error) rather than failing — static units can't be "enabled". Verify with `ActiveState == "active"` (query the unit with just `name:`, no state-changing params) instead of asserting `UnitFileState == "enabled"`.
- Prefer `ansible.builtin.package_facts` + `"'<pkg>' in ansible_facts.packages"` over `ansible.builtin.command: rpm -q ...`; the latter trips ansible-lint's `command-instead-of-module` rule and isn't check-mode-safe.
- A playbook meant for ad-hoc `ansible-playbook -i "<ip>,"` invocation must use `hosts: all`, not `hosts: default`. `default` only exists as a group when Packer's own `ansible` provisioner generates the inventory (as `cloud-init.pkr.hcl`'s provisioner does for `customizations/fedora-kde.yml` and `customizations/mate-desktop.yml`) — a bare comma-terminated IP string produces an ungrouped host that only `all` matches. `customizations/fedora-kde-verify.yml` is the ad-hoc case; the provisioning playbooks are the Packer case.

## Misc

- `ansible`/`ansible-playbook` invoked directly (outside Packer) in this session's sandboxed shell failed immediately with `ERROR: Ansible requires blocking IO on stdin/stdout/stderr` until stdin/stdout/stderr had `O_NONBLOCK` cleared first:

  ```sh
  python3 -c "
  import fcntl, os
  for fd in (0, 1, 2):
      fl = fcntl.fcntl(fd, fcntl.F_GETFL)
      fcntl.fcntl(fd, fcntl.F_SETFL, fl & ~os.O_NONBLOCK)
  "
  ```

  This doesn't persist across separate tool invocations — it has to be redone (or chained with `&&`) every time before an `ansible-playbook` call in a fresh shell.
