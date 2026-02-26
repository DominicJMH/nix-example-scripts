# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  
  # === IPv6 Configuration ===
  networking.enableIPv6 = true;
  
  # Configure dhcpcd to request IPv6 addresses 
  # Note: dhcpcd may conflict with NetworkManager; adjust if needed
  networking.dhcpcd.enable = true;
  networking.dhcpcd.extraConfig = ''
    # Request IPv6 router advertisements and autoconf
    ipv6rs
    ipv6autoconf
    # Reduce wait time for DHCP
    timeout 5
  '';

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.dominic = {
    isNormalUser = true;
    description = "Dominic";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  # Disable documentation to save space
  documentation.enable = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    # === Useful networking tools for testing ===
    inetutils  # ping6, ifconfig
    iproute2   # ip -6 addr, ip -6 route
    curl       # test HTTP over IPv6
    jq         # parse JSON responses if needed
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  
  networking.firewall.enable = false;

  networking.firewall.allowPing = true;

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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}