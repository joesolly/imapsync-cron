FROM python:3-alpine

ENV MAX_LOG_SIZE=5000000

COPY imapbackup312.py /usr/local/bin/imapbackup
RUN chmod +x /usr/local/bin/imapbackup

# ---------------------------------------------------------
# Add helper scripts
# ---------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
COPY rotate.sh /usr/local/bin/rotate
COPY run-sync.sh /usr/local/bin/run-sync

RUN chmod +x /entrypoint.sh /usr/local/bin/rotate /usr/local/bin/run-sync

# ---------------------------------------------------------
# Runtime directories
# ---------------------------------------------------------
RUN mkdir -p /etc/crontabs /var/log/cron /data

ENTRYPOINT ["/entrypoint.sh"]
