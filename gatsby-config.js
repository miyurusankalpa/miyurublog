module.exports = {
  siteMetadata: {
    title: `Miyuru Tech Blog`,
    author: {
      name: `Miyuru`,
      summary: `DevOps Engineer. #IPv6 advocate.`,
    },
    description: `Miyurus Tech Blog.`,
    siteUrl: `https://blog.miyuru.lk/`,
    social: {
      mastodon: `https://ipv6.social/@miyuru`,
      twitter: `miyurusankalpa`,
      linkedin: `miyurusankalpa`,
    },
  },
  plugins: [
    {
      resolve: `gatsby-source-filesystem`,
      options: {
        path: `${__dirname}/content/blog`,
        name: `blog`,
        fastHash: true,
      },
    },
    {
      resolve: `gatsby-source-filesystem`,
      options: {
        path: `${__dirname}/content/assets`,
        name: `assets`,
        fastHash: true,
      },
    },
    {
      resolve: `gatsby-transformer-remark`,
      options: {
        plugins: [
          {
            resolve: `gatsby-remark-images`,
            options: {
              maxWidth: 630,
            },
          },
          {
            resolve: `gatsby-remark-responsive-iframe`,
            options: {
              wrapperStyle: `margin-bottom: 1.0725rem`,
            },
          },
          {
            resolve: `gatsby-remark-vscode`,
            options: {
              theme: "Abyss", // Or install your favorite theme from GitHub
            },
          },
          `gatsby-remark-prismjs`,
          `gatsby-remark-copy-linked-files`,
          `gatsby-remark-smartypants`,
        ],
      },
    },
    `gatsby-transformer-sharp`,
    `gatsby-plugin-sharp`,
   // `gatsby-plugin-draft`,
    `gatsby-plugin-sitemap`,
    {
      resolve: "gatsby-plugin-matomo",
      options: {
        siteId: "3",
        matomoUrl: "//mat-mo.miyuru.lk",
        siteUrl: "https://blog.miyuru.lk",
        matomoPhpScript: "Jeff.php",
        matomoJsScript: "Jeff.php",
      },
    },
    `gatsby-plugin-feed`,
    {
      resolve: `gatsby-plugin-manifest`,
      options: {
        name: `Miyuru Blog`,
        short_name: `GatsbyJS`,
        start_url: `/`,
        background_color: `#ffffff`,
        theme_color: `#663399`,
        display: `minimal-ui`,
        icon: `content/assets/gatsby-icon.png`,
      },
    },
    `gatsby-plugin-react-helmet`,
    //`gatsby-plugin-netlify-cms`,
    // this (optional) plugin enables Progressive Web App + Offline functionality
    // To learn more, visit: https://gatsby.dev/offline
    // `gatsby-plugin-offline`,
  ],
}
