# Website

This website is built using [Docusaurus](https://docusaurus.io/), a modern static website generator.

## Installation

```bash
npm install
```

**Note**: feel free to use the package manager of your choice.

## Local Development

```bash
npm run start
```

This command starts a local development server and opens up a browser window.
Most changes are reflected live without having to restart the server.

## Build

```bash
npm run build
```

This command generates static content into the `build` directory and can be
served using any static contents hosting service.

## Deployment

Not `npm run deploy` — that would push this build to a `gh-pages`
branch of _this_ repository, which nothing serves. The live site is
built and published by a separate repository,
[hostwarden/hostwarden.github.io](https://github.com/hostwarden/hostwarden.github.io),
whose workflow pulls this project on a dispatch from
`.github/workflows/docs-publish-dispatch.yml` and
`tag-release.yml` (`docs/adr/20260925-docs-stay-in-repo-thin-publish.md`
says why).
