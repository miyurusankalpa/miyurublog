/**
 * SEO component that queries for data with
 *  Gatsby's useStaticQuery React hook
 *
 * See: https://www.gatsbyjs.com/docs/use-static-query/
 */

import React from "react"
import PropTypes from "prop-types"
import { Helmet } from "react-helmet"
import { useStaticQuery, graphql } from "gatsby"

const absoluteUrl = (url, siteUrl) => {
  if (!url) return undefined
  if (/^https?:\/\//i.test(url)) return url
  return `${siteUrl}${url.startsWith(`/`) ? `` : `/`}${url}`
}

const twitterHandle = handle => {
  if (!handle) return undefined
  return handle.startsWith(`@`) ? handle : `@${handle}`
}

const SEO = ({
  description,
  lang,
  meta,
  title,
  image,
  pathname,
  type,
  publishedTime,
  modifiedTime,
  schema,
}) => {
  const { site } = useStaticQuery(
    graphql`
      query {
        site {
          siteMetadata {
            title
            description
            siteUrl
            author {
              name
            }
            social {
              twitter
            }
          }
        }
      }
    `
  )

  const metaDescription = description || site.siteMetadata.description
  const defaultTitle = site.siteMetadata?.title
  const siteUrl = site.siteMetadata?.siteUrl || ``
  const isArticle = type === `article`
  const canonical = pathname ? absoluteUrl(pathname, siteUrl) : undefined
  const imageUrl = absoluteUrl(image, siteUrl)
  const siteTwitter = twitterHandle(site.siteMetadata?.social?.twitter)

  return (
    <Helmet
      htmlAttributes={{
        lang,
      }}
      title={title}
      titleTemplate={defaultTitle ? `%s | ${defaultTitle}` : null}
      link={canonical ? [{ rel: `canonical`, href: canonical }] : undefined}
      meta={[
        {
          name: `description`,
          content: metaDescription,
        },
        {
          property: `og:title`,
          content: title,
        },
        {
          property: `og:description`,
          content: metaDescription,
        },
        {
          property: `og:type`,
          content: isArticle ? `article` : `website`,
        },
        {
          property: `og:site_name`,
          content: defaultTitle,
        },
        {
          property: `og:url`,
          content: canonical || siteUrl,
        },
        {
          name: `twitter:card`,
          content: imageUrl ? `summary_large_image` : `summary`,
        },
        {
          name: `twitter:creator`,
          content: siteTwitter,
        },
        {
          name: `twitter:site`,
          content: siteTwitter,
        },
        {
          name: `twitter:title`,
          content: title,
        },
        {
          name: `twitter:description`,
          content: metaDescription,
        },
        imageUrl && {
          property: `og:image`,
          content: imageUrl,
        },
        imageUrl && {
          name: `twitter:image`,
          content: imageUrl,
        },
        isArticle &&
          publishedTime && {
            property: `article:published_time`,
            content: publishedTime,
          },
        isArticle &&
          modifiedTime && {
            property: `article:modified_time`,
            content: modifiedTime,
          },
        isArticle &&
          site.siteMetadata?.author?.name && {
            property: `article:author`,
            content: site.siteMetadata.author.name,
          },
      ]
        .filter(Boolean)
        .concat(meta)}
    >
      {schema && (
        <script type="application/ld+json">{JSON.stringify(schema)}</script>
      )}
    </Helmet>
  )
}

SEO.defaultProps = {
  lang: `en`,
  meta: [],
  description: ``,
  type: `website`,
}

SEO.propTypes = {
  description: PropTypes.string,
  lang: PropTypes.string,
  meta: PropTypes.arrayOf(PropTypes.object),
  title: PropTypes.string.isRequired,
  image: PropTypes.string,
  pathname: PropTypes.string,
  type: PropTypes.oneOf([`website`, `article`]),
  publishedTime: PropTypes.string,
  modifiedTime: PropTypes.string,
  schema: PropTypes.object,
}

export default SEO
