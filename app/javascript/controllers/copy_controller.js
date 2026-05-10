import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "feedback"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value)
    this.feedbackTarget.textContent = "Copied!"
    setTimeout(() => this.feedbackTarget.textContent = "", 2000)
  }
}
