# gmail-backup

Incrementally backs up Gmail to local `.mbox` files on a schedule. Each IMAP folder becomes a separate file (e.g. `INBOX.mbox`, `Sent Mail.mbox`). Only new messages are downloaded on each run.

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

Your emails will be backed up nightly at 2am to `./backup/you/`.

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

```
backup/
  alice/
    INBOX.mbox
    Sent Mail.mbox
    Archive.mbox
    ...
  bob/
    INBOX.mbox
    ...
```

## Viewing logs

Cron activity streams to stdout and is visible via:

```sh
docker compose logs -f
```

Per-account sync logs are written to `/var/log/cron/<account>.log` inside the container. Mount `./logs:/var/log/cron` (as shown in the quick start) to access them directly on the host:

```
logs/
  you@gmail.com.log
  other@gmail.com.log
```

```sh
tail -f logs/you@gmail.com.log
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CRON_JOBS` | _(required)_ | Crontab entries — one job per line |
| `MAX_LOG_SIZE` | `5000000` | Log file size in bytes before rotation |

Cron schedule format: `minute hour day month weekday` — use [crontab.guru](https://crontab.guru) to build a schedule.

## Using the mbox files

`.mbox` is a standard format supported by most email clients:

- **Apple Mail** — File → Import Mailboxes → Files in mbox format
- **Thunderbird** — ImportExportTools NG extension → Import mbox file
- **mutt** — `mutt -f backup/alice/INBOX.mbox`
