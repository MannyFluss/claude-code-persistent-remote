#!/bin/bash
# Claude Code Persistent Remote Setup
# Run this as your main user (not root) on a Debian/Ubuntu system.
# Some steps require manual interaction - the script will pause and tell you when.

set -e

CLAUDE_USER="claude"
MAIN_USER="$(whoami)"
PROJECT_DIR="/home/$CLAUDE_USER/ClaudePersistentRemoteSession"
SERVICE_NAME="claude-remote"

echo "=== Claude Code Persistent Remote Setup ==="
echo "Main user: $MAIN_USER"
echo "Claude user: $CLAUDE_USER"
echo ""

# ── Phase 1: Create claude linux user ────────────────────────────────────────

echo "[Phase 1] Creating claude linux user..."

if id "$CLAUDE_USER" &>/dev/null; then
    echo "  User '$CLAUDE_USER' already exists, skipping."
else
    sudo adduser "$CLAUDE_USER"
fi

echo "[Phase 1] Locking down your home directory..."
chmod 700 "/home/$MAIN_USER"

echo "[Phase 1] Verifying claude cannot read your home..."
if sudo -u "$CLAUDE_USER" ls "/home/$MAIN_USER" 2>&1 | grep -q "Permission denied"; then
    echo "  Lockdown confirmed."
else
    echo "  WARNING: claude user may have access to your home directory. Check permissions."
fi

# ── Phase 2: Create inbox ─────────────────────────────────────────────────────

echo ""
echo "[Phase 2] Creating inbox directory..."

sudo mkdir -p "/home/$CLAUDE_USER/inbox"
sudo chown "$MAIN_USER:$CLAUDE_USER" "/home/$CLAUDE_USER/inbox"
sudo chmod 750 "/home/$CLAUDE_USER/inbox"

echo "  Inbox created at /home/$CLAUDE_USER/inbox"
echo "  Ownership: $MAIN_USER owns it, $CLAUDE_USER can read it, nobody else can touch it."

# ── Phase 3: Set up project directory ────────────────────────────────────────

echo ""
echo "[Phase 3] Setting up project directory..."

sudo mkdir -p "$PROJECT_DIR/.claude"

# Write Claude Code settings (no sandbox restrictions needed - OS handles that)
sudo tee "$PROJECT_DIR/.claude/settings.json" > /dev/null << 'EOF'
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
EOF

sudo chown -R "$CLAUDE_USER:$CLAUDE_USER" "$PROJECT_DIR"
echo "  Project directory ready at $PROJECT_DIR"

# Write CLAUDE.md standing instructions
sudo tee "$PROJECT_DIR/CLAUDE.md" > /dev/null << EOF
# Standing Instructions

You are running as the claude Linux user on this machine.

## Boundaries
- Your home directory is /home/claude — you have full freedom here
- You cannot access /home/$MAIN_USER — this is enforced at the OS level
- Shared data from the main user arrives in /home/claude/inbox (read only by convention)
- Push outputs to GitHub so the main user can pull them

## Inbox
Files in /home/claude/inbox have been explicitly shared with you by the main user.
You may read them freely. Do not attempt to write back to the main user's home directory.
EOF

sudo chown "$CLAUDE_USER:$CLAUDE_USER" "$PROJECT_DIR/CLAUDE.md"

# ── Phase 4: Write start script ───────────────────────────────────────────────

echo ""
echo "[Phase 4] Writing start script..."

sudo tee "/home/$CLAUDE_USER/start-claude.sh" > /dev/null << EOF
#!/bin/bash
SESSION="claude"
WORKDIR="$PROJECT_DIR"

if tmux has-session -t "\$SESSION" 2>/dev/null; then
    echo "Claude already running. Attach with: tmux attach -t \$SESSION"
    exit 0
fi

tmux new-session -d -s "\$SESSION" -c "\$WORKDIR"
tmux send-keys -t "\$SESSION" "echo y | claude remote-control --name 'Homelab'" Enter
echo "Claude started. Attach with: tmux attach -t \$SESSION"
EOF

sudo chown "$CLAUDE_USER:$CLAUDE_USER" "/home/$CLAUDE_USER/start-claude.sh"
sudo chmod +x "/home/$CLAUDE_USER/start-claude.sh"

# ── Phase 5: Write systemd service ───────────────────────────────────────────

echo ""
echo "[Phase 5] Installing systemd service..."

sudo tee "/etc/systemd/system/$SERVICE_NAME.service" > /dev/null << EOF
[Unit]
Description=Claude Code Remote Control
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$CLAUDE_USER
ExecStart=/home/$CLAUDE_USER/start-claude.sh
ExecStop=/usr/bin/tmux kill-session -t claude

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

echo "  Service installed and enabled."

# ── Phase 6: Install Claude Code ─────────────────────────────────────────────

echo ""
echo "[Phase 6] Installing Claude Code for the claude user..."
echo "  This will switch to the claude user and run the installer."
echo ""

sudo -u "$CLAUDE_USER" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

# ── Phase 7: Manual steps ─────────────────────────────────────────────────────

echo ""
echo "=== Automated setup complete ==="
echo ""
echo "Two manual steps remain:"
echo ""
echo "STEP A — Authenticate Claude Code as the claude user:"
echo "  sudo su - claude"
echo "  cd $PROJECT_DIR"
echo "  claude"
echo "  (Log in with your Anthropic account, then /exit)"
echo ""
echo "STEP B — Accept workspace trust and start remote control:"
echo "  (Still as claude user)"
echo "  claude"
echo "  (Accept the workspace trust prompt, then /exit)"
echo "  exit"
echo ""
echo "STEP C — Start the service:"
echo "  sudo systemctl start $SERVICE_NAME"
echo "  sudo systemctl status $SERVICE_NAME"
echo ""
echo "STEP D — Attach to confirm it's running:"
echo "  sudo -u claude tmux attach -t claude"
echo "  (You should see the remote-control connected screen)"
echo "  (Detach with Ctrl+B then D)"
echo ""
echo "Your Claude Code instance is then accessible from the Claude mobile app"
echo "or https://claude.ai/code"
