{ pkgs, ... }: {
  boot.kernelPackages = pkgs.linuxPackages_latest;
  services.openssh.enable = true;
  documentation.enable = false;

  # === IPv6 Configuration ===
  networking.enableIPv6 = true;
  
  # Configure dhcpcd to request IPv6 addresses (works in most VM environments)
  networking.dhcpcd.enable = true;
  networking.dhcpcd.extraConfig = ''
    # Request IPv6 router advertisements and autoconf
    ipv6rs
    ipv6autoconf
    # Reduce wait time for DHCP (useful for quick VM boots)
    timeout 5
  '';

  # Optional: Disable firewall for easier testing
  # networking.firewall.enable = false;

  # === Useful networking tools for testing ===
  environment.systemPackages = with pkgs; [
    inetutils  # ping6, ifconfig
    iproute2   # ip -6 addr, ip -6 route
    curl       # test HTTP over IPv6
    jq         # parse JSON responses if needed
  ];

  # === IPv6 Self-Test Service ===
  # Runs on boot and logs results to /var/log/ipv6-test.log
  systemd.services.ipv6-selftest = {
    enable = true;
    description = "Verify IPv6 stack is functional";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal";
      StandardError = "journal";
    };
    script = ''
      LOGFILE="/var/log/ipv6-test.log"
      echo "=== IPv6 Self-Test $(date) ===" > "$LOGFILE"
      
      # 1. Verify kernel IPv6 support
      echo -n "Kernel IPv6 support: " >> "$LOGFILE"
      if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]; then
        if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" = "0" ]; then
          echo "enabled" >> "$LOGFILE"
        else
          echo "disabled" >> "$LOGFILE"
          echo "FAIL: IPv6 disabled in kernel" >&2
          exit 1
        fi
      else
        echo "? unknown" >> "$LOGFILE"
      fi
      
      # 2. Check for IPv6 addresses on non-loopback interfaces
      echo "Global IPv6 addresses:" >> "$LOGFILE"
      GLOBAL_ADDRS=$(${pkgs.iproute2}/bin/ip -6 addr show scope global | grep -c "inet6" || true)
      if [ "$GLOBAL_ADDRS" -gt 0 ]; then
        echo "Found $GLOBAL_ADDRS global IPv6 address(es)" >> "$LOGFILE"
        ${pkgs.iproute2}/bin/ip -6 addr show scope global >> "$LOGFILE" 2>&1
      else
        echo "No global IPv6 addresses (this is expected in isolated VMs like the one were testing in now)" >> "$LOGFILE"
      fi
      
      # 3. Test IPv6 loopback connectivity
      echo -n "IPv6 loopback (::1) ping: " >> "$LOGFILE"
      if ${pkgs.inetutils}/bin/ping6 -c 1 -W 2 ::1 >/dev/null 2>&1; then
        echo "success" >> "$LOGFILE"
      else
        echo "failed" >> "$LOGFILE"
        echo "WARN: Loopback ping failed" >&2
      fi
      
      # 4. Show IPv6 routing table
      echo "IPv6 routing table:" >> "$LOGFILE"
      ${pkgs.iproute2}/bin/ip -6 route show >> "$LOGFILE" 2>&1
      
      # 5. Optional: Test external IPv6 if connectivity exists
      echo -n "External IPv6 test (example.com): " >> "$LOGFILE"
      if ${pkgs.curl}/bin/curl -6 -s --connect-timeout 5 https://example.com >/dev/null 2>&1; then
        echo "reachable" >> "$LOGFILE"
      else
        echo "unreachable (may be expected)" >> "$LOGFILE"
      fi
      
      echo "=== Test Complete ===" >> "$LOGFILE"
      cat "$LOGFILE"  # Also output to journal for easy viewing
      exit 0
    '';
  };
}