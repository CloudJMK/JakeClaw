# Deployment Guide — JakeClaw-V2

This guide walks you through deploying Jake from scratch, even if you have
never created a Proxmox VM before. Take it one step at a time.

---

## Before You Start

You will need:

- A Proxmox VE host (version 7 or 8) on your local network
- SSH access to the Proxmox host (or access to the Proxmox web UI)
- An Anthropic API key (get one at console.anthropic.com)
- A code editor on your local machine (any editor works)

You do **not** need to install anything on your laptop beyond SSH.

---

## Step 1 — Set Up Your Secrets File

Jake loads all secrets from a `.env` file in the **parent directory** of this
repo (i.e. `../.env` relative to the `JakeClaw/` folder). This keeps
credentials out of the repo entirely.

```bash
# On your local machine, from the repo root:
cp JakeClaw-V2/config/.env.example ../.env
```

Now open `../.env` in your editor and fill in every line marked `<REQUIRED>`:

| Variable | What to put here |
|---|---|
| `ANTHROPIC_API_KEY` | Your `sk-ant-...` key from console.anthropic.com |
| `JAKE_API_KEY` | Any strong random string (you make this up) |
| `LITELLM_MASTER_KEY` | Another strong random string |
| `CODE_SERVER_PASSWORD` | The password you will use to log into Jake's IDE |
| `OPENCLAW_RELOAD_TOKEN` | Another strong random string |
| `JAKECLAW_REPO` | The HTTPS URL of your fork of this repo |
| `PROXMOX_TEMPLATE_ID` | The VM ID of your Ubuntu 24.04 cloud-init template |
| `PROXMOX_STORAGE` | Your Proxmox storage pool name (often `local-lvm`) |

Everything else has a safe default — you can leave it for now.

**Tip:** Generate random secrets with: `openssl rand -hex 32`

---

## Step 2 — Prepare an Ubuntu 24.04 Template on Proxmox

Jake clones from a cloud-init-enabled Ubuntu template. You only need to do
this once per Proxmox host.

**On your Proxmox host shell** (SSH in or open the shell in the web UI):

```bash
# Download Ubuntu 24.04 cloud image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Create a VM (use any unused ID — we'll use 9000)
qm create 9000 --name ubuntu-24-cloud --memory 2048 --net0 virtio,bridge=vmbr0

# Import the disk
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm

# Configure it as a cloud-init template
qm set 9000 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-9000-disk-0 \
  --ide2 local-lvm:cloudinit \
  --boot order=scsi0 \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1

# Convert to template
qm template 9000
```

Set `PROXMOX_TEMPLATE_ID=9000` in your `.env`.

---

## Step 3 — Copy the Repo to Your Proxmox Host

The VM creation script needs access to the cloud-init templates. The easiest
way is to clone the repo onto the Proxmox host:

```bash
# On your Proxmox host:
git clone https://github.com/CloudJMK/JakeClaw /opt/JakeClaw
cp /path/to/.env /opt/JakeClaw/../.env   # copy your .env alongside it
```

Or SCP the files from your laptop:
```bash
scp -r ./JakeClaw root@<proxmox-ip>:/opt/
scp ../.env root@<proxmox-ip>:/opt/.env
```

---

## Step 4 — Edit the Cloud-Init User Data

Before creating the VM, you must fill in two values that the create script
cannot pull from `.env`:

- Your **SSH public key** (so you can SSH into the VM)
- A **hashed password** for the jake user

Generate your hashed password:
```bash
openssl passwd -6 'your-chosen-password'
```

After running `create-Jake-vm.sh` in the next step, the script will tell you
where the substituted `jake-user-data.yaml` file is. Open it and replace:

- `<<REPLACE_SSH_PUBLIC_KEY>>` — paste your `~/.ssh/id_ed25519.pub` (or similar)
- `<<REPLACE_HASHED_PASSWORD>>` — paste the output of the openssl command above

---

## Step 5 — Create the Jake VM

**On your Proxmox host:**

```bash
cd /opt/JakeClaw

bash JakeClaw-V2/templates/proxmox/create-Jake-vm.sh \
  --name jake \
  --memory 4096 \
  --cores 2
```

The script will:
1. Auto-select a VM ID
2. Upload the cloud-init snippets
3. Clone the template
4. Configure the hardware (root disk + /Jake-data disk)
5. Start the VM

**After the script finishes:**
- Open the user-data file it tells you about
- Fill in your SSH key and hashed password (see Step 4)
- Then go to the Proxmox web UI → your VM → Cloud-Init → click **Regenerate Image** → **Start**

> **Note:** The VM will appear to hang during first boot. This is normal —
> cloud-init is running all the install scripts in the background. It takes
> 5–10 minutes. You can watch progress in Proxmox → VM → Console.

---

## Step 6 — Find the VM's IP Address

Once the VM is running, find its IP:

```bash
# On Proxmox host:
qm agent <VM-ID> network-get-interfaces
```

Or check your router's DHCP leases, or look at the Proxmox console.

---

## Step 7 — Verify the Deployment

```bash
ssh jake@<VM-IP>
bash /JakeClaw/JakeClaw-V2/scripts/deploy-test.sh --verbose
```

You should see mostly green `PASS` lines. A few `SKIP` lines are normal if
some optional services aren't configured yet.

Common failures:
- **jake-api not running** — check `journalctl -u jake-api` and verify your API key/backend in `.env`
- **claw-code not running** — the binary may still be building; check `journalctl -u claw-code`
- **code-server password prompt** — make sure `CODE_SERVER_PASSWORD` was set in `.env` before bootstrap ran

---

## Step 8 — Open Jake's IDE

Navigate to in your browser:

```
http://<VM-IP>:8080
```

Enter your `CODE_SERVER_PASSWORD`. You should see VS Code in the browser.

Open a terminal inside code-server (`Ctrl+backtick`) and try talking to Jake
via the Continue.dev panel on the left sidebar.

---

## Post-Deployment Customization

### Change the AI model backend

Edit `../.env` on the VM:
```bash
# On the Jake VM:
nano /JakeClaw/../.env
# Change JAKE_API_BACKEND to: anthropic, openai, claw-local, or custom
sudo systemctl restart jake-api
```

### Trigger self-improvement now

```bash
sudo systemctl start jake-self-improve.service
tail -f /Jake-data/logs/self-improvement.log
```

### View all service logs

```bash
journalctl -u jake-api -u claw-code -u code-server@jake -u jake-self-improve -f
```

---

## Troubleshooting

| Symptom | Where to look |
|---|---|
| VM won't boot | Proxmox → VM → Console |
| Bootstrap failed | `cat /var/log/jake-bootstrap.log` |
| API key errors | `journalctl -u jake-api` |
| Continue.dev not connecting | Check `~/.continue/config.yaml` |
| Disk not mounted | `df -h /Jake-data` → re-check cloud-init user-data |

If you're stuck, the test suite output (`--verbose`) will usually tell you
exactly which component needs attention.

---

## Security Notes

- Jake's VM is designed for **private home-lab use**. Do not expose ports
  8000, 8080, or 8081 to the public internet without additional authentication.
- API keys live in `../.env` — never commit that file to git.
- Jake's sudo access is passwordless (by design for automation). Restrict this
  if Jake is ever on a shared network.
