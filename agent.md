# Miyurublog Agent Notes

Use this file as fast context for future work in this repository.

## Stack

- Gatsby blog with Markdown posts in `content/blog/**/index.md`
- Global styles in `src/style.css` and resets in `src/normalize.css`
- Blog post template in `src/templates/blog-post.js`

## Key Files

- `gatsby-config.js`: site metadata and plugin config
- `gatsby-node.js`: node/page creation
- `gatsby-browser.js`: browser-only behavior and global imports
- `src/components/*`: shared UI blocks

## Markdown and Code Blocks

- Markdown rendering uses `gatsby-transformer-remark`
- Syntax/highlight plugins include:
  - `gatsby-remark-vscode`
  - `gatsby-remark-prismjs`
- Copy button behavior is implemented in `gatsby-browser.js`
  - Targets `.gatsby-highlight` and `.grvsc-container`
  - Avoids duplicates when another plugin already adds copy buttons
- Copy button styles are in `src/style.css` under `.code-copy-button`

## Working Rules

- Keep edits small and consistent with existing project style
- Prefer ASCII unless a file already uses Unicode
- Use `rg`/`rg --files` for fast code search
- After meaningful changes, run `npm run build`

## Common Tasks

- Update blog UX/layout: start with `src/templates/blog-post.js` and `src/style.css`
- Add browser enhancements: use Gatsby browser APIs in `gatsby-browser.js`
- Update content: edit `content/blog/**/index.md` frontmatter + body

