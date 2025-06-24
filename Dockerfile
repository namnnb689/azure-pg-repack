FROM debian:bookworm-slim

RUN apt-get update &&     apt-get install -y postgresql-client pg-repack cron &&     rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY maintenance_runner.sh job_handlers.sh ./
COPY .env ./

RUN chmod +x maintenance_runner.sh job_handlers.sh

RUN echo "*/5 * * * * /app/maintenance_runner.sh >> /app/maintenance_runner_cron.log 2>&1" > /etc/cron.d/maintenance_cron
RUN chmod 0644 /etc/cron.d/maintenance_cron
RUN crontab /etc/cron.d/maintenance_cron

CMD ["cron", "-f"]