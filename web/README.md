# Web content hashing and cache updates

The Vercel build uses Flutter 3.50's `--wasm --web-content-hash` output.
Run `node scripts/optimize-web-build.js` after a local web build as well.
The Flutter SDK path must be resolved from the project's local configuration.

## Cache policy

- Content-addressed `main.dart.<hash>.*` and `assets/**` files use one-year
  immutable HTTP caching and a shared service worker cache.
- HTML, bootstrap scripts, version and deployment manifests always check the
  network. School API requests bypass the worker cache.
- Unhashed icons and fonts revalidate instead of receiving immutable caching.
- The worker keeps the current and previous release's hashed files. It prunes
  older hashes on activation, preserves one previous shell, and never deletes
  caches belonging to another application.
- Missing static resources return 404; only application routes fall back to HTML.
  HTML and unsuccessful responses are never stored as static assets.

## Deployment transition

The postprocessor publishes `web-release-manifest.json` with full SHA-256 hashes
and sizes for the current release. In Vercel production builds it reads that
manifest from `https://$VERCEL_PROJECT_PRODUCTION_URL` (falling back to the
project's existing `hongik-ingan.vercel.app` production domain). It downloads
only previous release files absent from the current build and verifies every
file's size and full hash. A failed download, invalid manifest, or hash mismatch
fails the build, leaving the deployed site unchanged.

The new output includes exactly the current release and its immediate
predecessor. Previous files are excluded from the new release manifest, so they
do not accumulate indefinitely. This protects an old tab's first request for an
asset that was not already cached. Tabs older than one release should reload;
browser storage eviction and offline availability of uncached files are not
guaranteed.

On the first rollout, a missing manifest (404, or the old SPA's HTML fallback)
is accepted and unhashed asset aliases are included for pre-hash tabs. Older
unhashed compiled entrypoints cannot be reconstructed from that manifest;
existing tabs may need to reload during the first transition. Subsequent
production builds preserve the previous hashed release automatically. Preview
and local builds do not download production artifacts. Production build workers
must be able to read the public production manifest and its static files.

## Verification and rollback

Run `npm run test:pwa` and `npm run test:server`. The build tests cover two-release
retention, removal of older releases, corruption, missing manifests, unsafe paths,
and offline/cache behavior. Verify the generated HTML/worker logo URLs, Wasm and
JS fallback entrypoints, cache headers, and real static 404s in a browser.

For release verification, stage a production build, test it, then promote that
same build. A preview skips the production artifact-retention fetch and is not
enough to verify that step. Roll back to a previously tested deployment when
needed; keep HTML and bootstrap revalidation enabled. No global cache purge is
required for ordinary updates.

See [Flutter web deployment](https://docs.flutter.dev/deployment/web#web-content-hashing-web-content-hash).
