# Landing page and its deployment

`site/` holds the public landing page and the privacy policy, published to GitHub
Pages by `.github/workflows/pages.yml`. The internal documentation under `docs/`
stays off the web.

## Where the page gets its values

`site/site.js` reads `site/config.json` and fills every `data-cfg`, `data-cfg-href`
and `data-cfg-mailto` slot. That file is git-ignored: the markup carries fallback
values, so a checkout without it still renders, with placeholder identity.

The deploy writes the file from the `SITE_CONFIG_JSON` repository secret, then runs
`tool/site_config.sh`, which overwrites `version` with the one in `pubspec.yaml`. The
version has a single source of truth: it is never typed in the secret or in the
markup, so a release bump cannot leave it behind.

## Setting the secret

Repository → **Settings** → **Secrets and variables** → **Actions** → **New
repository secret**, named `SITE_CONFIG_JSON`, holding the JSON object that
`site/config.json.dist` describes. The values stay on GitHub and never appear in the
logs. Without the secret the deploy falls back to the template, and the published
page shows its placeholders rather than failing.

## When it deploys

On every push to `main`, and on demand through `workflow_dispatch`. There is
deliberately no `paths` filter: the page carries the `pubspec.yaml` version and the
values written into `site/config.json`, so a release bump must not be able to leave
the deployed site showing the previous one. Adding a value to the page is then one
less thing to remember.

The job skips forks and runs only in the canonical repository.

## Local preview

```
make config    # writes site/config.json from the template and pubspec.yaml
make preview   # serves site/ on http://127.0.0.1:8777/
```

`config.json` is git-ignored. To preview real values, write it by hand from
`site/config.json.dist`: `make config` keeps an existing file and only refreshes its
version.
