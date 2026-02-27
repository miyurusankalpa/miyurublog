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

const BlogPostTemplate = ({ data, location }) => {
  const post = data.markdownRemark
  const siteTitle = data.site.siteMetadata?.title || `Title`
  const { previous, next } = data
  const { headings, htmlWithAnchors } = buildPostContent(post.html)

  return (
    <Layout location={location} title={siteTitle}>
      <SEO
        title={post.frontmatter.title}
        description={post.frontmatter.description || post.excerpt}
      />
      <article
        className="blog-post"
        itemScope
        itemType="http://schema.org/Article"
      >
        <header>
          <h1 itemProp="headline">{post.frontmatter.title}</h1>
          <p>{post.frontmatter.date}</p>
        </header>
        {headings.length > 0 && (
          <aside className="blog-post-toc">
            <h2>On this page</h2>
            <nav>
              <ul>
                {headings.map(heading => (
                  <li key={heading.id} className={`toc-level-${heading.level}`}>
                    <a href={`#${heading.id}`}>{heading.title}</a>
                  </li>
                ))}
              </ul>
            </nav>
          </aside>
        )}
        <section
          dangerouslySetInnerHTML={{ __html: htmlWithAnchors }}
          itemProp="articleBody"
        />
        <hr />
        <footer>
          <Bio />
        </footer>
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
      }
    }
    markdownRemark(id: { eq: $id }) {
      id
      excerpt(pruneLength: 160)
      html
      frontmatter {
        title
        date(formatString: "MMMM DD, YYYY")
        description
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
