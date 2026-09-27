import React from "react"
import { Link, graphql } from "gatsby"

import Layout from "../components/layout"
import SEO from "../components/seo"

const NotFoundPage = ({ data, location }) => {
  const siteTitle = data.site.siteMetadata.title
  const posts = data.allMarkdownRemark.nodes

  const [picked, setPicked] = React.useState(() => posts.slice(0, 3))

  React.useEffect(() => {
    if (posts.length <= 3) return
    const shuffled = [...posts]
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]]
    }
    setPicked(shuffled.slice(0, 3))
  }, [posts])

  return (
    <Layout location={location} title={siteTitle}>
      <SEO title="404: Not Found" />
      <h1>404: Not Found</h1>
      <p>You just hit a route that doesn&#39;t exist... the sadness.</p>

      {picked.length > 0 && (
        <section className="random-posts" aria-label="Suggested posts">
          <h2 className="random-posts__title">
            While you&#39;re here — three posts at random
          </h2>
          <div className="random-posts__grid">
            {picked.map(post => (
              <Link
                to={post.fields.slug}
                className="random-post-card"
                key={post.fields.slug}
              >
                <time dateTime={post.frontmatter.rawDate}>
                  {post.frontmatter.date}
                </time>
                <h3>{post.frontmatter.title}</h3>
                <p>{post.excerpt}</p>
                <span className="random-post-card__cta">Read →</span>
              </Link>
            ))}
          </div>
        </section>
      )}
    </Layout>
  )
}

export default NotFoundPage

export const pageQuery = graphql`
  query {
    site {
      siteMetadata {
        title
      }
    }
    allMarkdownRemark(
      sort: { fields: [frontmatter___date], order: DESC }
      filter: { frontmatter: { draft: { ne: true } } }
    ) {
      nodes {
        excerpt(pruneLength: 140)
        fields {
          slug
        }
        frontmatter {
          date(formatString: "MMM D, YYYY")
          rawDate: date
          title
        }
      }
    }
  }
`
