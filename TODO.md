# Remaining Setup

These items were discussed and designed but not yet implemented.

## 1. Obsidian sync script

A script that runs on your main user account and copies tagged Obsidian files into the claude user's inbox.

**Design:**
- Scans your Obsidian vault for files tagged `#claude`
- Copies them to `/home/claude/inbox/`
- Run manually or on a schedule via cron

**Protocol:**
- manny-linux-user runs the script (with sudo to write into the inbox)
- claude-linux-user reads from inbox
- One-way: Claude never writes back to your home directory
- For sensitive data only — use GitHub for Claude's outputs back to you

## 2. GitHub PAT for claude user

So Claude can push work outputs to GitHub, and you can pull them from your main account.

**Design:**
- Create a scoped Personal Access Token on your GitHub account
- Limit it to specific repos only
- Store it in `/home/claude/.config/gh/` or as a git credential
- Claude pushes outputs → you pull on your main user

**Why GitHub and not direct file transfer:**
- Clean audit trail (every change is versioned)
- Works from your phone (you can review PRs remotely)
- No sudo needed for the "outputs back to you" direction
- Natural fit for code, notes, and documents

## 3. CLAUDE.md review

The current `CLAUDE.md` in `/home/claude/ClaudePersistentRemoteSession/` has generic instructions. Update it with:
- Specific projects or tasks you want Claude to know about
- Any conventions or preferences
- What repos it has access to push to
