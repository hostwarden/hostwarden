// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// See: https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Hostwarden',
  tagline: 'The warden over the hosts',
  // favicon, the social card and the navbar logo below are vendored
  // copies of hostwarden/brand's own files: a local build needs
  // them present on disk, and fetching them live on every
  // `npm start` would make hostwarden/brand's own outage this
  // site's outage too. The publish workflow in
  // hostwarden.github.io re-fetches current copies from
  // hostwarden/brand on every deploy, so what actually ships never
  // drifts; only a local preview between brand updates can be
  // briefly stale.
  favicon: 'img/favicon-32.png',

  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Served from hostwarden/hostwarden.github.io, which builds this
  // project and deploys it under /docs — see docs/adr and the
  // publish workflow there for why the path isn't the Docusaurus
  // default of /hostwarden/.
  url: 'https://hostwarden.github.io',
  baseUrl: '/docs/',

  organizationName: 'hostwarden',
  projectName: 'hostwarden',

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          // baseUrl is already /docs/, so the docs plugin owns the
          // site's root instead of adding a second /docs/ segment.
          // That also makes docs the homepage of this project —
          // the one-pager in front of it lives in the separate
          // hostwarden.github.io repo, not here.
          routeBasePath: '/',
          sidebarPath: './sidebars.js',
          editUrl: 'https://github.com/hostwarden/hostwarden/tree/main/website/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/social-card.png',
      colorMode: {
        respectPrefersColorScheme: true,
      },
      navbar: {
        // No separate `title`: the lockup below is tower and
        // wordmark together (hostwarden/brand's README calls it
        // that), so a `title` next to it would repeat the name a
        // second time.
        logo: {
          alt: 'Hostwarden',
          src: 'img/hostwarden-lockup.svg',
          srcDark: 'img/hostwarden-lockup-invers.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Docs',
          },
          {
            type: 'docsVersionDropdown',
            position: 'right',
          },
          {
            href: 'https://github.com/hostwarden/hostwarden',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Introduction',
                to: '/',
              },
            ],
          },
          {
            title: 'Project',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/hostwarden/hostwarden',
              },
              {
                label: 'Issues',
                href: 'https://github.com/hostwarden/hostwarden/issues',
              },
            ],
          },
        ],
        // Named the way LICENSE and hostwarden/brand's LICENSE
        // already do: the actual person, not "Hostwarden" as if
        // the project were its own legal entity.
        copyright: `Copyright © ${new Date().getFullYear()} Julian Pawlowski.`,
      },
      prism: {
        theme: prismThemes.oneLight,
        darkTheme: prismThemes.oneDark,
      },
    }),

  themes: [
    [
      '@easyops-cn/docusaurus-search-local',
      /** @type {import('@easyops-cn/docusaurus-search-local').PluginOptions} */
      ({
        hashed: true,
        language: ['en'],
        indexDocs: true,
        indexBlog: false,
        indexPages: false,
        docsRouteBasePath: '/',
      }),
    ],
  ],
};

export default config;
