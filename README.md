# ruby-mise

A CI image for Ruby and Rails projects: Debian trixie with
[mise](https://mise.jdx.dev/), plus MySQL and Redis that a job starts when it
needs them.

```
ghcr.io/d34ndev/ruby-mise:latest
```

## What's in it

- **mise**, with Ruby 3.3, 3.4 and 4.0 and Node 24 preinstalled. A project's
  `.mise.toml` picks the versions, so `mise install` is usually a no-op.
- **Wrangler**, Cloudflare's CLI, for deploying Workers and Pages.
- **MySQL 8.4** (real MySQL, not MariaDB) and **Redis**. They're installed but
  not running; start them with `start-mysql` and `start-redis`.
- Build dependencies for common native gems: libssl, libyaml, libvips, ffmpeg,
  libmysqlclient and so on.

## Tags

The [Publish](.github/workflows/publish.yml) workflow builds on every push to
`main` and every Monday, and pushes:

- `latest`
- the build date, such as `2026-10-12`. Use this to pin a version in CI.
- `sha-<short commit>`

Pull requests build the image without publishing it.

CI runners keep the images they've already pulled, so a pipeline using `latest`
may keep running an older copy. Pin a date tag, or set the runner to always pull.

## Using it in Woodpecker

```yaml
steps:
  - name: test
    image: ghcr.io/d34ndev/ruby-mise:2026-10-12
    environment:
      BUNDLE_PATH: /cache/bundle
      MISE_TRUSTED_CONFIG_PATHS: /woodpecker
      MISE_YES: "1"
      RAILS_ENV: test
      DATABASE_URL: mysql2://root@127.0.0.1:3306/app_test
      REDIS_URL: redis://127.0.0.1:6379/0
    commands:
      - mise install
      - bundle install
      - start-mysql
      - start-redis
      - bin/rails db:create test:db
```

MySQL and Redis run inside the step's own container and listen on
`127.0.0.1`. MySQL's `root` user has no password. They start in a second or
two, with no service containers to pull or wait for.

If the package is private, add a `ghcr.io` login in Woodpecker (Admin →
Registries): your GitHub username and a personal access token with
`read:packages`. Or make the package public in its GitHub settings.

## Adding a Ruby version

Add the version to the `mise install ruby@...` line in the `Dockerfile` and
push. mise downloads precompiled Ruby, so builds stay quick. A project that
asks for a version not in the image still works, but it downloads Ruby in
every job.

## Building locally

```sh
docker build -t ruby-mise:test .
```
