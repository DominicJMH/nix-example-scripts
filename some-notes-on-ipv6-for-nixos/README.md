# Enabling and Verifying IPv6 on NixOS

These notes describe how to:

1. Enable IPv6 on a **NixOS** machine.
2. Demonstrate connectivity between that NixOS machine and an **Ubuntu** laptop connected via Ethernet.
3. Add a boot-time self-test using a systemd service to verify that the IPv6 stack is working correctly.

The configuration is defined in `configuration.nix`, and it consists of two main parts:

* **Part 1 – Basic IPv6 enablement**
* **Part 2 – A systemd-based IPv6 self-test**

---

## Part 1: Enabling IPv6 on NixOS

NixOS follows a deliberately minimal philosophy: very little is enabled unless you explicitly configure it. This is powerful, but it can be surprising if you are coming from other Linux distributions where more networking functionality is enabled by default.

You may enable IPv6 in `configuration.nix`, rebuild the system, and still find that `ping6` fails. The most common reason is the firewall configuration.

### The Critical Setting

You must explicitly allow ICMP (which includes ping):

```nix
networking.firewall.allowPing = true;
```

Without this, IPv6 pings will fail — often with misleading errors such as:

```
Network is unreachable
```

This behavior is documented in a long-standing NixOS issue:
[https://github.com/NixOS/nixpkgs/issues/12927](https://github.com/NixOS/nixpkgs/issues/12927)

The key takeaway is that NixOS does not assume you want ping enabled. You must opt in.

---

## Applying the Configuration

After updating `configuration.nix`, run:

```bash
sudo nixos-rebuild switch
```

Once rebuilt, you can test IPv6 connectivity between two laptops connected directly via Ethernet.

---

## Testing IPv6 Connectivity Between Two Machines

### Step 1: Identify the IPv6 Address and Interface

On one of the machines, run:

```bash
ip -6 addr show
```

Look for:

* The Ethernet interface name (e.g., `enp0s31f6`, `eth0`, etc.)
* The link-local IPv6 address (typically beginning with `fe80::`)

---

### Step 2: Ping the Other Machine

From the other laptop, run:

```bash
ping6 -c 4 fe80::<other-laptop-address>%<interface>
```

For example:

```bash
ping6 -c 4 fe80::bb0e:8024:bf8:890f%enp0s20f0u3u2u1
```

**Important:**
When using a link-local (`fe80::`) address, you *must* specify the interface using `%<interface>`.

If everything is configured correctly, you should receive replies confirming IPv6 connectivity.

---

# Part 2: Boot-Time IPv6 Sanity Test (systemd Service)

The second part of the configuration (lines 150–217 in `configuration.nix`) defines a systemd service named:

```
ipv6-selftest
```

This service runs once at boot and writes a detailed diagnostic report to:

```
/var/log/ipv6-test.log
```

It performs several checks:

---

## What the Self-Test Verifies

### 1. Kernel IPv6 Support

It checks:

```
/proc/sys/net/ipv6/conf/all/disable_ipv6
```

If IPv6 is disabled at the kernel level, the service exits with failure.

---

### 2. Global IPv6 Addresses

It checks for globally scoped IPv6 addresses on non-loopback interfaces.

If none are found, it reports that — which is expected in isolated environments such as VMs without upstream IPv6 connectivity.

---

### 3. IPv6 Loopback

It attempts to ping:

```
::1
```

This confirms that the local IPv6 stack is functioning.

---

### 4. IPv6 Routing Table

It logs the output of:

```bash
ip -6 route show
```

This confirms whether proper routes exist.

---

### 5. External IPv6 Connectivity (Optional)

It attempts a `curl -6` request to:

```
https://example.com
```

If external IPv6 connectivity exists, it reports success. If not, it marks it as unreachable — which may be expected depending on the environment.

---

# Viewing the Results

After rebooting the NixOS machine, open a terminal and run:

```bash
cat /var/log/ipv6-test.log
```

This file provides a structured diagnostic report detailing:

* Whether IPv6 is enabled in the kernel
* Whether addresses are assigned
* Whether loopback works
* What routes exist
* Whether external IPv6 is reachable

