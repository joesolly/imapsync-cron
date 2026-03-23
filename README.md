# gmail-backup

Incrementally syncs Gmail to local [Maildir](https://en.wikipedia.org/wiki/Maildir) on a schedule using [mbsync](https://isync.sourceforge.io). Each email is stored as an individual file, so backups only transfer new and deleted messages — not the entire mailbox.

Gmail is treated as the source of truth — deletions and new mail sync down to local, but no local changes are ever pushed back to Gmail.

## Prerequisites

**Gmail App Password** — standard passwords won't work. You need to:
1. Enable [2-Step Verification](https://myaccount.google.com/security) on your Google account
2. Generate an [App Password](https://myaccount.google.com/apppasswords) (select "Mail" and your device)
3. Use that 16-character password below instead of your real Gmail password

## Quick start

Create a `docker-compose.yml`:

```yaml
services:
  gmail-backup:
    image: joesolly/imapsync-cron:latest
    volumes:
      - ./backup:/data
      - ./logs:/var/log/cron
    environment:
      CRON_JOBS: |
        0 2 * * * run-sync you@gmail.com your-app-password you
    restart: unless-stopped
```

Then run:

```sh
docker compose up -d
```

Your emails will be synced nightly at 2am to `./backup/you/`.

The `run-sync` command takes three required arguments and one optional:

| Argument | Description |
|---|---|
| `ACCOUNT` | Full Gmail address (`user@gmail.com`) |
| `PASSWORD` | Gmail App Password |
| `TARGET` | Subdirectory name under `/data` where mail is stored |
| `EXCLUDE` _(optional)_ | Comma-separated folder labels to skip, e.g. `"Clubs,Forums"` |

## Multiple accounts

Add one line per account, staggered so they don't overlap:

```yaml
services:
  gmail-backup:
    image: joesolly/imapsync-cron:latest
    volumes:
      - ./backup:/data
      - ./logs:/var/log/cron
    environment:
      CRON_JOBS: |
        0 2 * * * run-sync alice@gmail.com alice-app-password alice
        0 4 * * * run-sync bob@gmail.com bob-app-password bob
    restart: unless-stopped
```

## Backup output

Each folder is a Maildir directory. Every email is a separate file — only new and deleted messages are touched on each sync.

```
backup/
  alice/
    INBOX/
    [Gmail]/
      Sent Mail/
      Drafts/
      Starred/
      ...
    My Label/
    ...
  bob/
    INBOX/
    ...
```

Note: `[Gmail]/All Mail` contains a copy of every email across all folders. Use the `EXCLUDE` argument if you want to skip it to save storage.

## Viewing logs

Cron activity streams to stdout and is visible via:

```sh
docker compose logs -f
```

Per-account sync logs are written to `/var/log/cron/<account>.log`. Mount `./logs:/var/log/cron` (as shown in the quick start) to access them directly on the host:

```sh
tail -f logs/you@gmail.com.log
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CRON_JOBS` | _(required)_ | Crontab entries — one job per line |
| `MAX_LOG_SIZE` | `5000000` | Log file size in bytes before rotation |

Cron schedule format: `minute hour day month weekday` — use [crontab.guru](https://crontab.guru) to build a schedule.

## Using the backup

Maildir is supported natively by most email clients:

- **Thunderbird** — add a Local Folder pointing at the account directory
- **mutt / neomutt** — `set mbox_type=Maildir` and point at the folder
- **Apple Mail** — does not support Maildir directly; run a local [Dovecot](https://www.dovecot.org) instance to serve the Maildir over IMAP, then add it as a normal account
