import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "backdrop", "content"]
  static values = {
    closable: { type: Boolean, default: true },
    size: { type: String, default: "medium" }
  }

  connect() {
    this.boundKeydown = this.keydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
    this.previousActiveElement = document.activeElement
    document.body.classList.add("overflow-hidden")
    this.animateIn()

    const firstInput = this.element.querySelector("input, textarea, select")
    if (firstInput) firstInput.focus()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    document.body.classList.remove("overflow-hidden")
    if (this.previousActiveElement) this.previousActiveElement.focus()
  }

  animateIn() {
    this.element.classList.add("opacity-0")
    this.contentTarget.classList.add("scale-95")

    requestAnimationFrame(() => {
      this.element.classList.remove("opacity-0")
      this.element.classList.add("opacity-100")
      this.contentTarget.classList.remove("scale-95")
      this.contentTarget.classList.add("scale-100")
    })
  }

  animateOut(callback) {
    this.element.classList.remove("opacity-100")
    this.element.classList.add("opacity-0")
    this.contentTarget.classList.remove("scale-100")
    this.contentTarget.classList.add("scale-95")

    setTimeout(() => {
      if (callback) callback()
      else this.element.remove()
    }, 200)
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget && this.closableValue) this.close()
  }

  closeClick() {
    if (this.closableValue) this.close()
  }

  keydown(event) {
    if (event.key === "Escape" && this.closableValue) this.close()
  }

  close() {
    this.animateOut()
  }

  submitEnd(event) {
    if (event.detail.success) this.close()
  }
}
