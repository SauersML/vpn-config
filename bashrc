univvpn() {
    # --- Configuration ---
    local VPN_SERVER="tc-vpn-1.vpn.univ.edu"
    local VPN_USER="username"  # <<< Your univ ID
    local VPN_GROUP="AnyConnect-UofMvpnFull" # Using Full Tunnel
    local DUO_FACTOR="push" # Your desired Duo factor
    local STORED_PASSWD
    # Attributes to identify the secret in the keyring (unique name)
    local KEYRING_ATTR_APP="vpn_app_pw_only_auto_push_state"
    local KEYRING_ATTR_SERVICE="univ_vpn"
    local KEYRING_ATTR_USER_FIELD="user"
    # -------------------

    echo "Attempting to connect to univ VPN ($VPN_GROUP) as $VPN_USER..."

    # Try to look up the password from the keyring
    STORED_PASSWD=$(secret-tool lookup "$KEYRING_ATTR_APP" "$KEYRING_ATTR_SERVICE" "$KEYRING_ATTR_USER_FIELD" "$VPN_USER" 2>/dev/null)

    # Check if the lookup failed or returned empty string
    if [ $? -ne 0 ] || [ -z "$STORED_PASSWD" ]; then
        echo "univ VPN password not found in keyring or lookup failed."
        echo "Please enter it now to use and optionally store it."
        echo -n "Enter univ Password (ONLY the password, Duo factor '$DUO_FACTOR' will be added automatically): "
        read -s STORED_PASSWD # -s hides the input
        echo

        if [ -z "$STORED_PASSWD" ]; then
            echo "No password entered. Aborting."
            return 1
        fi

        # Ask to store it
        read -p "Store this password in Gnome Keyring for future use? (y/N): " STORE_SECRET
        if [[ "$STORE_SECRET" =~ ^[Yy]$ ]]; then
            echo -n "$STORED_PASSWD" | secret-tool store --label="univ VPN Password (only) for $VPN_USER" \
                "$KEYRING_ATTR_APP" "$KEYRING_ATTR_SERVICE" \
                "$KEYRING_ATTR_USER_FIELD" "$VPN_USER"
            if [ $? -eq 0 ]; then echo "Password stored successfully in keyring."; else echo "Failed to store password in keyring."; fi
        fi
    else
        echo "Retrieved password from keyring."
    fi

    # Combine retrieved/entered password with the chosen Duo factor
    local PASSWD_WITH_DUO="${STORED_PASSWD},${DUO_FACTOR}"

    # Pipe the combined password+Duo string to openconnect with troubleshooting flags
    echo "Connecting and triggering Duo factor '$DUO_FACTOR' (using --force-dpd 90 --no-dtls)..."
    echo "$PASSWD_WITH_DUO" | sudo openconnect "$VPN_SERVER" --user="$VPN_USER" --authgroup="$VPN_GROUP" --passwd-on-stdin --force-dpd 90 --no-dtls --script /etc/vpnc/vpnc-script

    # Check the exit status
    if [ $? -ne 0 ]; then echo "VPN connection failed or was disconnected."; else echo "VPN connection process finished."; fi
}
