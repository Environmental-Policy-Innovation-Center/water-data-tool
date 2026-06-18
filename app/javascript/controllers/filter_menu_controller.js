import { Controller } from "@hotwired/stimulus"

// Listens for "filter:close-all" to dismiss menus when other controllers need them closed.
export default class extends Controller {
  #outsideClick = (e) => {
    if (!e.target.closest(".filter-menu-btn") && !e.target.closest(".filter-dropdown")) {
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

    const isOpen = !menu.classList.contains("hidden")
    this.#closeAll()
    if (!isOpen) {
      const mapRect = document.getElementById("container-map").getBoundingClientRect()
      const btnRect = btn.getBoundingClientRect()
      const menuBtns = document.querySelectorAll(".filter-menu-btn")
      const lastMenuBtn = menuBtns.length ? menuBtns[menuBtns.length - 1] : null
      const moreBtnRect = lastMenuBtn ? lastMenuBtn.getBoundingClientRect() : mapRect

      menu.style.left = "0"
      menu.classList.remove("hidden")
      btn.classList.add("active")
      btn.setAttribute("aria-expanded", "true")

      const menuW = menu.offsetWidth
      const rightBoundary = moreBtnRect.right - mapRect.left
      const naturalLeft = btnRect.left - mapRect.left
      const maxLeft = rightBoundary - menuW
      menu.style.left = `${Math.max(0, Math.min(naturalLeft, maxLeft))}px`
    }
  }

  #closeAll() {
    document.querySelectorAll(".filter-dropdown").forEach(m => {
      m.classList.add("hidden")
    })
    document.querySelectorAll(".filter-menu-btn").forEach(b => {
      b.classList.remove("active")
      b.setAttribute("aria-expanded", "false")
    })
  }
}
