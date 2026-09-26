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
    // The infrastructure maps bin/hostwarden-map writes are Mermaid;
    // the Memory section shows real ones.
    mermaid: true,
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
          {type: 'docSidebar', sidebarId: 'start', position: 'left', label: 'Get started'},
          {type: 'docSidebar', sidebarId: 'features', position: 'left', label: 'Features'},
          {type: 'docSidebar', sidebarId: 'memory', position: 'left', label: 'Memory'},
          {type: 'docSidebar', sidebarId: 'safety', position: 'left', label: 'Safety'},
          {type: 'docSidebar', sidebarId: 'running', position: 'left', label: 'Running it'},
          {type: 'docSidebar', sidebarId: 'reference', position: 'left', label: 'Reference'},
          // Working on Hostwarden itself, kept apart from the admin
          // sections on the left.
          {type: 'docSidebar', sidebarId: 'development', position: 'right', label: 'Development'},
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
            title: 'Using Hostwarden',
            items: [
              {label: 'Get started', to: '/'},
              {label: 'Features', to: '/features'},
              {label: 'Memory and maps', to: '/memory'},
              {label: 'Safety', to: '/safety'},
            ],
          },
          {
            title: 'Operating it',
            items: [
              {label: 'Running Hostwarden', to: '/running-it'},
              {label: 'Reference', to: '/reference'},
              {label: 'Working on Hostwarden', to: '/development'},
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
      mermaid: {
        theme: {light: 'neutral', dark: 'dark'},
      },
      prism: {
        theme: prismThemes.oneLight,
        darkTheme: prismThemes.oneDark,
      },
    }),

  themes: [
    '@docusaurus/theme-mermaid',
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
