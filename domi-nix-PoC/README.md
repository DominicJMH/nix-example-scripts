
## Proposed Architecture for the domi-nix System

The core idea is simple:

> Keep one lightweight, central NixOS configuration file that defines the minimal “domi-nix-like” interface, and move everything else into clean, modular components.

### The Problem with the Current Setup

Right now, much of the codebase is tightly coupled. Services, packages, and security features are intertwined. As a result:

* You can’t easily build or test individual components.
* You’re forced into an all-or-nothing system build.
* Iteration is slow and cumbersome.
* Testing specific features in isolation is painful.

This violates one of the major strengths of NixOS: composability and modularity.

---

## The Proposed Model

### 1. A Central, Minimal Configuration

We introduce a single top-level NixOS configuration file that:

* Defines only the **bare essentials** needed to resemble a domi-nix machine.
* Contains no deeply integrated services.
* Imports all functionality as separate modules.
* Acts as a single entry point for builds and tests.

This configuration should:

* Build on **NixOS**
* Build on other **Linux distributions**
* Build on **macOS (including Apple Silicon / M-series)** using Nix
* Run inside a lightweight VM on non-NixOS systems

The goal is not to ship full domi-nix functionality immediately but rather give the *appearance* of a domi-nix system. The actual services and logic are layered on afterward as modules.

---

## 2. Dendritic Structure

The architectural pattern to be used is reffered to as the **dendritic Nix structure**.

Think of it like this:

* One trunk (central configuration)
* Many independent branches (feature modules)
* Each branch can be attached, detached, or tested independently

Instead of embedding services directly into the main system configuration, we isolate them as feature modules.

A thorough explanation of that approach can be found here:

[https://discourse.nixos.org/t/how-do-you-structure-your-nixos-configs/65851/8](https://discourse.nixos.org/t/how-do-you-structure-your-nixos-configs/65851/8)

---

## 3. Independent Feature Modules

Each domi-nix feature should:

* Live in its own module
* Be imported from a single aggregation point
* Be buildable independently
* Be testable independently
* Support different architectures (x86_64, aarch64, etc.)
* Support different OS environments (NixOS, Linux VM, macOS VM)

This approach is inspired by the module testing strategy described here:

[https://phip1611.de/blog/nix-testing-a-single-nixos-module-in-ci/](https://phip1611.de/blog/nix-testing-a-single-nixos-module-in-ci/)

However, instead of using that idea purely for CI pipelines, we generalize it. The central configuration becomes a portable entry point capable of building across:

* NixOS
* Other Linux distributions
* macOS (including Apple Silicon / M-series machines)

---

## 4. Build Targets

The central configuration should support:

* Native NixOS builds
* Linux-based VMs (e.g., via QEMU)
* macOS-hosted NixOS VMs
* Potential future support for NixOS Compose (optional, not core)

On non-NixOS machines, the system runs inside a fast, lightweight VM so users can experiment with features without committing to a full system install.

For Linux hosts, this can follow the approach outlined here:

[https://www.thenegation.com/posts/nixos-on-qemu/](https://www.thenegation.com/posts/nixos-on-qemu/)

For macOS hosts:

[https://www.tweag.io/blog/2023-02-09-nixos-vm-on-macos/](https://www.tweag.io/blog/2023-02-09-nixos-vm-on-macos/)

Additionally, there is an alternative deployment model using NixOS Compose:

[https://www.youtube.com/watch?v=fXHDMqRT-Cg](https://www.youtube.com/watch?v=fXHDMqRT-Cg)

Note, the alternative deployment model is a nice-to-have. The Linux and macOS builds are necessary.

---

# Suggested File Structure

Here’s a concrete example of what this might look like.

```
domi-nix/
|
|-- flake.nix
|-- flake.lock
|
|-- systems/
|   |
|   |-- default.nix                # Central minimal domi-nix-like config
|   |-- profiles/
|   |   |-- minimal.nix            # Bare domi-nix UI shell
|   |   |-- full.nix               # Full feature set (optional)
|
|-- modules/
|   |
|   |-- services/
|   |   |-- service-a.nix
|   |   |-- service-b.nix
|   |
|   |-- security/
|   |   |-- hardening.nix
|   |   |-- sandboxing.nix
|   |
|   |-- packages/
|   |   |-- custom-pkg-a.nix
|   |   |-- custom-pkg-b.nix
|   |
|   |-- ui/
|   |   |-- domi-nix-shell.nix
|   |
|   |-- features/
|       |-- feature-x.nix
|       |-- feature-y.nix
|
|-- tests/
|   |
|   |-- feature-x-test.nix
|   |-- service-a-test.nix
|
|-- vm/
    |
    |-- linux-vm.nix
    |-- macos-vm.nix
```

---

## How It Works

### `systems/default.nix`

This is the trunk.

It contains:

* Minimal UI shell
* Base system configuration
* A single `imports = [ ... ];` block

Example conceptual form:

```
{
  imports = [
    ../modules/ui/domi-nix-shell.nix
    ../modules/features/feature-x.nix
    # other features toggled here
  ];
}
```

If you want to test only `feature-x`, you:

* Remove other imports
* Build the system
* Done

No full domi-nix rebuild required.

---

## Why This Is Better

### 1. Decoupling

Modules do not depend on hidden global assumptions. Each feature defines its own inputs and constraints.

### 2. Testability

You can build:

* Central config + one module
* Central config + specific feature set
* Single module in isolation

### 3. Portability

Because the system is flake-driven and modular:

* It works across architectures
* It works across host systems
* It works inside VMs
* It can be composed or deployed elsewhere later

### 4. Developer Ergonomics

Instead of “Build the entire system to test one change.”

We'll have “Import only the module I care about and build it.”

---

# Final Summary

The goal is:

* One lightweight, central NixOS configuration
* Zero deep coupling in the root configuration
* All functionality encapsulated as modules
* Single import point
* Independent testing
* Cross-platform build capability
* Optional VM execution for non-NixOS users

This preserves the dendritic structure and restores NixOS’s natural composability, while making domi-nix easier to build, test, and evolve.
