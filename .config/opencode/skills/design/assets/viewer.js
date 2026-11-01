// Viewer runtime for /design output. Config comes from window.DESIGN:
// { app: "Name", mode: "design" | "options", themes: ["light","dark"], viewports: ["phone","desktop"] }
(function () {
  const cfg = Object.assign({ app: "Design", mode: "design", themes: ["light"], viewports: ["phone"] }, window.DESIGN || {});
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const el = (tag, attrs = {}, html = "") => { const e = document.createElement(tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (html) e.innerHTML = html; return e; };
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const tokensById = {};
  $$('script[type="application/json"]').forEach((s) => { try { tokensById[s.id] = JSON.parse(s.textContent); } catch (e) {} });
  const tokensFor = (node) => tokensById[(node.closest("[data-tokens]") || {}).dataset?.tokens || "tokens"] || Object.values(tokensById)[0];

  const state = { theme: null, viewport: cfg.viewports[0] };

  function parseHash() {
    const [path, query] = location.hash.replace(/^#\/?/, "").split("?");
    const params = new URLSearchParams(query || "");
    const [page, screen, st] = (path || "").split("/");
    return { page, screen, state: st, params };
  }
  function writeHash(page, screen, st) {
    const q = new URLSearchParams();
    if (state.theme) q.set("theme", state.theme);
    if (cfg.viewports.length > 1) q.set("viewport", state.viewport);
    const path = [page, screen, st].filter(Boolean).join("/");
    history.replaceState(null, "", "#" + path + (q.toString() ? "?" + q : ""));
  }

  function setTheme(t) {
    state.theme = t;
    if (t) document.documentElement.dataset.theme = t;
    $$(".v-theme button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.value === t)));
  }
  function setViewport(v) {
    state.viewport = v;
    $$(".v-screen .v-frame").forEach((f) => (f.dataset.viewport = v));
    $$("[data-only]").forEach((n) => (n.hidden = !n.dataset.only.split(/\s+/).includes(v)));
    $$(".v-viewport button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.value === v)));
    fitFrames();
  }
  function seg(cls, label, values, onPick) {
    const g = el("div", { class: "v-seg " + cls, role: "group", "aria-label": label });
    values.forEach((v) => {
      const b = el("button", { type: "button", "data-value": v }, esc(v[0].toUpperCase() + v.slice(1)));
      b.addEventListener("click", () => { onPick(v); const r = parseHash(); writeHash(r.page, r.screen, r.state); });
      g.append(b);
    });
    return g;
  }

  function buildToolbar(host) {
    const bar = el("header", { class: "v-toolbar" });
    bar.append(el("span", { class: "v-title" }, esc(cfg.app)));
    if (cfg.themes.length > 1) bar.append(seg("v-theme", "Theme", cfg.themes, setTheme));
    if (cfg.mode === "design" && cfg.viewports.length > 1) bar.append(seg("v-viewport", "Viewport", cfg.viewports, setViewport));
    host.prepend(bar);
  }

  function buildNav() {
    const nav = $(".v-nav");
    if (!nav) return;
    nav.innerHTML = `<h1>${esc(cfg.app)}</h1>`;
    let group = null;
    $$(".v-page").forEach((p) => {
      const g = p.dataset.group || "";
      if (g !== group) { group = g; if (g) nav.append(el("div", { class: "v-group" }, esc(g))); }
      nav.append(el("a", { href: "#" + p.dataset.page, "data-page": p.dataset.page }, esc(p.dataset.title || p.dataset.page)));
    });
  }

  function showPage(id) {
    const pages = $$(".v-page");
    const target = pages.find((p) => p.dataset.page === id) || pages[0];
    if (!target) return null;
    pages.forEach((p) => (p.hidden = p !== target));
    $$(".v-nav a").forEach((a) => (a.dataset.page === target.dataset.page ? a.setAttribute("aria-current", "page") : a.removeAttribute("aria-current")));
    return target;
  }

  function showState(screen, name) {
    const states = $$(":scope > .v-stage > .v-frame > .v-state", screen);
    const target = states.find((s) => s.dataset.state === name) || states[0];
    states.forEach((s) => (s.hidden = s !== target));
    $$(":scope > .v-tabs button", screen).forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.state === target.dataset.state)));
    const note = $(":scope > .v-state-note", screen);
    const t = target.dataset;
    note.innerHTML = `<strong>${esc(t.label || t.state)}</strong>${t.trigger ? " · <em>Trigger:</em> " + esc(t.trigger) : ""}${t.note ? "<br>" + esc(t.note) : ""}`;
    $$("[data-overlay]", target).forEach((o) => { if (!o.hasAttribute("data-static")) o.hidden = true; });
    target.closest(".v-frame").scrollTop = 0;
    return target.dataset.state;
  }

  function buildScreens() {
    $$(".v-screen").forEach((screen) => {
      const states = $$(":scope > .v-state", screen);
      const head = el("h2", {}, esc(screen.dataset.title || screen.dataset.screen));
      const purpose = el("p", { class: "v-purpose" }, esc(screen.dataset.purpose || ""));
      const tabs = el("div", { class: "v-tabs", role: "group", "aria-label": "States" });
      const stage = el("div", { class: "v-stage" });
      const frame = el("div", { class: "v-frame", "data-viewport": state.viewport });
      const note = el("div", { class: "v-state-note", "aria-live": "polite" });
      states.forEach((s) => {
        frame.append(s);
        const b = el("button", { type: "button", "data-state": s.dataset.state }, esc(s.dataset.label || s.dataset.state));
        b.addEventListener("click", () => { const st = showState(screen, s.dataset.state); writeHash(screen.closest(".v-page").dataset.page, screen.dataset.screen, st); });
        tabs.append(b);
      });
      stage.append(frame);
      screen.prepend(head, purpose, tabs, stage, note);
      showState(screen, states[0] && states[0].dataset.state);
    });
  }

  function go(page, screen, st) {
    const p = showPage(page);
    if (!p) return;
    let target = null;
    if (screen) {
      target = $$(".v-screen", p).find((s) => s.dataset.screen === screen);
      if (target) { showState(target, st); target.scrollIntoView({ block: "start" }); }
    } else window.scrollTo(0, 0);
    writeHash(p.dataset.page, screen, st);
  }

  // Prototype interactions: data-goto, data-state-to, data-open, data-close, data-snackbar
  function wireFlows() {
    document.addEventListener("click", (e) => {
      const t = e.target.closest("[data-goto],[data-state-to],[data-open],[data-close],[data-snackbar]");
      if (!t) return;
      const frame = t.closest(".v-frame") || document;
      if (t.dataset.goto) { e.preventDefault(); const [p, s, st] = t.dataset.goto.split("/"); go(p, s, st); return; }
      if (t.dataset.stateTo) { e.preventDefault(); const screen = t.closest(".v-screen"); const st = showState(screen, t.dataset.stateTo); writeHash(screen.closest(".v-page").dataset.page, screen.dataset.screen, st); return; }
      if (t.dataset.open) { e.preventDefault(); const o = $(t.dataset.open, frame); if (o) { o.hidden = false; const f = o.querySelector("[autofocus],button,input,a"); if (f) f.focus(); } return; }
      if (t.dataset.close !== undefined) { e.preventDefault(); const o = t.closest("[data-overlay]"); if (o) o.hidden = true; return; }
      if (t.dataset.snackbar) {
        e.preventDefault();
        const s = $(t.dataset.snackbar, frame);
        if (!s) return;
        s.hidden = false;
        clearTimeout(s._timer);
        s._timer = setTimeout(() => (s.hidden = true), Number(s.dataset.duration || 5000));
      }
    });
    document.addEventListener("keydown", (e) => {
      if (e.key !== "Escape") return;
      $$("[data-overlay]:not([hidden]):not([data-static])").filter((o) => o.dataset.dismissible !== "false").forEach((o) => (o.hidden = true));
    });
  }

  // Foundation renderers: <div data-render="primitives|roles|contrast|type|space|radius|elevation|icons">
  const R = {
    primitives(t) {
      return Object.entries(t.primitives).map(([name, ramp]) =>
        `<div class="v-ramp"><span>${esc(name)}</span>${Object.entries(ramp).map(([k, v]) =>
          `<div class="v-sw" style="background:${v};color:${lum(v) > 0.4 ? "#000" : "#fff"}">${esc(k)}<br>${esc(v)}</div>`).join("")}</div>`).join("");
    },
    roles(t) {
      return t.themes.map((theme) => {
        const res = t.resolved[theme], refs = t.roles[theme];
        const cards = Object.keys(res).filter((r) => !r.startsWith("on-")).map((r) => {
          const on = res["on-" + r] ? "on-" + r : null;
          const fg = on ? res[on] : (lum(res[r]) > 0.4 ? "#000" : "#fff");
          return `<div class="v-role"><div style="background:${res[r]};color:${fg}">${on ? "Aa " : ""}${esc(r)}</div>
            <div>${esc(r)} ${esc(res[r])} <span style="opacity:.7">${esc(refs[r])}</span>${on ? `<br>${esc(on)} ${esc(res[on])} <span style="opacity:.7">${esc(refs[on])}</span>` : ""}</div></div>`;
        }).join("");
        return `<h3>${esc(theme)}</h3><div class="v-roles">${cards}</div>`;
      }).join("");
    },
    contrast(t) {
      const rows = t.contrast.map((c) => `<tr><td>${esc(c.theme)}</td><td><span class="v-sample" style="background:${c.bgHex};color:${c.fgHex};${c.use === "ui" ? `box-shadow:inset 0 0 0 2px ${c.fgHex};color:${c.fgHex}` : ""}">${c.use === "ui" ? "▢ UI" : "Aa"}</span></td>
        <td>${esc(c.fg)}</td><td>${esc(c.bg)}</td><td>${esc(c.use)}</td><td><strong>${c.ratio}:1</strong></td><td>${c.required}:1</td>
        <td><span class="v-badge ${c.pass ? "pass" : "fail"}">${c.pass ? "AA pass" : "Fail"}</span></td></tr>`).join("");
      return `<div class="v-stage"><table class="v-table"><thead><tr><th>Theme</th><th>Sample</th><th>Foreground</th><th>Background</th><th>Use</th><th>Ratio</th><th>Needs</th><th></th></tr></thead><tbody>${rows}</tbody></table></div>`;
    },
    type(t, node) {
      const sample = node.dataset.sample || "The quick brown fox jumps over the lazy dog 0123456789";
      return Object.entries(t.type).map(([name, s]) => `<div class="v-type-row"><div class="v-label">${esc(name)}<br>${s.size}/${s.line} · ${s.weight || 400} · ${esc((t.font[s.font || "body"] || {}).family || "")}${s.tracking ? " · " + s.tracking + "px" : ""}</div>
        <div class="t-${esc(name)}">${esc(s.sample || sample)}</div></div>`).join("");
    },
    space(t) {
      return Object.entries(t.space).map(([k, v]) => `<div class="v-type-row"><div class="v-label">space-${esc(k)} · ${v}px</div><div><div class="v-bar" style="width:${v}px"></div></div></div>`).join("");
    },
    radius(t) {
      return `<div class="v-specimen">${Object.entries(t.radius).map(([k, v]) => `<figure><div class="v-box" style="border-radius:var(--radius-${esc(k)})"></div><figcaption>radius-${esc(k)} · ${v}px</figcaption></figure>`).join("")}</div>`;
    },
    elevation(t) {
      const levels = Object.keys(t.elevation[t.themes[0]] || {});
      return `<div class="v-specimen">${levels.map((k) => `<figure><div class="v-elev" style="box-shadow:var(--elevation-${esc(k)})">Level ${esc(k)}</div><figcaption>elevation-${esc(k)}</figcaption></figure>`).join("")}</div>`;
    },
    icons(t, node) {
      const names = (node.dataset.names || "").split(",").map((s) => s.trim()).filter(Boolean);
      return `<p class="v-label">${esc(t.icons.set || "")} ${esc(t.icons.version || "")}${t.icons.stroke ? " · stroke " + t.icons.stroke : ""}</p><div class="v-icons">${names.map((n) => `<div><i data-icon="${esc(n)}"></i>${esc(n)}</div>`).join("")}</div>`;
    },
  };
  function lum(hex) {
    const h = hex.replace("#", "").slice(0, 6);
    const c = [0, 2, 4].map((i) => { const v = parseInt(h.slice(i, i + 2), 16) / 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }
  function renderFoundations() {
    $$("[data-render]").forEach((n) => { const t = tokensFor(n); const fn = R[n.dataset.render]; if (t && fn) n.innerHTML = fn(t, n); });
  }

  function renderIcons() {
    $$("i[data-icon]").forEach((i) => {
      const set = (tokensFor(i).icons || {}).set || "lucide";
      if (set === "lucide") { i.setAttribute("data-lucide", i.dataset.icon); return; }
      const span = el("span", { class: set + " " + (i.className || ""), "aria-hidden": "true" }, esc(i.dataset.icon));
      i.replaceWith(span);
    });
    if (window.lucide) window.lucide.createIcons({ attrs: { "aria-hidden": "true" } });
  }

  function fitFrames() {
    $$(".v-stage").forEach((stage) => {
      const f = $(":scope > .v-frame", stage);
      if (!f) return;
      f.style.zoom = "";
      const avail = stage.clientWidth;
      if (avail && f.offsetWidth > avail) f.style.zoom = String(Math.max(0.4, avail / f.offsetWidth));
    });
  }

  function init() {
    const route = parseHash();
    const host = $(".v-main") || $(".v-options") || document.body;
    buildToolbar(host);
    buildNav();
    renderFoundations();
    buildScreens();
    renderIcons();
    wireFlows();
    const preset = route.params.get("theme") || document.documentElement.dataset.theme || null;
    if (cfg.themes.length > 1) setTheme(preset && cfg.themes.includes(preset) ? preset : (matchMedia("(prefers-color-scheme: dark)").matches && cfg.themes.includes("dark") ? "dark" : cfg.themes[0]));
    else setTheme(cfg.themes[0]);
    const vp = route.params.get("viewport");
    setViewport(vp && cfg.viewports.includes(vp) ? vp : cfg.viewports[0]);
    if (cfg.mode === "design") go(route.page, route.screen, route.state);
    fitFrames();
    addEventListener("resize", fitFrames);
    addEventListener("hashchange", () => { const r = parseHash(); if (r.params.get("theme")) setTheme(r.params.get("theme")); go(r.page, r.screen, r.state); });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
