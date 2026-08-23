// custom typefaces
import "typeface-montserrat"
import "typeface-merriweather"
// normalize CSS across browsers
import "./src/normalize.css"
// custom CSS styles
import "./src/style.css"

// Highlighting for code blocks
import "prismjs/themes/prism.css"

const COPY_BUTTON_CLASS = "code-copy-button"
const COPY_BUTTON_DEFAULT_TEXT = "Copy"
const COPY_BUTTON_SUCCESS_TEXT = "Copied"
const COPY_BUTTON_ERROR_TEXT = "Copy failed"
const COPY_BUTTON_RESET_MS = 1800

const getCopyText = containerElement => {
  const codeElement =
    containerElement.querySelector("pre code") ||
    containerElement.querySelector("pre") ||
    containerElement.querySelector(".grvsc-code") ||
    containerElement.querySelector("code")
  return (codeElement || containerElement).textContent || ""
}

const setTemporaryButtonText = (buttonElement, text) => {
  buttonElement.textContent = text
  window.setTimeout(() => {
    buttonElement.textContent = COPY_BUTTON_DEFAULT_TEXT
  }, COPY_BUTTON_RESET_MS)
}

const copyText = async text => {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
    return
  }

  const textarea = document.createElement("textarea")
  textarea.value = text
  textarea.setAttribute("readonly", "")
  textarea.style.position = "absolute"
  textarea.style.left = "-9999px"
  document.body.appendChild(textarea)
  textarea.select()
  document.execCommand("copy")
  textarea.remove()
}

const attachCopyButtons = () => {
  const codeContainers = document.querySelectorAll(
    ".gatsby-highlight, .grvsc-container"
  )
  codeContainers.forEach(container => {
    if (container.dataset.copyButtonAttached === "true") {
      return
    }

    // Skip if another plugin already injected a copy button.
    if (
      container.querySelector(`.${COPY_BUTTON_CLASS}`) ||
      container.querySelector("[class*='copy'][class*='button']") ||
      container.querySelector("button[aria-label*='Copy']")
    ) {
      container.dataset.copyButtonAttached = "true"
      return
    }

    const button = document.createElement("button")
    button.type = "button"
    button.className = COPY_BUTTON_CLASS
    button.textContent = COPY_BUTTON_DEFAULT_TEXT
    button.setAttribute("aria-label", "Copy code to clipboard")

    button.addEventListener("click", async () => {
      try {
        await copyText(getCopyText(container))
        setTemporaryButtonText(button, COPY_BUTTON_SUCCESS_TEXT)
      } catch (error) {
        setTemporaryButtonText(button, COPY_BUTTON_ERROR_TEXT)
      }
    })

    container.appendChild(button)
    container.dataset.copyButtonAttached = "true"
  })
}

export const onInitialClientRender = () => {
  attachCopyButtons()
  setupTocScrollSpy()
}

export const onRouteUpdate = () => {
  attachCopyButtons()
  setupTocScrollSpy()
}

let tocSpyObserver = null

const headingIdFromHash = hash => {
  const id = hash.replace(/^#/, "")
  try {
    return decodeURIComponent(id)
  } catch (error) {
    return id
  }
}

const setupTocScrollSpy = () => {
  if (tocSpyObserver) {
    tocSpyObserver.disconnect()
    tocSpyObserver = null
  }

  if (typeof IntersectionObserver === "undefined") {
    return
  }

  const tocLinks = Array.from(
    document.querySelectorAll(".blog-post-toc nav a[href^='#']")
  )
  if (tocLinks.length === 0) {
    return
  }

  const linkByHeadingId = new Map()
  tocLinks.forEach(link => {
    link.classList.remove("toc-active")
    linkByHeadingId.set(headingIdFromHash(link.hash), link)
  })

  const headings = Array.from(linkByHeadingId.keys())
    .map(id => document.getElementById(id))
    .filter(Boolean)

  if (headings.length === 0) {
    return
  }

  let activeLink = null

  const setActiveLink = heading => {
    const nextLink = heading ? linkByHeadingId.get(heading.id) : null
    if (nextLink === activeLink) {
      return
    }
    if (activeLink) {
      activeLink.classList.remove("toc-active")
    }
    activeLink = nextLink
    if (activeLink) {
      activeLink.classList.add("toc-active")
    }
  }

  tocSpyObserver = new IntersectionObserver(
    entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          setActiveLink(entry.target)
        }
      })
    },
    { rootMargin: "0px 0px -75% 0px" }
  )

  headings.forEach(heading => tocSpyObserver.observe(heading))
}
