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
      ACCOUNT_1: "you@gmail.com|your-app-password|you|0 2 * * *"
    restart: unless-stopped
```

Then run:

```sh
docker compose up -d
```

Your emails will be synced nightly at 2am to `./backup/you/`.

## Account format

Each account is configured as a separate `ACCOUNT_*` environment variable in pipe-separated format:

```
email|password|target|schedule[|exclude]
```

| Field | Description |
|---|---|
| `email` | Full Gmail address (`user@gmail.com`) |
| `password` | Gmail App Password |
| `target` | Subdirectory name under `/data` where mail is stored |
| `schedule` | Cron schedule — use [crontab.guru](https://crontab.guru) to build one |
| `exclude` _(optional)_ | Comma-separated folder labels to skip, e.g. `Clubs,Forums` |

Passwords are written to a credentials file at container startup and never passed as command arguments or logged.

## Multiple accounts

Add one `ACCOUNT_*` variable per account, staggered so they don't overlap:

```yaml
services:
  gmail-backup:
    image: joesolly/imapsync-cron:latest
    volumes:
      - ./backup:/data
      - ./logs:/var/log/cron
    environment:
      ACCOUNT_1: "alice@gmail.com|alice-app-password|alice|0 2 * * *"
      ACCOUNT_2: "bob@gmail.com|bob-app-password|bob|0 4 * * *"
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

Note: `[Gmail]/All Mail` contains a copy of every email across all folders. Use the `exclude` field if you want to skip it to save storage.

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
| `ACCOUNT_*` | _(required)_ | One per account, pipe-separated (see above) |
| `PUID` | `0` | User ID to run sync jobs as (recommended: your local UID) |
| `PGID` | `0` | Group ID to run sync jobs as |
| `MAX_LOG_SIZE` | `5000000` | Log file size in bytes before rotation |

Run `id` in your terminal to get your `PUID` and `PGID`.

## Using the backup

Maildir is supported natively by most email clients:

- **Thunderbird** — add a Local Folder pointing at the account directory
- **mutt / neomutt** — `set mbox_type=Maildir` and point at the folder
- **Apple Mail** — does not support Maildir directly; run a local [Dovecot](https://www.dovecot.org) instance to serve the Maildir over IMAP, then add it as a normal account
