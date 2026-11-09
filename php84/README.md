# Lotusboard PHP 8.4 runtime

The production panel uses PHP 8.4.27 on the official `php:8.4-fpm-bookworm`
image, with the existing application, external database, and external Redis.
Laravel remains on 8.83.29; this runtime migration does not restore Laravel 8
security support or resolve the separate dependency security audit.

Build from this directory:

```sh
docker build -t ix-lotusboard:php84-20261109 .
```

The image starts PHP-FPM, Caddy, the existing queue/Horizon programs, and cron.
It expects the existing bind mounts at `/www`, `/wwwlogs`,
`/run/caddy/caddy.conf`, `/run/supervisor/supervisord.conf`, and
`/etc/crontabs/root`. Redis is external; no replacement Redis is started.
FPM keeps the existing root worker identity so this migration does not change
ownership of application storage or uploaded files.

For an isolated canary, set `RUN_WORKERS=false` and `RUN_SCHEDULER=false`, mount
the application read-only, and give it separate writable storage and logs.
The entrypoint handles the legacy crontab's missing final newline for Debian
cron, and installs a PATH containing `/usr/local/bin` so Debian cron can find PHP.
The blue/green scheduler additionally declares its cache environment in its own
crontab and checks actual execution heartbeats. The entrypoint also gives queue processes 120 seconds to stop during future changes.

## Production

The owning Compose project is `/root/docker-compose/docker-compose.yaml`,
service and container `v2board-new`, published port `84:80`. Its image is
`ix-lotusboard:php84-20261109`; do not deploy an obsolete Compose file from the
historical project directories.

The application requires PHP `^8.4` and Composer platform PHP `8.4.0`.
The production lock changed only `nette/schema` (1.2.5 to 1.4.0) and
`nette/utils` (3.2.10 to 4.1.6) to satisfy PHP 8.4 platform requirements.
The verified production `composer.lock` is tracked by the application repository.
Deploy it with `composer install`; an unrestricted Composer update would change
unrelated packages.

PHP engine deprecations are excluded from the pre-bootstrap production error
mask because Laravel 8 declares legacy implicit nullable parameters. Other PHP
errors remain logged. Laravel installs its own deprecation handler after boot;
this setting does not make the framework fully modern or security-supported.

The production server now uses a stable Caddy gateway on port 84, two web slots,
and a separate worker and scheduler for the active slot. The image is reused with
role-specific commands; the default all-in-one command above is retained for
legacy deployments. Explicitly use SIGTERM when stopping scheduler containers:
the upstream PHP image defaults to SIGQUIT.

See the deployed topology and release commands in the parent repository's
[`docs/smooth-deployment.md`](https://github.com/hexonal/lotusboard-docker/blob/main/docs/smooth-deployment.md).

## Rollback

The previous runtime is preserved as image
`ix-lotusboard:php74-rollback-20261109` and stopped container
`ix-php74-rollback-preserved` (restart policy `no`).
The matching vendor tree, Composer files, Compose configuration, and container
inspection are under
`/root/lotusboard-docker-new/runtime/php84/rollback/cutover-20261109/`.

The guarded `rollback/rollback-php74.sh` script refuses to operate directly on
the blue/green gateway. Restore the all-in-one topology and stop blue/green
background roles before using this legacy PHP rollback. For ordinary application
rollback, use the parent repository's `manage.py promote <previous-slot>`.
It stops PHP 8.4 workers before restoring the old vendor and Composer files,
then recreates only the panel's owning Compose service. Do not start the PHP
7.4 container against PHP 8.4's vendor tree.

No database migrations were run. Real purchases, email delivery, and a full
interactive login were not exercised. Verification covers password hashing,
JWT and encryption round trips, login validation, Stripe signature and callback
parsing with synthetic data, email MIME generation without sending, five
subscription formats, and authenticated backend node configuration.
