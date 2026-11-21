# ippas-factory

The one command that turns a fresh Debian 12 box into an IP-PAS appliance. Run it as root:

```bash
wget -O- https://raw.githubusercontent.com/Elpro-Energy/ippas-factory/main/ippas-factory.sh | bash
```

It asks for the GitHub read token and the enrolment code from the hub admin (`XXXX-XXXX-XXXX`; both hidden), clones the private IP-PAS repo and starts the install. The install carries on by itself through two reboots, registers the box on the remote-access hub, and ends with `FACTORY OK` and the box's name on the hub (2 to 3.5 hours). Ctrl-C only stops watching; run the same command again to watch. Full instructions: `factory/README.md` in the IP-PAS repo.

The box needs outbound UDP 443 and TCP 443 to `106.51.29.35`; nothing inbound.

This repo is public on purpose and holds no secrets.
