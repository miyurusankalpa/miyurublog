import React from "react"
import { Link, graphql } from "gatsby"

import Bio from "../components/bio"
import Layout from "../components/layout"
import SEO from "../components/seo"

const stripHtml = value => value.replace(/<[^>]*>/g, "").trim()

const slugify = value =>
  value
    .toLowerCase()
    .replace(/&[a-z0-9#]+;/g, "")
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")

const buildPostContent = html => {
  const usedIds = new Map()
  const headings = []

  const htmlWithAnchors = html.replace(
    /<h([2-6])([^>]*)>([\s\S]*?)<\/h\1>/g,
    (full, level, attrs, innerHtml) => {
      const title = stripHtml(innerHtml)
      if (!title) {
        return full
      }

      const idMatch = attrs.match(/\sid=["']([^"']+)["']/)
      const baseId = idMatch ? idMatch[1] : slugify(title)
      const count = usedIds.get(baseId) || 0
      const id = count === 0 ? baseId : `${baseId}-${count}`
      usedIds.set(baseId, count + 1)
      headings.push({ id, level: Number(level), title })

      const attrsWithId = idMatch ? attrs : `${attrs} id="${id}"`

      return `<h${level}${attrsWithId}>${innerHtml}<a class="heading-anchor" href="#${id}" aria-label="Anchor link to ${title}">#</a></h${level}>`
    }
  )

  return { headings, htmlWithAnchors }
}

const absoluteUrl = (url, siteUrl) => {
  if (!url) return undefined
  if (/^https?:\/\//i.test(url)) return url
  return `${siteUrl}${url.startsWith(`/`) ? `` : `/`}${url}`
}

const BlogPostTemplate = ({ data, location }) => {
  const post = data.markdownRemark
  const siteTitle = data.site.siteMetadata?.title || `Title`
  const siteUrl = data.site.siteMetadata?.siteUrl || ``
  const authorName = data.site.siteMetadata?.author?.name
  const authorMastodon = data.site.siteMetadata?.social?.mastodon
  const { previous, next } = data
  const { headings, htmlWithAnchors } = buildPostContent(post.html)

  const canonical = `${siteUrl}${post.fields.slug}`
  const ogImage =
    post.frontmatter.image?.childImageSharp?.resize?.src ||
    post.frontmatter.image?.publicURL

  const schema = {
    "@context": `https://schema.org`,
    "@type": `BlogPosting`,
    headline: post.frontmatter.title,
    description: post.frontmatter.description || post.excerpt,
    url: canonical,
    mainEntityOfPage: {
      "@type": `WebPage`,
      "@id": canonical,
    },
    ...(post.frontmatter.publishedIso && {
      datePublished: post.frontmatter.publishedIso,
    }),
    ...((post.frontmatter.updatedIso || post.frontmatter.publishedIso) && {
      dateModified:
        post.frontmatter.updatedIso || post.frontmatter.publishedIso,
    }),
    ...(authorName && {
      author: {
        "@type": `Person`,
        name: authorName,
        ...(authorMastodon && { sameAs: authorMastodon }),
      },
    }),
    ...(ogImage && { image: [absoluteUrl(ogImage, siteUrl)] }),
  }

  return (
    <Layout location={location} title={siteTitle} wide>
      <SEO
        title={post.frontmatter.title}
        description={post.frontmatter.description || post.excerpt}
        image={ogImage}
        pathname={post.fields.slug}
        type="article"
        publishedTime={post.frontmatter.publishedIso}
        modifiedTime={post.frontmatter.updatedIso}
        schema={schema}
      />
      <article
        className="blog-post"
        itemScope
        itemType="http://schema.org/Article"
      >
        <div className="blog-post-layout">
          <header className="blog-post-header">
            <h1 itemProp="headline">{post.frontmatter.title}</h1>
            <p>
              {post.frontmatter.date}
              {post.frontmatter.updated && (
                <>
                  {` `}| Updated {post.frontmatter.updated}
                </>
              )}
            </p>
          </header>
          {headings.length > 0 && (
            <aside className="blog-post-toc">
              <h2>On this page</h2>
              <nav aria-label="On this page">
                <ul>
                  {headings.map(heading => (
                    <li
                      key={heading.id}
                      className={`toc-level-${heading.level}`}
                    >
                      <a href={`#${heading.id}`}>{heading.title}</a>
                    </li>
                  ))}
                </ul>
              </nav>
            </aside>
          )}
          <div className="blog-post-body">
            <section
              dangerouslySetInnerHTML={{ __html: htmlWithAnchors }}
              itemProp="articleBody"
            />
            <hr />
            <footer>
              <Bio />
            </footer>
          </div>
        </div>
      </article>
      <nav className="blog-post-nav">
        <ul
          style={{
            display: `flex`,
            flexWrap: `wrap`,
            justifyContent: `space-between`,
            listStyle: `none`,
            padding: 0,
          }}
        >
          <li>
            {previous && (
              <Link to={previous.fields.slug} rel="prev">
                ← {previous.frontmatter.title}
              </Link>
            )}
          </li>
          <li>
            {next && (
              <Link to={next.fields.slug} rel="next">
                {next.frontmatter.title} →
              </Link>
            )}
          </li>
        </ul>
      </nav>
    </Layout>
  )
}

export default BlogPostTemplate

export const pageQuery = graphql`
  query BlogPostBySlug(
    $id: String!
    $previousPostId: String
    $nextPostId: String
  ) {
    site {
      siteMetadata {
        title
        siteUrl
        author {
          name
        }
        social {
          mastodon
        }
      }
    }
    markdownRemark(id: { eq: $id }) {
      id
      excerpt(pruneLength: 160)
      html
      fields {
        slug
      }
      frontmatter {
        title
        date(formatString: "MMMM DD, YYYY")
        updated(formatString: "MMMM DD, YYYY")
        publishedIso: date
        updatedIso: updated
        description
        image {
          childImageSharp {
            resize(width: 1200, quality: 85) {
              src
            }
          }
          publicURL
        }
      }
    }
    previous: markdownRemark(id: { eq: $previousPostId }) {
      fields {
        slug
      }
      frontmatter {
        title
      }
    }
    next: markdownRemark(id: { eq: $nextPostId }) {
      fields {
        slug
      }
      frontmatter {
        title
      }
    }
  }
`
