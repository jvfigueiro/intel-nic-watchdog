# Intel NIC Watchdog & Offload Fix

A lightweight, highly resilient Bash watchdog script designed to mitigate the notorious hardware/driver hangs (TX/RX timeouts) affecting Intel Network Interface Cards (NICs) on Linux, particularly in headless environments and hypervisors.

## 🚨 Problem

Several Intel Ethernet controllers (especially the `e1000e` family, I225-V, and I226-V) suffer from a well-documented hardware/driver bug where the interface intermittently stops passing traffic. The kernel throws a hardware hang error, completely dropping the network connection until the interface is manually reset. 

This is a known issue at the kernel level. For reference, see this [mainline Linux kernel commit](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/drivers/net/ethernet/intel/e1000e/netdev.c?h=v6.19-rc3&id=b10effb92e272051dd1ec0d7be56bf9ca85ab927) addressing `e1000e` hangs.

In headless servers, this bug is catastrophic as it results in total loss of remote management.

## 💡 Solution

This watchdog script runs silently via `cron` and acts as an automated self-healing mechanism. It performs the following routine:

1. **Physical Link Check:** It first verifies the `carrier` status. If the cable is physically unplugged, the script exits cleanly to prevent false positives and log spam.
2. **Connectivity Test:** It pings the defined gateway. If it fails, it waits 15 seconds and retries to rule out temporary network drops.
3. **Soft Reset & Offload Patch:** If the gateway remains unreachable, it forces the interface down and crucially uses `ethtool` to disable `tso` (TCP Segmentation Offload) and `gso` (Generic Segmentation Offload) — the primary triggers for these driver crashes — before bringing the interface back up.
4. **Failsafe:** If the reset doesn't restore connectivity (e.g., an actual ISP outage), it logs the diagnostic event but keeps the system active for local services, avoiding unnecessary reboot loops.

## ⚙️ Installation & Usage

1. Clone this repository to your server:
```bash
git clone [https://github.com/jvfigueiro/intel-nic-watchdog.git](https://github.com/jvfigueiro/intel-nic-watchdog.git)
cd intel-nic-watchdog
```

2. Make the script executable:

```bash
chmod +x intel_nic_watchdog.sh
```

3. Edit the script to match your environment variables:

```bash
nano intel_nic_watchdog.sh
```

Update the `TARGET` (your gateway IP) and `IFACE` (your physical interface, e.g., `eno1`, `enp3s0`, or `nic0`) variables.

4. Add the script to the root `crontab` to run every minute:

```bash
crontab -e
```

Add the following line:

```bash
* * * * * /path/to/intel-nic-watchdog/intel_nic_watchdog.sh >/dev/null 2>&1
```

## 📊 Logging

The script maintains a clean, timestamped log of all critical events, interface resets, and connectivity failures at `/var/log/watchdog_rede.log`.
You can monitor its activity by checking the log file:

```bash
tail -f /var/log/watchdog_rede.log
```

## ⚖️ License

MIT License. Feel free to use, modify, and distribute this script.

