#!/bin/bash
# add to /sbin/ and make executable
# edit /etc/pam.d/sshd and add:
# session  optional  pam_exec.so /sbin/sshd-login
# to bottom of the file

WEBHOOK_URL="URL"
DISCORDUSER="<@&ROLE_ID> or <@USER_ID>"
URGENT_ROLE="<@&ROLE_ID> or <@USER_ID>"

# File to store previously seen IP addresses
IP_FILE="/var/log/seen_ips.log"

# Function to check if IP is new
is_new_ip() {
    local ip="$1"
    while read -r line; do
        if [ "$line" = "$ip" ]; then
            return 1  # IP address found, not new
        fi
    done < "$IP_FILE"
    return 0  # IP address not found, new
}

# Function to record seen IP
record_ip() {
    local ip="$1"
    echo "$ip" >> "$IP_FILE"
}

# Ensure the file exists
touch "$IP_FILE"

# Capture only open and close sessions.
case "$PAM_TYPE" in
    open_session)
        if is_new_ip "$PAM_RHOST"; then
            PAYLOAD=" { \"content\": \"$URGENT_ROLE: User \`$PAM_USER\` logged in to \`$HOSTNAME\` (NEW remote host: $PAM_RHOST).\" }"
            record_ip "$PAM_RHOST"
        else
            PAYLOAD=" { \"content\": \"$DISCORDUSER: User \`$PAM_USER\` logged in to \`$HOSTNAME\` (remote host: $PAM_RHOST).\" }"
        fi
        ;;
    close_session)
        PAYLOAD=" { \"content\": \"$DISCORDUSER: User \`$PAM_USER\` logged out of \`$HOSTNAME\` (remote host: $PAM_RHOST).\" }"
        ;;
esac

# If payload exists, fire webhook
if [ -n "$PAYLOAD" ]; then
    curl -X POST -H 'Content-Type: application/json' -d "$PAYLOAD" "$WEBHOOK_URL"
fi
