# Pulling a Private GHCR Image with Nix and Extracting the Containerised Binary

This guide walks through how to pull a private image from GitHub Container Registry (GHCR) using a Nix flake, and then extract a binary from that container. The concrete example used throughout is the **TII onboarding agent** image.

At a high level, we will:

1. Locate the image in GHCR
2. Authenticate against the private registry
3. Pull the image using `dockerTools`
4. Prefetch the required hash for Nix
5. Extract the binary from the container filesystem

---

## 1. Finding the Image in GitHub Container Registry

Start by navigating to the **TII onboarding agent** GitHub repository. On the left-hand side, click **Packages** to see all published container images.

In our case, the package we care about is:

**`tii-onboarding-agent`**

Clicking into it will show a list of tagged versions. From there, you can identify the image reference, which looks something like:

```
ghcr.io/tiiuae/tii-onboarding-agent:1.4.0
```

For Nix, we only need the image name:

```
ghcr.io/tiiuae/tii-onboarding-agent
```

---

## 2. Attempting to Pull the Image with `dockerTools`

A natural first attempt is to use Nix’s built-in Docker tooling:

```nix
pkgs.dockerTools.pullImage {
  imageName = "ghcr.io/tiiuae/tii-onboarding-agent";
  imageDigest = "sha256:…";
}
```

However, this will fail for private repositories. The missing piece is **authentication**.

---

## 3. Authenticating with GHCR (Skopeo Under the Hood)

Internally, `dockerTools` uses **skopeo**. To authenticate properly, we need to give skopeo access to a Docker authentication file.

A helpful discussion explaining this can be found here:
[https://github.com/NixOS/nixpkgs/issues/30723#issuecomment-1692662760](https://github.com/NixOS/nixpkgs/issues/30723#issuecomment-1692662760)

### Step 1: Log in to GHCR

```bash
docker login ghcr.io
```

This creates an authentication file at:

```
~/.config/containers/auth.json
```

You can verify it exists:

```bash
cat ~/.config/containers/auth.json
```

Example output:

```json
{
  "auths": {
    "ghcr.io": {
      "auth": "THIS_STRING_IS_THE_AUTH_TOKEN"
    }
  }
}
```

### Step 2: Make the Auth File Available to Skopeo

```bash
mkdir -p /tmp/docker-config
cp ~/.config/containers/auth.json /tmp/docker-config/config.json

export DOCKER_CONFIG=/tmp/docker-config
```

---

## 4. Overriding `dockerTools` to Use the Auth File

Next, we override `dockerTools` so that skopeo explicitly uses our authentication file:

```nix
dockerToolsWithAuth =
  pkgs.dockerTools.override {
    skopeo = pkgs.writeScriptBin "skopeo" ''
      exec ${pkgs.skopeo}/bin/skopeo "$@" \
        --authfile=/tmp/auth.json
    '';
  };
```

This gets us part of the way there, but we’re still missing a critical piece of the puzzle.

---

## 5. Prefetching the Image Hash with `nix-prefetch-docker`

Because the image is private, Nix also requires the **content hash** (`sha256-…`) to verify the download. The easiest way to obtain this is with `nix-prefetch-docker`.

### Open a Shell with the Tool Available

```bash
nix-shell -p nix-prefetch-docker
```

### Run the Prefetch Command

`nix-prefetch-docker` takes:

* the image name
* the image digest

```bash
nix-prefetch-docker ghcr.io/tiiuae/tii-onboarding-agent \
  --image-digest sha256:<ENTER_YOUR_SHA_HERE>
```

Example output (trimmed):

```
-> ImageName: ghcr.io/tiiuae/tii-onboarding-agent
-> ImageDigest: sha256:<ENTER_YOUR_SHA_HERE>
-> ImageHash: sha256-...
{
  imageName = "ghcr.io/tiiuae/tii-onboarding-agent";
  imageDigest = "sha256:<ENTER_YOUR_SHA_HERE>";
  hash = "sha256-<THIS_IS_THE_IMAGE_HASH_WE_WANT>";
  finalImageName = "ghcr.io/tiiuae/tii-onboarding-agent";
  finalImageTag = "latest";
}
```

**Important:** Copy the value of `hash = "sha256-..."`.

---

## 6. Pulling the Image with Authentication and Hashes

Now we can finally pull the image successfully:

```nix
onboardingAgentImage =
  dockerToolsWithAuth.pullImage {
    imageName = "ghcr.io/tiiuae/tii-onboarding-agent";
    imageDigest = "sha256:<YOUR_IMAGE_DIGEST>";
    sha256 = "sha256-<HASH_FROM_NIX-PREFETCH>";
    os = "linux";
    arch = "amd64";
  };
```

At this point, Nix has everything it needs:

* authenticated registry access
* image digest
* verified content hash

---

## 7. Extracting the Binary from the Container

The final step is to unpack the container filesystem and copy out the binary. The following script (placed after the `in` of your `let` expression) does exactly that:

```bash
set -euo pipefail

mkdir -p $out/bin
mkdir rootfs

undocker ${onboardingAgentImage} rootfs.tar

tar -xf rootfs.tar -C rootfs

cp rootfs/onboarding-agent $out/bin/onboarding-agent
chmod +x $out/bin/onboarding-agent
```

Here’s what’s happening:

* `undocker` converts the image into a tarball
* the root filesystem is extracted
* the `onboarding-agent` binary is copied into `$out/bin`
* executable permissions are applied

---

## 8. Verifying the Result

Build the derivation:

```bash
nix build
```

A `result/` directory should appear. You can confirm the binary exists and runs:

```bash
cd result/bin
./onboarding-agent
```

You may see an error like:

```
panic: open /var/log/onboarding-agent.log: permission denied
```

The binary is running correctly, but it doesn’t have permission to write logs in this environment which can be fixed by running with sudo.

---
