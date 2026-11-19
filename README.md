# ippas-factory

The one command that turns a fresh Debian 12 box into an IP-PAS appliance. Run it as root:

```bash
wget -O- https://raw.githubusercontent.com/Elpro-Energy/ippas-factory/main/ippas-factory.sh | bash
```

It asks for the GitHub read token, clones the private IP-PAS repo and starts the install, which carries on by itself through two reboots until `FACTORY OK` (2 to 3.5 hours). Ctrl-C only stops watching; run the same command again to watch. Full instructions: `factory/README.md` in the IP-PAS repo.

This repo is public on purpose and holds no secrets.
