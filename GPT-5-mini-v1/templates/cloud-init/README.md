Cloud-init templates

Files:
- user-data.yaml: cloud-config to create the `jake` user, install base packages, and run a bootstrap script. Contains `{{SSH_PUBLIC_KEY}}` placeholder — replace before using.
- network-config.yaml: netplan example (DHCP by default, static example commented).

Usage:
- Inject your SSH public key into `user-data.yaml` (replace `{{SSH_PUBLIC_KEY}}`).
- If you host the repo publicly, consider replacing the embedded bootstrap stub with a curl/wget to your `bootstrap-Jake.sh` in the repo.

Caveats:
- Do NOT store private keys in the repo.
- Review `runcmd` and `write_files` before booting a VM to avoid unexpected commands.
