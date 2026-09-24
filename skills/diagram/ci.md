# Keep diagrams fresh in CI

Installs a GitHub Actions workflow that checks every push to the default branch, plus a weekly run, for drift since `diagrams/manifest.json` was stamped. When it finds drift, it runs `/d2:diagram` and opens a pull request with the refreshed diagrams. A push that touches no source costs a checkout and a `git diff`, with no Claude run.

1. `./diagrams/manifest.json` must exist and be committed, because CI refreshes and never builds from scratch. If it's missing, run the build first.
2. Copy `${CLAUDE_PLUGIN_ROOT}/templates/refresh-diagrams.yml` to `.github/workflows/refresh-diagrams.yml`. If the default branch isn't `main`, which `git symbolic-ref --short refs/remotes/origin/HEAD` shows, change the `branches:` entry to match.
3. Tell the user what's left, since it's theirs to do:
   - add a repository secret: `ANTHROPIC_API_KEY`, or `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token` for a subscription (then swap the `anthropic_api_key:` line as its comment says)
   - under Settings, Actions, General, allow GitHub Actions to create pull requests
   - pull requests opened with the default token don't trigger other workflows. If their CI must run on the refresh PR, give `create-pull-request` a PAT or app token

Done when the workflow file exists and the user has the list above. Committing it is the user's call.
