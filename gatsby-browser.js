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
}

export const onRouteUpdate = () => {
  attachCopyButtons()
}
