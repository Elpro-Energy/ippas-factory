# IP-PAS factory bootstrap

Turns a fresh Debian 12 (amd64) box into an IP-PAS appliance. On the box, as root:

```bash
wget -qO- https://raw.githubusercontent.com/Elpro-Energy/ippas-factory/main/ippas-factory.sh | bash
```

You need the factory access token. The script asks for it with the input hidden.

The box installs itself in about 80 minutes and reboots twice. It continues by itself after each reboot, so you can close the session. To watch progress, run the same command again. When the box is done, the log ends with `FACTORY OK`.

This repository holds only the bootstrap. The appliance software is private.
