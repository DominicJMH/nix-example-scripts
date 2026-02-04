{
  description = "Onboarding agent packaged from a prebuilt GHCR image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        dockerToolsWithAuth =
          pkgs.dockerTools.override {
            skopeo = pkgs.writeScriptBin "skopeo" ''
              exec ${pkgs.skopeo}/bin/skopeo "$@" \
                --authfile=/tmp/auth.json
            '';
          };

        onboardingAgentImage =
          dockerToolsWithAuth.pullImage {
            imageName = "ghcr.io/tiiuae/tii-onboarding-agent";
            imageDigest =
              "sha256:<INSERT_IMAGE_SHA_HASH_FROM_GITHUB_REPO_HERE>";
            sha256 = "sha256-<INSERT_SHA_FROM_NIX_PREFETCH_HERE>";
            os = "linux";
            arch = "amd64";
          };
      in {
        packages.default = pkgs.runCommand "onboarding-agent" {
          nativeBuildInputs = [ pkgs.docker pkgs.undocker pkgs.coreutils pkgs.gnutar ];
        } ''
          set -euo pipefail

          mkdir -p $out/bin
          mkdir rootfs

          undocker ${onboardingAgentImage} rootfs.tar 
          
          tar -xf rootfs.tar -C rootfs

          cp rootfs/onboarding-agent $out/bin/onboarding-agent
          chmod +x $out/bin/onboarding-agent
        '';
      }
    );
}