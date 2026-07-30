# hanzoai/pkg — pkg.hanzo.ai, the self-hosted npm registry

verdaccio 5.33.0 + verdaccio-aws-s3-storage 10.3.3, the npm twin of
`hanzoai/registry` (registry.hanzo.ai, containers). Same estate pattern:
stock battle-tested server, config baked into the image, storage on
hanzoai/s3, secrets from KMS.

## Shape
- `Dockerfile` — verdaccio + the S3 store plugin under `/verdaccio/plugins`.
- `conf/config.yaml` — the whole registry policy:
  - store: bucket `pkg` on `http://s3.hanzo.svc:9000` (path-style). Zero PVC.
  - uplink `npmjs` -> registry.npmjs.org, 30m metadata cache; installs of
    anything not published here fall through and the tarball is cached in S3
    (supply-chain buffer).
  - auth: bcrypt htpasswd at `/verdaccio/auth/htpasswd`, `max_users: -1`
    (no self-registration; the file is KMS-synced, KMS path `/pkg`, org
    `hanzo`, env `prod`, keys `htpasswd` + `publish-password`).
  - publish requires auth; reads are open.

## Deploy
Fleet app `hanzo-pkg`: `universe/charts/app/values/hanzo/pkg.yaml`.
- image `ghcr.io/hanzoai/pkg` (built by an in-cluster BuildKit job in
  `hanzo-build`, git context = this repo tag).
- env: `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` from the existing
  `s3-credentials` secret; `VERDACCIO_PUBLIC_URL=https://pkg.hanzo.ai`.
- ingress: host `pkg.hanzo.ai` (hanzoai/ingress class, cert-manager
  letsencrypt-prod, existing secret `pkg-hanzo-ai-tls`), path-split:
  `/v1/packages` stays on `hanzo-git` (the forge's 25-ecosystem package
  surface), `/` is the npm protocol -> service `pkg:4873`.

## Publish
```
npm login --registry https://pkg.hanzo.ai/   # user hanzo, password from KMS /pkg/publish-password
npm publish --registry https://pkg.hanzo.ai/
```
Repo `.npmrc` cutover is a separate decision — nothing points here yet.
