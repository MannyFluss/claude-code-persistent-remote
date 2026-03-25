# Claude Code Persistent Remote

Run a persistent, remote-controlled Claude Code instance on your home server or VPS. Control it from your phone or any device using the Claude mobile app.

## What this sets up

```
your-linux-user (/home/you)        claude-linux-user (/home/claude)
├── private data (locked down)     ├── Claude Code running in tmux
├── Obsidian vault                 ├── persistent, remote-controlled
└── drops files → inbox/ ─────────►└── inbox/ (reads shared files)
                                        └── pushes outputs to GitHub
```

- A dedicated `claude` Linux user — isolated at the OS level, not just application level
- Claude Code running persistently in a tmux session
- Remote-control enabled so you can dispatch tasks from the Claude mobile app or browser
- A one-way inbox so you can share specific files with Claude without exposing your whole home directory
- A systemd service so it starts automatically on boot

## Why a separate Linux user instead of Claude Code's built-in sandbox

Claude Code has a sandbox feature, but running your setup *inside* the sandbox limits what Claude can do to help you set things up. More importantly, Linux user isolation is enforced by the OS kernel — no matter what Claude does, it physically cannot read files it doesn't have permission to read. It's a harder boundary.

The tradeoff: you give Claude freedom within its own home directory, and the OS enforces the wall between it and your private data.

## Prerequisites

- Debian or Ubuntu (tested on Debian 12)
- A user account with `sudo` access
- `tmux` installed (`sudo apt install tmux`)
- An Anthropic account with a Claude subscription

## Quick start

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-persistent-remote
cd claude-code-persistent-remote
chmod +x setup.sh
./setup.sh
```

Then follow the manual steps printed at the end.

## What the script does

### Phase 1 — Create the claude Linux user

Creates a new user called `claude` with its own home directory at `/home/claude`. This user has no `sudo` access — it can only affect its own home directory.

The script also sets your home directory to `chmod 700`, which means only you can read it. The claude user will get `Permission denied` if it ever tries to access `/home/you`.

> **Note on Linux permissions:** `chmod 700` means owner=rwx, group=none, others=none. The three digits map to owner / group / everyone else. `7` = read+write+execute, `0` = no access.

### Phase 2 — Create the inbox

Creates `/home/claude/inbox/` with these ownership settings:

```
drwxr-x---  your-user  claude  inbox/
```

- You (owner) can read, write, and enter it
- The claude user (group) can read and enter, but NOT write
- Everyone else has no access

This is the one-way data channel. You drop files in, Claude reads them, it can never write back upstream.

> **What "execute" means on a directory:** It means the ability to `cd` into it or traverse it — not to run programs. So `r-x` on a directory means "can list and enter, but not create or delete files."

### Phase 3 — Project directory and settings

Sets up `/home/claude/ClaudePersistentRemoteSession/` with:

- A `CLAUDE.md` file containing standing instructions (what Claude should know about its environment)
- A minimal `.claude/settings.json` — no filesystem restrictions needed since the OS handles that

### Phase 4 — Start script

Writes `/home/claude/start-claude.sh`. This script:

1. Checks if a tmux session named `claude` is already running (singleton check)
2. If not, creates a new tmux session and starts Claude Code in remote-control mode
3. If already running, exits cleanly with a message

The singleton check means you can run this script as many times as you want — it won't spawn duplicate instances.

### Phase 5 — Systemd service

Installs and enables a systemd service (`claude-remote.service`) that calls the start script on boot.

```
sudo systemctl start claude-remote    # start
sudo systemctl stop claude-remote     # stop (kills the tmux session)
sudo systemctl status claude-remote   # check if running
sudo systemctl restart claude-remote  # restart
```

The service uses `Type=oneshot` with `RemainAfterExit=yes`. This means the service "runs" the script (which starts tmux and exits), and systemd considers the service active as long as the tmux session is alive. This is the right pattern for services that launch a background process and exit.

> **Why not `Type=simple`?** Simple expects the ExecStart process to keep running. Our script starts tmux and exits — that would look like a crash to systemd. `oneshot` is for "do a thing and exit, I'll track state separately."

### Phase 6 — Install Claude Code

Runs the official installer as the claude user. Uses the native installer (not npm — the npm package is deprecated).

## Manual steps after running the script

The script cannot automate these because they require interactive input:

**1. Authenticate** — Claude Code needs to be linked to your Anthropic account:
```bash
sudo su - claude
claude
# Log in when prompted, then /exit
```

**2. Accept workspace trust** — Claude Code asks once whether you trust the project directory:
```bash
# Still as claude user, same directory
claude
# Accept the trust prompt, then /exit
exit
```

**3. Start the service:**
```bash
sudo systemctl start claude-remote
sudo systemctl status claude-remote
```

**4. Verify it's running:**
```bash
sudo -u claude tmux attach -t claude
# You should see the remote-control connected screen
# Detach with Ctrl+B then D
```

## Connecting from your phone

Once the service is running, open the Claude app on your phone and look for the remote sessions option. You can also go to https://claude.ai/code in a browser.

The session name is `Homelab` by default. You can change this in `/home/claude/start-claude.sh`.

## The inbox: sharing files with Claude

To share files from your private data with Claude, drop them into the inbox:

```bash
cp /path/to/file /home/claude/inbox/
```

Claude can read anything in `/home/claude/inbox/`. It cannot write back to your home directory.

> **Planned extension:** An Obsidian sync script that scans your vault for files tagged `#claude` and automatically copies them to the inbox. See [TODO.md](TODO.md).

## Troubleshooting

**`sudo: claude: command not found` when trying to run claude as the claude user**

The claude binary is installed in `/home/claude/.local/bin/` which isn't in root's PATH. Use:
```bash
sudo -u claude /home/claude/.local/bin/claude
```
Or switch fully to the claude user first: `sudo su - claude`

**`sh: Syntax error: "(" unexpected`**

The install script requires bash, not sh. On Debian, `sh` is `dash` which doesn't support all bash syntax. Always use:
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Service fails with exit code 203**

The ExecStart binary can't be found or isn't executable. Check:
```bash
sudo -u claude /home/claude/start-claude.sh
```

**`Workspace not trusted` error**

You need to run `claude` interactively in the project directory at least once to accept the trust dialog before remote-control will work. See manual step 2 above.

**`sudo cat > /etc/...` doesn't work**

`sudo` applies to `cat`, not to the shell redirection `>`. The redirect still runs as your user, which can't write to `/etc/`. Use `sudo tee` instead, or write to `/tmp/` first and then `sudo mv`.

## Remaining setup (see TODO.md)

- Obsidian sync script (tag `#claude` → auto-copy to inbox)
- GitHub PAT for claude user (push outputs back to you)
- Update CLAUDE.md with project-specific instructions
