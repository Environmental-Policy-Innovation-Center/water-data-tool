import { Controller } from "@hotwired/stimulus"

// Listens for "filter:close-all" to dismiss menus when other controllers need them closed.
export default class extends Controller {
  #outsideClick = (e) => {
    if (!e.target.closest(".filter-menu-btn") && !e.target.closest(".container-menu")) {
      this.#closeAll()
    }
  }

  #onCloseAll = () => this.#closeAll()

  connect() {
    document.addEventListener("click", this.#outsideClick)
    document.addEventListener("filter:close-all", this.#onCloseAll)
  }

  disconnect() {
    document.removeEventListener("click", this.#outsideClick)
    document.removeEventListener("filter:close-all", this.#onCloseAll)
  }

  toggleMenu(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const menuId = btn.dataset.menu
    const menu = document.getElementById(`container-menu-${menuId}`)
    if (!menu) return

    const isOpen = menu.style.display === "block"
    this.#closeAll()
    if (!isOpen) {
      const mapRect = document.getElementById("container-map").getBoundingClientRect()
      const btnRect = btn.getBoundingClientRect()

      // Show first so offsetWidth is accurate, then clamp to avoid right-edge overflow
      menu.style.left = "0"
      menu.style.display = "block"
      btn.classList.add("active")

      const leftPos = btnRect.left - mapRect.left
      const maxLeft = mapRect.width - menu.offsetWidth - 10
      menu.style.left = `${Math.max(0, Math.min(leftPos, maxLeft))}px`
    }
  }

  #closeAll() {
    document.querySelectorAll(".container-menu").forEach(m => { m.style.display = "none" })
    document.querySelectorAll(".filter-menu-btn").forEach(b => b.classList.remove("active"))
  }
}
