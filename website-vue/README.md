# ZENCHE production website

This directory is the versioned source for the Vue website deployed at
`https://zenche.top` on 2026-08-11. It contains the public homepage and the
`/redeem` client. The redemption API remains a separately managed production
service and is not stored here.

Build the site with:

```sh
npm ci
npm run build
```

The generated `dist/` directory is intentionally ignored. A production switch
must use a new immutable staging directory, verify the staged file hashes,
create a root-only backup, atomically replace the live entry point, and then
compare the public HTTPS files with the staged hashes.

The repository's existing `website/` directory is the older static GitHub Pages
site. Its workflow is unchanged in this release; it must not be treated as the
source of the production Vue deployment until a separate migration is reviewed.
