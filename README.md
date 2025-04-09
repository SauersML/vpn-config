# OpenConnect VPN Automation via Bash Function and Keyring

## Goal

To create a reliable and convenient method for connecting to a Cisco AnyConnect-compatible VPN using the open-source `openconnect` client on Linux, automating the entry of username, password, and triggering a push-based Multi-Factor Authentication (MFA) factor like Duo Push, while securely storing the password locally.

## Problem Context

Connecting using `openconnect` sometimes succeeds initially but then disconnects shortly after (e.g., within ~1 minute) with errors like `CSTP Dead Peer Detection detected dead peer!`. This can occur even if authentication and MFA were successful. Often, during the brief connected period, external network connectivity is lost, indicating a potential routing or DNS configuration issue introduced by the VPN connection process.

## Solution Overview

The implemented solution utilizes a Bash shell function (intended to be placed in `~/.bashrc` or equivalent) combined with `secret-tool` (for interacting with the Gnome Keyring) and specific `openconnect` command-line flags.

**Key Components:**
1.  **Bash Function (`vpn_connect` or similar):** Encapsulates the logic for retrieving credentials and launching `openconnect`.
2.  **Gnome Keyring (`secret-tool`):** Securely stores the user's VPN password locally after the first use, avoiding the need to re-type it.
3.  **`openconnect` Flags:**
    *   `--passwd-on-stdin`: Allows securely piping the password (and appended MFA factor) to the client without exposing it as a command-line argument.
    *   `--no-dtls`: Forces the VPN data tunnel to use TLS (TCP) instead of DTLS (UDP).
    *   `--force-dpd <seconds>`: Sets the client-side Dead Peer Detection interval (e.g., 90 seconds).
    *   `--script <path>`: Explicitly defines the script used for network configuration (e.g., `/etc/vpnc/vpnc-script`).
4.  **Duo Append Mode:** The password stored in the keyring is combined with the desired Duo factor (e.g., `,push`) within the script before being passed to `openconnect`, triggering the MFA push automatically.

## Rationale and Reasoning

*   **Why `openconnect`?** Used as a Free/Open Source alternative when the official proprietary client is unavailable, incompatible (e.g., architecture mismatch like x86_64 vs ARM64), or undesirable.
*   **Why a Bash Function?** Provides a simple command to execute a multi-step process (check keyring, prompt if needed, store if needed, combine password+MFA, run `openconnect` with sudo and flags).
*   **Why Gnome Keyring (`secret-tool`)?** Provides standard, secure local storage for sensitive data like passwords. The keyring is typically unlocked automatically on user login, offering convenience without storing the password in plaintext files or the script itself.
*   **Why `--passwd-on-stdin`?** More secure than passing passwords directly as command-line arguments, which can be visible to other users on the system via process lists (`ps`).
*   **Why Duo Append Mode (Password + `,push`)?** Leverages the VPN server's likely support for Duo's append mode to trigger the desired MFA factor automatically without requiring an interactive prompt from `openconnect` for the second factor.
*   **Why `--no-dtls`?** This is often the **critical fix** for the "Dead Peer Detection" disconnects. DTLS (UDP) can be unreliable due potentially blocked UDP traffic by firewalls/NAT, or general network instability. Forcing the entire connection over TLS (TCP) is typically more robust and ensures keepalive packets aren't lost due to UDP issues.
*   **Why `--force-dpd 90`?** Increases the time `openconnect` waits for a keepalive response before assuming the connection is dead. This adds resilience against minor network latency or packet delays, complementing the stability gained from `--no-dtls`.
*   **Why `--script /etc/vpnc/vpnc-script`?** While often found implicitly, explicitly defining the standard script ensures the correct helper is used for setting up routes and DNS after connection, preventing network configuration errors that can cause loss of connectivity and subsequent DPD failures.

## Required Dependencies (Linux)

*   `openconnect`: The VPN client.
*   `libsecret`: Provides the `secret-tool` command for keyring interaction. (Package name may vary slightly by distribution).

## Setup Summary (Generic)

1.  Install `openconnect` and `libsecret` packages using the system package manager (e.g., `dnf`, `apt`).
2.  Add the provided bash function definition to `~/.bashrc`.
3.  Reload the shell (`source ~/.bashrc` or open a new terminal).
4.  Run the function for the first time. Enter the VPN password (only) when prompted. Choose 'y' to store it securely in the keyring.
5.  Approve the MFA prompt (e.g., Duo Push) on the registered device.
6.  Subsequent runs only require executing the function name and approving the MFA prompt.
