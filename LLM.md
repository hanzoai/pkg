# hanzoai/pkg — pkg.hanzo.ai, the self-hosted npm registry

verdaccio 5.33.0 + verdaccio-aws-s3-storage 10.3.3, the npm twin of
`hanzoai/registry` (oci.hanzo.ai, containers). Same estate pattern:
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

## Branding — both marks are ABSOLUTE PATHS, and neither lives in the theme
`web.logo` / `web.logoDark` / `web.favicon` name files under `/verdaccio/web/`.
Copying an asset into the theme's `static/` dir and naming it by basename looks
right and does nothing, in two different ways:
- **logo**: verdaccio runs `path.posix.resolve(logo)` against the process CWD
  (`/opt/verdaccio`). A basename resolves to a file that is not there, and an
  unreadable logo is dropped to `undefined` — the page renders `logo:""`, no
  mark, and logs nothing. Given a path that exists it reads the file itself and
  republishes it at `/-/static/<basename>`.
- **favicon**: `app.get('/-/static/favicon.ico', serveFavicon(config))` is
  registered on the app ahead of the theme router, so the theme dir is never
  consulted. It streams `web.favicon`, else the stock icon inside verdaccio.

Check branding by reading `window.__VERDACCIO_BASENAME_UI_OPTIONS` on `/` —
`logo` must be a URL, `primaryColor` `#000000` (vendor default is `#4b5e40`).
`/-/static/*` sits behind Cloudflare, so purge that URL after a change or the
edge keeps serving the old icon against a correct origin.

## Deploy
Fleet app `hanzo-pkg`: `universe/charts/app/values/hanzo/pkg.yaml`.
- `.hanzo/workflows/deploy.yml` is the build lane — the forge reads
  `.hanzo/workflows/`, and GitHub Actions is off account-wide, so
  `.github/workflows/` builds nothing. A push to `main` derives the next patch
  from the tags published in GHCR (authenticated: `ghcr.io/hanzoai/pkg` is
  private, and an anonymous read returns an empty list that reads like a fresh
  repository), proves the tag is unused, builds linux/amd64, proves the pushed
  image resolves, then calls `universe/charts/app/pin.sh pkg <version>` so
  cd.hanzo.ai reconciles. Tags carry a leading `v`; pin.sh takes the bare
  version and picks the prefix up from the values file.
- The forge's Actions unit must stay enabled on the repo. With it off a
  workflow file is inert — no run is created and nothing reports a failure.
- env: `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` from the existing
  `s3-credentials` secret; `VERDACCIO_PUBLIC_URL=https://pkg.hanzo.ai`.
- ingress: host `pkg.hanzo.ai` (hanzoai/ingress class, cert-manager
  letsencrypt-prod, existing secret `pkg-hanzo-ai-tls`), path-split:
  `/v1/packages` stays on `hanzo-git` (the forge's 25-ecosystem package
  surface), `/` is the npm protocol -> service `pkg:4873`.

## Publish
`max_users: -1` also closes the interactive `npm login` endpoint (verdaccio
routes login through adduser), so auth is Basic `_auth` in `.npmrc`:
```
registry=https://pkg.hanzo.ai/
//pkg.hanzo.ai/:_auth=<base64 of "hanzo:<KMS hanzo/prod /pkg/publish-password>">
```
Verified end to end: `npm ping` PONG, `npm whoami` -> hanzo,
`@hanzo/smoke@0.0.1` published + installed back, `@hanzo/ui@8.0.33` installed
THROUGH the uplink with its tarball cached into the S3 bucket.
Repo `.npmrc` cutover is a separate decision — nothing points here yet.
