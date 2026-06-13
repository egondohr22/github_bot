import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "label", "input", "search", "option", "chevron"]
  static values = { placeholder: { type: String, default: "Select…" } }

  connect() {
    this.isOpen = false
    this.boundClickOutside = this.clickOutside.bind(this)
    this.menuTarget.classList.add("opacity-0", "scale-95")
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.isOpen = true
    this.menuTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.menuTarget.classList.remove("opacity-0", "scale-95")
      this.menuTarget.classList.add("opacity-100", "scale-100")
      if (this.hasChevronTarget) {
        this.chevronTarget.classList.add("rotate-180")
      }
    })
    if (this.hasSearchTarget) {
      setTimeout(() => this.searchTarget.focus(), 50)
    }
    document.addEventListener("click", this.boundClickOutside)
  }

  close() {
    this.isOpen = false
    this.menuTarget.classList.remove("opacity-100", "scale-100")
    this.menuTarget.classList.add("opacity-0", "scale-95")
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.remove("rotate-180")
    }
    setTimeout(() => this.menuTarget.classList.add("hidden"), 150)
    document.removeEventListener("click", this.boundClickOutside)
  }

  select(event) {
    const option = event.currentTarget
    const value = option.dataset.selectValue
    const label = option.dataset.selectLabel || value

    this.inputTarget.value = value
    this.labelTarget.textContent = label
    this.labelTarget.classList.remove("theme-text-secondary")
    this.labelTarget.classList.add("theme-text-primary")

    // Mark selected option
    this.optionTargets.forEach(o => o.classList.remove("theme-bg-secondary", "font-medium"))
    option.classList.add("theme-bg-secondary", "font-medium")

    this.close()
  }

  filter() {
    const query = this.searchTarget.value.toLowerCase()
    this.optionTargets.forEach(option => {
      const text = option.textContent.toLowerCase()
      option.classList.toggle("hidden", query.length > 0 && !text.includes(query))
    })
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }
}
