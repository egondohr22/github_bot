import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 4000 } }

  connect() {
    this.show()
    this.scheduleHide()
  }

  show() {
    this.element.classList.add("translate-x-0", "opacity-100")
    this.element.classList.remove("translate-x-full", "opacity-0")
  }

  hide() {
    this.element.classList.add("translate-x-full", "opacity-0")
    this.element.classList.remove("translate-x-0", "opacity-100")
    setTimeout(() => { if (this.element.parentNode) this.element.remove() }, 300)
  }

  scheduleHide() {
    this.hideTimeout = setTimeout(() => this.hide(), this.timeoutValue)
  }

  dismiss() {
    clearTimeout(this.hideTimeout)
    this.hide()
  }

  pauseHide() {
    clearTimeout(this.hideTimeout)
  }

  resumeHide() {
    this.scheduleHide()
  }
}
