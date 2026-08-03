import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'en-US',
  title: 'simshot',
  description: 'App Store screenshot capture CLI — simctl only, no XCUITest, no hangs.',
  base: '/simshot/',
  lastUpdated: true,
  cleanUrls: true,
  head: [
    ['meta', { name: 'theme-color', content: '#dc2626' }],
    ['link', { rel: 'icon', href: '/simshot/favicon.svg', type: 'image/svg+xml' }],
  ],
  themeConfig: {
    logo: '/favicon.svg',
    siteTitle: 'simshot',
    nav: [
      { text: 'Guide', link: '/guide/installation', activeMatch: '/guide/' },
      { text: 'Commands', link: '/guide/commands' },
      { text: 'GitHub', link: 'https://github.com/kichiemon/simshot' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Quick Start', link: '/guide/quickstart' },
            { text: 'Scene Protocol', link: '/guide/scene-protocol' },
            { text: 'Configuration', link: '/guide/configuration' },
            { text: 'Commands', link: '/guide/commands' },
            { text: 'Troubleshooting', link: '/guide/troubleshooting' },
            { text: 'AI Agents', link: '/guide/ai-agents' },
          ],
        },
      ],
    },
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2026 kichiemon',
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/kichiemon/simshot' }],
    editLink: {
      pattern: 'https://github.com/kichiemon/simshot/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },
  },
})
