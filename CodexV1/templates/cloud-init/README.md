# Cloud-init templates

## Before first boot

1. Replace `{{SSH_PUBLIC_KEY}}` in `user-data.yaml`.
2. Replace `{{JAKE_REPO_URL}}` and `{{JAKE_REPO_REF}}` in `user-data.yaml`.
3. Adjust package lists if your image already includes some tools.
4. Review `network-config.yaml` and keep DHCP or uncomment the static block.

## Notes

- The bootstrap wrapper is written to `/tmp/bootstrap-Jake.sh` and runs once on first boot.
- The wrapper clones the repo into `/opt/JakeClaw` and then calls `scripts/bootstrap-Jake.sh --force`.
- If you inject secrets at boot time, prefer your cloud-init secret store or a pull step in the bootstrap script rather than committing values to the repo.
