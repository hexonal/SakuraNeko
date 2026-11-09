#!/bin/sh
# Run on the panel server only when explicitly rolling back this PHP migration.
set -eu

runtime_dir=/root/lotusboard-docker-new/runtime/php84
snapshot_dir=$runtime_dir/rollback/cutover-20261109
app_dir=/root/lotusboard-docker-new/lotusboard
compose_file=/root/docker-compose/docker-compose.yaml

test -d "$snapshot_dir/vendor-php74"
test -f "$snapshot_dir/composer.json"
test -f "$snapshot_dir/composer.lock"
test -f "$snapshot_dir/docker-compose.yaml"
docker image inspect ix-lotusboard:php74-rollback-20261109 >/dev/null
current_image=$(docker inspect v2board-new --format '{{.Config.Image}}')
case "$current_image" in
    ix-lotusboard:php84-*) ;;
    *) echo 'Refusing rollback: the active panel is not this PHP 8.4 deployment.' >&2; exit 1 ;;
esac

docker compose -f "$compose_file" stop -t 120 v2board-new
saved_vendor=$runtime_dir/rollback/vendor-php84-$(date -u +%Y%m%dT%H%M%SZ)
test ! -e "$saved_vendor"
mv "$app_dir/vendor" "$saved_vendor"
cp -a "$snapshot_dir/vendor-php74" "$app_dir/vendor"
cp -p "$snapshot_dir/composer.json" "$app_dir/composer.json"
cp -p "$snapshot_dir/composer.lock" "$app_dir/composer.lock"
cp -p "$snapshot_dir/docker-compose.yaml" "$compose_file"
# Use the preserved local image, without pulling a mutable legacy upstream tag.
sed -i 's#image: ghcr.io/lotusnetwork/sakuraneko#image: ix-lotusboard:php74-rollback-20261109#' "$compose_file"
docker compose -f "$compose_file" up -d --no-deps --force-recreate v2board-new
docker exec v2board-new php -v
docker exec -w /www v2board-new php artisan --version
