# HubMail container build

Fork of [grommunio/gromox-container](https://github.com/grommunio/gromox-container).
Builds `ghcr.io/jesseframework/hubmail-core`: grommunio core with the HubMail patches.

## What differs from upstream

- `gromox-core/Dockerfile` overlays our admin-api fork
  ([jesseframework/hubmail-admin-api](https://github.com/jesseframework/hubmail-admin-api),
  build arg `HUBMAIL_ADMIN_API_REF`, default `master`) onto the packaged admin-api.
  That carries the default-license patch: no 5-user Community cap.
- The exact grommunio package versions in each image are written to
  `/etc/hubmail/packages.txt`, and the overlaid admin-api commit to
  `/etc/hubmail/admin-api.commit`. The community repo only serves its latest build,
  so these files are how we know what an image contains.
- OCI labels point at this repo, which keeps the modified source public (AGPL-3.0).
- `.github/workflows/hubmail-core.yml` builds on every push/PR, smoke-tests that the
  cap patch is present, and pushes to GHCR from `master` and `v*` tags.

## Tags

| Tag | Meaning |
|---|---|
| `sha-<commit>` | Immutable; what k3s manifests pin to |
| `master`, `latest` | Moving; newest master build |
| `<version>` | From a `v<version>` git tag |

## Local smoke test

    docker compose -f hubmail/compose.test.yml up -d --build
    # wait for first-boot setup (several minutes), then:
    docker compose -f hubmail/compose.test.yml exec hubmail-core \
      bash -c 'cd /usr/share/grommunio-admin-api && python3 -c "from tools.license import getLicense as g; l=g(); print(l.product, l.users)"'
    # admin UI: https://localhost:9443  (admin / hubmail-test)
    docker compose -f hubmail/compose.test.yml down -v

`hubmail/test.env` holds throwaway test passwords only. Production settings come from
Infisical via ESO on k3s, never from this repo.

## Sync with upstream

    git fetch upstream
    git checkout master && git merge upstream/master && git push origin master

## Not yet done (phase 2)

Splitting the single supervisord container into per-role deployments (MX, front,
store shards) and wiring multiple exmdb home servers. That needs the k3s staging
environment to test failover properly.
