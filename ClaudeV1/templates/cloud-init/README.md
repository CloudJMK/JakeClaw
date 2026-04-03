# Cloud-init Templates

These files are injected into a Proxmox Ubuntu 24.04 VM at first boot via the
`cicustom` parameter (see `create-Jake-vm.sh`).

## Files

| File | Purpose |
|---|---|
| `user-data.yaml` | Creates `jake` user, installs packages, clones repo, runs bootstrap |
| `network-config.yaml` | DHCP by default; static IP example included |

## Before You Deploy

### 1. Inject your SSH public key

Open `user-data.yaml` and replace `{{SSH_PUBLIC_KEY}}` with your actual public key:

```bash
# Get your key:
cat ~/.ssh/id_ed25519.pub
# or generate one:
ssh-keygen -t ed25519 -C "jake-deploy"
```

### 2. Set a password (optional)

Replace `{{JAKE_PASSWORD}}` with a hashed password:

```bash
openssl passwd -6 'your-strong-password'
```

Or set `lock_passwd: true` and rely on SSH key only (recommended).

### 3. Set the Jake data disk (optional)

If you're attaching a second virtual disk for `/Jake-data` persistence,
replace `{{JAKE_DATA_DISK}}` with the block device (e.g. `/dev/sdb`).

If you only have one disk, comment out the disk-format block in `runcmd`.

### 4. Set the repo URL

Replace `{{JAKECLAW_REPO}}` with your fork URL, e.g.:

```
https://github.com/CloudJMK/JakeClaw.git
```

### 5. Static IP (optional)

Edit `network-config.yaml`: comment out the DHCP block and fill in the
static section with your desired IP, gateway, and DNS servers.

## How Proxmox Uses These Files

```bash
# Upload to Proxmox local storage (snippets)
scp templates/cloud-init/*.yaml proxmox-host:/var/lib/vz/snippets/

# Or let create-Jake-vm.sh handle this automatically
bash templates/proxmox/create-Jake-vm.sh --name my-jake ...
```

The `cicustom` VM parameter tells Proxmox where to find the files:

```
cicustom: "user=local:snippets/user-data.yaml,network=local:snippets/network-config.yaml"
```

## Idempotency

`runcmd` entries check for existing state before acting (git clone only if not
already cloned, mkfs only if not already formatted). Re-running is safe.
