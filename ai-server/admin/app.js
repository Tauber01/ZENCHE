/* ZENCHE 后台监控 · 静态前端 SPA（零依赖 vanilla）
 * 契约：PLANS/ZENCHE_ADMIN_MONITOR_PLAN.md「前端契约」+「后端契约」10 条路由。
 * 登录 token 存 sessionStorage；所有 fetch 带 Bearer；401 自动回登录页。
 * API 路径一律相对 /v1/admin/...（同域部署）。 */
(function () {
  "use strict";

  var TOKEN_KEY = "zenche_admin_token";
  var PAGE_SIZE = 50;

  var app = document.getElementById("app");
  var toastEl = document.getElementById("toast");
  var toastTimer = null;

  var state = {
    token: sessionStorage.getItem(TOKEN_KEY) || "",
    view: "overview",
    stats: null,
    history: [],
    devices: [],
    total: 0,
    cursor: null,
    pages: [],
    pageIndex: 0,
    startCursor: null,
    query: "",
    filter: "all",
    currentDevice: null,
    siteDays: 7,
    site: null,
    siteError: null,
    accounts: [],
    acctTotal: 0,
    acctCursor: null,
    acctPages: [],
    acctPageIndex: 0,
    acctStartCursor: null,
    acctQuery: ""
  };

  /* ── 工具 ──────────────────────────────────────── */
  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    if (attrs) {
      for (var k in attrs) {
        if (k === "class") node.className = attrs[k];
        else if (k === "text") node.textContent = attrs[k];
        else if (k === "html") node.innerHTML = attrs[k];
        else if (k.startsWith("on")) node.addEventListener(k.slice(2), attrs[k]);
        else node.setAttribute(k, attrs[k]);
      }
    }
    (children || []).forEach(function (c) {
      if (typeof c === "string") node.appendChild(document.createTextNode(c));
      else if (c) node.appendChild(c);
    });
    return node;
  }

  function toast(msg, ok) {
    toastEl.textContent = msg;
    toastEl.className = "toast show " + (ok ? "ok" : "err");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toastEl.className = "toast"; }, 3200);
  }

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function fmtTs(ts) {
    if (!ts) return "—";
    var d = new Date(Number(ts));
    if (isNaN(d.getTime())) return String(ts);
    var p = function (n) { return (n < 10 ? "0" : "") + n; };
    return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) +
      " " + p(d.getHours()) + ":" + p(d.getMinutes());
  }

  function fmtExpiry(exp) {
    if (!exp) return "—";
    return String(exp).replace(/^(\d{4})(\d{2})(\d{2})$/, "$1-$2-$3");
  }

  function copyText(text) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).catch(function () {});
      return true;
    }
    return ok;
  }

  /* ── API ───────────────────────────────────────── */
  function api(path, opts) {
    opts = opts || {};
    var headers = opts.headers || {};
    headers["Accept"] = "application/json";
    if (state.token) headers["Authorization"] = "Bearer " + state.token;
    var init = { method: opts.method || "GET", headers: headers, credentials: "same-origin" };
    if (opts.body !== undefined) {
      headers["Content-Type"] = "application/json";
      init.body = JSON.stringify(opts.body);
    }
    return fetch("/v1/admin" + path, init).then(function (res) {
      if (res.status === 401) {
        logout(true);
        throw new Error("未授权，请重新登录");
      }
      return res.json().then(function (data) {
        return { status: res.status, ok: res.ok, data: data };
      }).catch(function () {
        return { status: res.status, ok: res.ok, data: null };
      });
    });
  }

  function errMsg(result) {
    if (result && result.data && typeof result.data === "object" && result.data.error) {
      return String(result.data.error);
    }
    if (result && result.data && typeof result.data === "object" && result.data.message) {
      return String(result.data.message);
    }
    return "请求失败（HTTP " + (result ? result.status : "?") + "）";
  }

  /* ── 视图切换 ──────────────────────────────────── */
  function setView(v) {
    state.view = v;
    try { location.hash = v === "overview" ? "" : "#/" + v; } catch (e) {}
    render();
    if (v === "overview") loadOverview();
    else if (v === "devices") { state.pages = []; state.pageIndex = 0; state.cursor = null; loadDevices(); }
    else if (v === "accounts") { state.acctPages = []; state.acctPageIndex = 0; state.acctCursor = null; loadAccounts(); }
    else if (v === "site") loadSite();
  }

  function viewFromHash() {
    var h = (location.hash || "").replace(/^#\//, "").replace(/^#/, "");
    return (h === "devices" || h === "issue" || h === "site" || h === "accounts") ? h : "overview";
  }

  function logout(expired) {
    state.token = "";
    sessionStorage.removeItem(TOKEN_KEY);
    render();
    if (expired) toast("登录已过期，请重新输入管理员令牌", false);
  }

  /* ── 总览 ──────────────────────────────────────── */
  function loadOverview() {
    Promise.all([
      api("/stats"),
      api("/stats/history?days=30")
    ]).then(function (results) {
      var stats = results[0];
      var hist = results[1];
      if (!stats.ok || !stats.data) { toast("加载总览失败：" + errMsg(stats), false); return; }
      state.stats = stats.data;
      state.history = (hist.ok && hist.data && Array.isArray(hist.data)) ? hist.data : [];
      renderOverview();
    }).catch(function (e) { if (state.token) toast(e.message, false); });
  }

  function renderOverview() {
    var s = state.stats;
    var cards = [
      { label: "总用户", value: s.totalAccounts, sub: "含未验证与已禁用账号", cls: "accent" },
      { label: "24h 活跃", value: s.active24h, sub: "最近 24 小时", cls: "live" },
      { label: "7d 活跃", value: s.active7d, sub: "最近 7 天", cls: "live" },
      { label: "7d 内到期", value: s.expiring7d, sub: "到期 ≤ 7 天", cls: "warning" },
      { label: "已用尽", value: s.exhausted, sub: "剩余次数为 0", cls: "live" },
      { label: "已吊销", value: s.revoked, sub: "吊销状态", cls: "warning" }
    ];
    var grid = el("div", { class: "cards-grid" });
    cards.forEach(function (c) {
      grid.appendChild(el("div", { class: "stat-card " + c.cls }, [
        el("div", { class: "label", text: c.label }),
        el("div", { class: "value", text: String(c.value == null ? 0 : c.value) }),
        el("div", { class: "sub", text: c.sub })
      ]));
    });

    var dist = s.remainingDistribution || {};
    var distRows = [
      { key: "zero", label: "0（已用尽）", cls: "zero" },
      { key: "low1to10", label: "1–10", cls: "low" },
      { key: "mid11to50", label: "11–50", cls: "mid" },
      { key: "high51to99", label: "51–99", cls: "high" },
      { key: "full100", label: "100（满）", cls: "full" }
    ];
    var distCard = el("div", { class: "card" }, [el("h2", {}, ["剩余次数分布", el("span", { class: "tag", text: "per 激活设备" })])]);
    var maxDist = 1;
    distRows.forEach(function (r) { maxDist = Math.max(maxDist, Number(dist[r.key]) || 0); });
    distRows.forEach(function (r) {
      var n = Number(dist[r.key]) || 0;
      var pct = (n / maxDist) * 100;
      distCard.appendChild(el("div", { class: "dist-row" }, [
        el("div", { class: "dist-label" }, [document.createTextNode(r.label)]),
        el("div", { class: "dist-track" }, [
          el("div", { class: "dist-fill " + r.cls, style: "width:" + pct + "%" })
        ]),
        el("div", { class: "dist-num", text: String(n) })
      ]));
    });

    var trendCard = el("div", { class: "card" }, [
      el("h2", {}, ["30 天活跃趋势", el("span", { class: "tag", text: "每日快照" })]),
      state.history.length ? renderTrend(state.history) : el("div", { class: "empty", text: "暂无趋势数据" })
    ]);

    var root = el("div", {}, [
      el("div", { class: "page-head" }, [
        el("h1", { text: "总览" }),
        el("div", { class: "desc", text: "注册用户与激活设备状态概览" })
      ]),
      grid,
      el("div", {}, [distCard]),
      trendCard
    ]);
    mount(root);
  }

  function renderTrend(history) {
    var svgNS = "http://www.w3.org/2000/svg";
    var W = 960, H = 240, padL = 44, padR = 12, padT = 14, padB = 26;
    var innerW = W - padL - padR, innerH = H - padT - padB;
    var svg = document.createElementNS(svgNS, "svg");
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);
    svg.setAttribute("preserveAspectRatio", "none");
    svg.id = "trend-chart";

    var dates = history.map(function (h) { return h.date; });
    var series = [
      { key: "active24h", color: "oklch(62% 0.2 25)" },
      { key: "active7d", color: "oklch(62% 0.18 256)" },
      { key: "totalDevices", color: "oklch(78% 0.14 88)" }
    ];
    var maxV = 1;
    history.forEach(function (h) {
      series.forEach(function (s) { maxV = Math.max(maxV, Number(h[s.key]) || 0); });
    });
    maxV = Math.ceil((maxV * 1.15) / 10) * 10;

    // 网格 + Y 轴
    for (var g = 0; g <= 4; g++) {
      var gy = padT + innerH - (innerH * g / 4);
      var line = document.createElementNS(svgNS, "line");
      line.setAttribute("x1", padL); line.setAttribute("y1", gy);
      line.setAttribute("x2", W - padR); line.setAttribute("y2", gy);
      line.setAttribute("stroke", "oklch(36% 0.016 258)");
      line.setAttribute("stroke-width", "1");
      line.setAttribute("stroke-dasharray", "3 4");
      svg.appendChild(line);
      var label = document.createElementNS(svgNS, "text");
      label.setAttribute("x", padL - 8); label.setAttribute("y", gy + 4);
      label.setAttribute("text-anchor", "end");
      label.setAttribute("font-size", "10");
      label.setAttribute("fill", "oklch(70% 0.012 252)");
      label.textContent = String(Math.round(maxV * g / 4));
      svg.appendChild(label);
    }

    // X 轴日期（约 6 个刻度）
    var n = dates.length;
    var tickEvery = Math.max(1, Math.ceil(n / 6));
    for (var i = 0; i < n; i += tickEvery) {
      var lx = padL + (n === 1 ? innerW / 2 : (innerW * i / (n - 1)));
      var dl = document.createElementNS(svgNS, "text");
      dl.setAttribute("x", lx); dl.setAttribute("y", H - 8);
      dl.setAttribute("text-anchor", "middle");
      dl.setAttribute("font-size", "10");
      dl.setAttribute("fill", "oklch(70% 0.012 252)");
      var d = String(dates[i]);
      dl.textContent = d.length === 8 ? d.slice(2) : d;
      svg.appendChild(dl);
    }

    function xAt(idx) { return padL + (n === 1 ? innerW / 2 : (innerW * idx / (n - 1))); }
    function yAt(v) { return padT + innerH - (Number(v) / maxV) * innerH; }

    // 系列折线 + 面积
    series.forEach(function (s) {
      var path = "";
      var area = "";
      history.forEach(function (h, idx) {
        var px = xAt(idx), py = yAt(h[s.key] || 0);
        path += (idx === 0 ? "M" : "L") + px.toFixed(1) + " " + py.toFixed(1);
        area += (idx === 0 ? "M" : "L") + px.toFixed(1) + " " + py.toFixed(1);
      });
      if (n > 0) {
        area += " L" + xAt(n - 1).toFixed(1) + " " + (padT + innerH) +
                " L" + xAt(0).toFixed(1) + " " + (padT + innerH) + " Z";
        var areaEl = document.createElementNS(svgNS, "path");
        areaEl.setAttribute("d", area);
        areaEl.setAttribute("fill", s.color);
        areaEl.setAttribute("opacity", "0.10");
        svg.appendChild(areaEl);
      }
      var lineEl = document.createElementNS(svgNS, "path");
      lineEl.setAttribute("d", path);
      lineEl.setAttribute("fill", "none");
      lineEl.setAttribute("stroke", s.color);
      lineEl.setAttribute("stroke-width", "2");
      lineEl.setAttribute("stroke-linejoin", "round");
      lineEl.setAttribute("stroke-linecap", "round");
      svg.appendChild(lineEl);
    });

    var wrap = el("div", {}, [svg]);
    var legend = el("div", { class: "trend-legend" });
    series.forEach(function (s) {
      legend.appendChild(el("span", {}, [
        el("span", { class: "sw", style: "background:" + s.color }),
        document.createTextNode(s.key)
      ]));
    });
    wrap.appendChild(legend);
    return wrap;
  }

  /* ── 账号列表 ──────────────────────────────────── */
  function loadDevices() {
    state.startCursor = state.cursor;
    var params = new URLSearchParams();
    params.set("limit", String(PAGE_SIZE));
    params.set("filter", state.filter);
    if (state.query) params.set("query", state.query);
    if (state.cursor) params.set("cursor", state.cursor);
    var p = document.getElementById("devices-body");
    if (p) p.parentElement.parentElement.querySelector(".loading") ||
      (function () {
        var box = document.getElementById("devices-card");
        if (box) box.insertBefore(el("div", { class: "loading", text: "加载中…" }), box.firstChild.nextSibling);
      })();
    api("/devices?" + params.toString()).then(function (result) {
      var box = document.getElementById("devices-card");
      if (box) { var l = box.querySelector(".loading"); if (l) l.remove(); }
      if (!result.ok || !result.data) { toast("加载账号列表失败：" + errMsg(result), false); return; }
      state.devices = result.data.items || [];
      state.total = result.data.total || 0;
      state.cursor = result.data.next_cursor || null;
      // 记录本页起点（供上一页返回）
      if (state.pages.length === state.pageIndex) state.pages.push(state.startCursor);
      else state.pages[state.pageIndex] = state.startCursor;
      renderDevices();
    }).catch(function (e) { if (state.token) toast(e.message, false); });
  }

  function statusPill(st) {
    var map = { active: ["active", "正常"], expired: ["expired", "已到期"], exhausted: ["exhausted", "已用尽"], revoked: ["revoked", "已吊销"] };
    var m = map[st] || ["active", st];
    return el("span", { class: "pill " + m[0], text: m[1] });
  }

  function renderDevices() {
    var box = document.getElementById("devices-card");
    if (!box) return;
    var body = document.getElementById("devices-body");
    body.innerHTML = "";
    if (!state.devices.length) {
      body.appendChild(el("tr", {}, [el("td", { colspan: "8", class: "empty", text: "无匹配记录" })]));
    } else {
      state.devices.forEach(function (d) {
        var tr = el("tr", { onclick: function () { openDetail(d.device_id); } }, [
          el("td", { class: "mono" }, [
            document.createTextNode(shortId(d.device_id)),
            el("div", { class: "sub", text: d.created_at ? "建档 " + fmtTs(d.created_at) : "建档未知" })
          ]),
          el("td", { class: "mono", text: d.activation || "—" }),
          el("td", { class: "mono", text: fmtExpiry(d.expiry) }),
          el("td", { class: "mono", text: String(d.used == null ? 0 : d.used) + " / " + String((d.remaining == null ? 0 : d.remaining) + (d.used == null ? 0 : d.used)) }),
          el("td", { class: "mono", text: String(d.remaining == null ? 0 : d.remaining) }),
          el("td", { class: "mono", text: fmtTs(d.last_seen) }),
          el("td", {}, [statusPill(d.status)]),
          el("td", { class: "row-actions", onclick: function (ev) { ev.stopPropagation(); } }, buildRowActions(d))
        ]);
        body.appendChild(tr);
      });
    }
    var info = document.getElementById("pager-info");
    if (info) info.textContent = "共 " + state.total + " 条 · 每页 " + PAGE_SIZE + " · 第 " + (state.pageIndex + 1) + " 页";
    var prev = document.getElementById("pager-prev");
    var next = document.getElementById("pager-next");
    if (prev) prev.disabled = state.pageIndex === 0;
    if (next) next.disabled = !state.cursor;
  }

  function shortId(id) {
    var s = String(id);
    return s.length > 14 ? s.slice(0, 7) + "…" + s.slice(-7) : s;
  }

  function buildRowActions(d) {
    var acts = [];
    acts.push(el("button", { class: "btn small", text: "重置", title: "重置次数归零", onclick: function () { resetUsage(d.device_id); } }));
    acts.push(el("button", { class: "btn small", text: "延期", title: "延期到期日", onclick: function () { promptExtend(d); } }));
    if (d.status === "revoked") {
      acts.push(el("button", { class: "btn small", text: "恢复", title: "解除吊销", onclick: function () { toggleRevoke(d.device_id, false); } }));
    } else {
      acts.push(el("button", { class: "btn small danger", text: "吊销", title: "吊销该设备激活码", onclick: function () { toggleRevoke(d.device_id, true); } }));
    }
    acts.push(el("button", { class: "btn small", text: "备注", title: "编辑管理员备注", onclick: function () { promptNote(d); } }));
    return acts;
  }

  /* ── 行内操作 ──────────────────────────────────── */
  function resetUsage(id) {
    if (!confirm("确认重置设备 " + shortId(id) + " 的用量次数为 0？")) return;
    api("/devices/" + encodeURIComponent(id) + "/reset-usage", { method: "POST", body: {} }).then(function (r) {
      if (r.ok) { toast("已重置用量", true); loadDevices(); }
      else toast("重置失败：" + errMsg(r), false);
    });
  }

  function promptExtend(d) {
    var today = new Date();
    var def = String(d.expiry) || "";
    var input = el("input", { type: "text", value: def, placeholder: "YYYYMMDD", style: "flex:1;padding:9px 11px;background:oklch(13% 0.012 260);border:1px solid var(--rule);border-radius:8px;outline:none;font-family:var(--font-mono)" });
    var mask = el("div", { class: "drawer-mask", onclick: function (ev) { if (ev.target === mask) mask.remove(); } }, [
      el("div", { class: "drawer", style: "width:420px" }, [
        el("h2", { text: "延期到期日" }),
        el("div", { class: "kv-grid", style: "margin-bottom:16px" }, [
          el("div", { class: "k", text: "设备" }),
          el("div", { class: "v", text: d.device_id }),
          el("div", { class: "k", text: "当前到期" }),
          el("div", { class: "v", text: fmtExpiry(d.expiry) })
        ]),
        el("div", { style: "display:flex;gap:10px" }, [
          input,
          el("button", { class: "btn primary", text: "确认延期", onclick: function () {
            var v = input.value.trim();
            if (!/^\d{8}$/.test(v)) { toast("到期日格式应为 YYYYMMDD（8 位数字）", false); return; }
            doExtend(d.device_id, v, mask);
          } })
        ]),
        el("div", { class: "desc", style: "margin-top:10px;font-size:12px;color:var(--muted)", text: "经签发服务签新码，新到期日 " + fmtExpiry(input.value) })
      ])
    ]);
    document.body.appendChild(mask);
  }

  function doExtend(id, expiry, mask) {
    api("/devices/" + encodeURIComponent(id) + "/extend-expiry", { method: "POST", body: { expiry: expiry } }).then(function (r) {
      if (r.ok) {
        mask.remove();
        toast("已延期至 " + fmtExpiry(expiry) + "，新码已生成", true);
        loadDevices();
      } else toast("延期失败：" + errMsg(r), false);
    });
  }

  function toggleRevoke(id, revoke) {
    var verb = revoke ? "吊销" : "恢复";
    if (!confirm("确认" + verb + "设备 " + shortId(id) + "？吊销后 consume/rebind 将拒绝。")) return;
    api("/devices/" + encodeURIComponent(id) + (revoke ? "/revoke" : "/unrevoke"), { method: "POST", body: {} }).then(function (r) {
      if (r.ok) { toast("已" + verb, true); loadDevices(); }
      else toast(verb + "失败：" + errMsg(r), false);
    });
  }

  function promptNote(d) {
    var ta = el("textarea", { placeholder: "管理员备注（≤500 字）", style: "width:100%;min-height:90px;background:oklch(13% 0.012 260);border:1px solid var(--rule);border-radius:8px;padding:10px;outline:none;resize:vertical;font-family:inherit" });
    ta.value = d.note || "";
    var mask = el("div", { class: "drawer-mask", onclick: function (ev) { if (ev.target === mask) mask.remove(); } }, [
      el("div", { class: "drawer", style: "width:460px" }, [
        el("h2", { text: "编辑备注" }),
        el("div", { class: "kv-grid", style: "margin-bottom:14px" }, [
          el("div", { class: "k", text: "设备" }),
          el("div", { class: "v", text: d.device_id })
        ]),
        ta,
        el("div", { style: "display:flex;gap:10px;margin-top:14px;justify-content:flex-end" }, [
          el("button", { class: "btn", text: "取消", onclick: function () { mask.remove(); } }),
          el("button", { class: "btn primary", text: "保存", onclick: function () {
            var v = ta.value.trim();
            if (v.length > 500) { toast("备注不能超过 500 字", false); return; }
            api("/devices/" + encodeURIComponent(d.device_id) + "/note", { method: "POST", body: { note: v } }).then(function (r) {
              if (r.ok) { mask.remove(); toast("备注已保存", true); loadDevices(); }
              else toast("保存失败：" + errMsg(r), false);
            });
          } })
        ])
      ])
    ]);
    document.body.appendChild(mask);
  }

  /* ── 详情（含迁移链） ──────────────────────────── */
  function openDetail(id) {
    api("/devices/" + encodeURIComponent(id)).then(function (r) {
      if (!r.ok) { toast("加载详情失败：" + errMsg(r), false); return; }
      renderDetail(r.data, id);
    });
  }

  function renderDetail(data, id) {
    var d = data;
    var chain = (d.migration_chain && Array.isArray(d.migration_chain)) ? d.migration_chain : [];
    var nodes = chain.length ? chain : [d];
    var migrateBox = el("div", { class: "migrate" }, [
      el("h3", { text: "迁移链（" + nodes.length + " 节点）" })
    ]);
    nodes.forEach(function (n, idx) {
      var current = n.device_id === id;
      migrateBox.appendChild(el("div", { class: "migrate-node" + (current ? " current" : "") }, [
        el("div", { class: "dir", text: idx === 0 ? "源" : (idx === nodes.length - 1 ? "尾" : "中转") }),
        el("div", { class: "dev", text: n.device_id }),
        el("div", { class: "st" }, [statusPill(n.status || "active")]),
        el("div", { class: "st mono", text: n.migrated_at ? fmtTs(n.migrated_at) : "" })
      ]));
    });
    var mask = el("div", { class: "drawer-mask", onclick: function (ev) { if (ev.target === mask) mask.remove(); } }, [
      el("div", { class: "drawer" }, [
        el("button", { class: "btn small close", text: "关闭", onclick: function () { mask.remove(); } }),
        el("h2", { text: "设备详情" }),
        el("div", { class: "kv-grid" }, [
          el("div", { class: "k", text: "设备 ID" }), el("div", { class: "v", text: d.device_id }),
          el("div", { class: "k", text: "激活码" }), el("div", { class: "v", text: d.activation || "—" }),
          el("div", { class: "k", text: "到期日" }), el("div", { class: "v", text: fmtExpiry(d.expiry) }),
          el("div", { class: "k", text: "用量 / 剩余" }), el("div", { class: "v", text: String(d.used || 0) + " / " + String(d.remaining || 0) }),
          el("div", { class: "k", text: "最后活跃" }), el("div", { class: "v", text: fmtTs(d.last_seen) }),
          el("div", { class: "k", text: "状态" }), el("div", { class: "v plain" }, [statusPill(d.status)]),
          el("div", { class: "k", text: "建档时间" }), el("div", { class: "v", text: d.created_at ? fmtTs(d.created_at) : "未知（旧记录）" }),
          el("div", { class: "k", text: "备注" }), el("div", { class: "v plain", text: d.note || "—" })
        ]),
        migrateBox
      ])
    ]);
    document.body.appendChild(mask);
  }

  /* ── 签发 ──────────────────────────────────────── */
  function renderIssue() {
    var deviceInput = el("input", { type: "text", id: "issue-device", placeholder: "设备 ID（deviceId）", autocomplete: "off" });
    var expiryInput = el("input", { type: "text", id: "issue-expiry", placeholder: "YYYYMMDD", value: defaultExpiry(), style: "font-family:var(--font-mono)" });
    var resultBox = el("div", { class: "code-result", id: "issue-result" });
    var copied = el("div", { class: "copied", id: "issue-copied" });

    function doIssue() {
      var device = deviceInput.value.trim();
      var expiry = expiryInput.value.trim();
      if (!device) { toast("请填写设备 ID", false); return; }
      if (!/^\d{8}$/.test(expiry)) { toast("到期日格式应为 YYYYMMDD（8 位数字）", false); return; }
      api("/codes/issue", { method: "POST", body: { device_id: device, expiry: expiry } }).then(function (r) {
        if (r.ok && r.data) {
          resultBox.innerHTML = "";
          resultBox.classList.add("show");
          resultBox.appendChild(el("div", { class: "label", style: "font-size:12px;color:var(--muted)", text: "新激活码" }));
          resultBox.appendChild(el("div", { class: "code", text: r.data.code }));
          resultBox.appendChild(el("div", { class: "meta", text: "设备 " + r.data.device_id + " · 到期 " + fmtExpiry(r.data.expiry) }));
          resultBox.appendChild(el("div", { style: "display:flex;gap:8px;margin-top:12px" }, [
            el("button", { class: "btn primary", text: "复制激活码", onclick: function () {
              var okc = copyText(r.data.code);
              copied.textContent = okc ? "已复制到剪贴板" : "复制失败，请手动选择复制";
            } }),
            el("button", { class: "btn", text: "再签一张", onclick: function () {
              resultBox.classList.remove("show");
              resultBox.innerHTML = "";
              copied.textContent = "";
              deviceInput.value = "";
            } })
          ]));
          resultBox.appendChild(copied);
        } else {
          toast("签发失败：" + errMsg(r), false);
        }
      });
    }

    return el("div", {}, [
      el("div", { class: "page-head" }, [
        el("h1", { text: "签发新码" }),
        el("div", { class: "desc", text: "为新的设备 ID 签发激活码（已存在的设备将返回 409）" })
      ]),
      el("div", { class: "card" }, [
        el("h2", {}, ["新激活码", el("span", { class: "tag", text: "经回环签发服务" })]),
        el("div", { class: "issue-form" }, [
          deviceInput,
          expiryInput,
          el("button", { class: "btn primary", text: "签发", onclick: doIssue })
        ]),
        resultBox
      ])
    ]);
  }

  function defaultExpiry() {
    var d = new Date();
    d.setDate(d.getDate() + 365);
    var p = function (n) { return (n < 10 ? "0" : "") + n; };
    return "" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate());
  }

  /* ── 账号（W13-b）────────────────────────────────
   * 契约：kimi W13-b 派工。GET /v1/admin/accounts?query=&cursor=&limit=
   * 返回 {items:[{email, createdAt, status, verified, deviceCount}],
   * next_cursor, total}；操作 POST /v1/admin/accounts/{email}/
   * disable|enable|force-logout（email 必须 encodeURIComponent）。 */
  function acctErrMsg(result) {
    var msg = "";
    if (result && result.data && typeof result.data === "object" && result.data.error) msg = String(result.data.error);
    else if (result && result.data && typeof result.data === "object" && result.data.message) msg = String(result.data.message);
    else msg = "请求失败";
    return "HTTP " + (result ? result.status : "?") + "：" + msg;
  }

  function acctStatusPill(st) {
    if (st === "disabled") return el("span", { class: "pill disabled", text: "已禁用" });
    return el("span", { class: "pill active", text: "正常" });
  }

  function acctVerifiedPill(v) {
    if (v) return el("span", { class: "pill verified", text: "已验证" });
    return el("span", { class: "pill unverified", text: "未验证" });
  }

  function loadAccounts() {
    state.acctStartCursor = state.acctCursor;
    var params = new URLSearchParams();
    params.set("limit", String(PAGE_SIZE));
    if (state.acctQuery) params.set("query", state.acctQuery);
    if (state.acctCursor) params.set("cursor", state.acctCursor);
    var box = document.getElementById("accounts-card");
    if (box && !box.querySelector(".loading")) {
      box.insertBefore(el("div", { class: "loading", text: "加载中…" }), box.firstChild.nextSibling);
    }
    api("/accounts?" + params.toString()).then(function (result) {
      var b = document.getElementById("accounts-card");
      if (b) { var l = b.querySelector(".loading"); if (l) l.remove(); }
      if (!result.ok || !result.data) { toast("加载账号列表失败：" + acctErrMsg(result), false); return; }
      state.accounts = result.data.items || [];
      state.acctTotal = result.data.total || 0;
      state.acctCursor = result.data.next_cursor || null;
      if (state.acctPages.length === state.acctPageIndex) state.acctPages.push(state.acctStartCursor);
      else state.acctPages[state.acctPageIndex] = state.acctStartCursor;
      renderAccounts();
    }).catch(function (e) { if (state.token) toast(e.message, false); });
  }

  function renderAccounts() {
    var body = document.getElementById("accounts-body");
    if (!body) return;
    body.innerHTML = "";
    if (!state.accounts.length) {
      body.appendChild(el("tr", {}, [el("td", { colspan: "6", class: "empty", text: "无匹配账号" })]));
    } else {
      state.accounts.forEach(function (a) {
        body.appendChild(el("tr", {}, [
          el("td", { class: "mono acct-email", text: a.email }),
          el("td", { class: "mono", text: a.createdAt ? fmtTs(a.createdAt) : "—" }),
          el("td", { class: "mono", text: String(a.deviceCount == null ? 0 : a.deviceCount) }),
          el("td", {}, [acctStatusPill(a.status)]),
          el("td", {}, [acctVerifiedPill(a.verified)]),
          el("td", { class: "row-actions" }, [
            a.status === "disabled"
              ? el("button", { class: "btn small", text: "启用", title: "解除禁用", onclick: function () { acctEnable(a); } })
              : el("button", { class: "btn small danger", text: "禁用", title: "禁用后该账号全部会话即时失效", onclick: function () { acctDisable(a); } }),
            el("button", { class: "btn small warn", text: "强制登出", title: "吊销该账号全部会话", onclick: function () { acctForceLogout(a); } })
          ])
        ]));
      });
    }
    var info = document.getElementById("acct-pager-info");
    if (info) info.textContent = "共 " + state.acctTotal + " 条 · 每页 " + PAGE_SIZE + " · 第 " + (state.acctPageIndex + 1) + " 页";
    var prev = document.getElementById("acct-pager-prev");
    var next = document.getElementById("acct-pager-next");
    if (prev) prev.disabled = state.acctPageIndex === 0;
    if (next) next.disabled = !state.acctCursor;
  }

  function acctDisable(a) {
    if (!confirm("确认禁用账号 " + a.email + "？禁用后该账号全部会话将立即失效，登录将被拒绝。")) return;
    api("/accounts/" + encodeURIComponent(a.email) + "/disable", { method: "POST", body: {} }).then(function (r) {
      if (r.ok) { toast("已禁用 " + a.email, true); loadAccounts(); }
      else toast("禁用失败：" + acctErrMsg(r), false);
    });
  }

  function acctEnable(a) {
    if (!confirm("确认启用账号 " + a.email + "？")) return;
    api("/accounts/" + encodeURIComponent(a.email) + "/enable", { method: "POST", body: {} }).then(function (r) {
      if (r.ok) { toast("已启用 " + a.email, true); loadAccounts(); }
      else toast("启用失败：" + acctErrMsg(r), false);
    });
  }

  function acctForceLogout(a) {
    if (!confirm("确认强制登出账号 " + a.email + "？将吊销其全部会话，该账号所有端立即退出。")) return;
    api("/accounts/" + encodeURIComponent(a.email) + "/force-logout", { method: "POST", body: {} }).then(function (r) {
      if (r.ok) {
        var n = (r.data && r.data.sessions_revoked != null) ? r.data.sessions_revoked : 0;
        toast("已强制登出 " + a.email + "（吊销 " + n + " 个会话）", true);
      } else toast("强制登出失败：" + acctErrMsg(r), false);
    });
  }

  function accountsPage() {
    var search = el("input", { type: "search", id: "account-search", placeholder: "搜索邮箱…", value: state.acctQuery });
    var debounce = null;
    search.addEventListener("input", function () {
      clearTimeout(debounce);
      debounce = setTimeout(function () {
        state.acctQuery = search.value.trim();
        state.acctPages = [];
        state.acctPageIndex = 0;
        state.acctCursor = null;
        loadAccounts();
      }, 300);
    });

    return el("div", {}, [
      el("div", { class: "page-head" }, [
        el("h1", { text: "账号" }),
        el("div", { class: "desc", text: "邮箱注册账号管理：搜索、分页、禁用/启用与强制登出" })
      ]),
      el("div", { class: "card", id: "accounts-card" }, [
        el("div", { class: "toolbar" }, [
          search,
          el("span", { class: "count", id: "acct-pager-info", text: "—" })
        ]),
        el("div", { style: "overflow-x:auto" }, [
          el("table", {}, [
            el("thead", {}, [el("tr", {}, [
              el("th", { text: "邮箱" }), el("th", { text: "注册时间" }), el("th", { text: "设备数" }),
              el("th", { text: "状态" }), el("th", { text: "验证" }), el("th", { text: "操作" })
            ])]),
            el("tbody", { id: "accounts-body" })
          ])
        ]),
        el("div", { class: "pager" }, [
          el("button", { class: "btn", id: "acct-pager-prev", text: "← 上一页", onclick: function () {
            if (state.acctPageIndex === 0) return;
            state.acctPageIndex -= 1;
            state.acctCursor = state.acctPages[state.acctPageIndex];
            loadAccounts();
          } }),
          el("button", { class: "btn", id: "acct-pager-next", text: "下一页 →", onclick: function () {
            if (!state.acctCursor) return;
            state.acctPageIndex += 1;
            state.acctCursor = state.acctCursor; // 本页 next_cursor 即下一页起点
            loadAccounts();
          } })
        ])
      ])
    ]);
  }

  /* ── 官网访问统计 ────────────────────────────────
   * 契约：PLANS/ZENCHE_ADMIN_MONITOR_PLAN.md「二期追加：官网访问统计」。
   * GET /v1/admin/site/stats?days=N；503 站点日志不可读 → 提示条 + 重试。 */
  var SITE_SOURCES = [
    ["direct", "直接访问"], ["baidu", "百度"], ["sogou", "搜狗"], ["so360", "360"],
    ["bing", "必应"], ["google", "谷歌"], ["tencent", "腾讯系"], ["otherExternal", "其他外链"]
  ];

  function fmtIso(iso) {
    if (!iso) return "—";
    var d = new Date(iso);
    if (isNaN(d.getTime())) return String(iso);
    var p = function (n) { return (n < 10 ? "0" : "") + n; };
    return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) +
      " " + p(d.getHours()) + ":" + p(d.getMinutes());
  }

  function setSiteDays(n) {
    if (state.siteDays === n) return;
    state.siteDays = n;
    loadSite();
  }

  function loadSite() {
    api("/site/stats?days=" + state.siteDays).then(function (r) {
      if (r.status === 503 || !r.ok || !r.data) {
        state.site = null;
        state.siteError = { msg: (r.status === 503 ? "站点日志不可读" : "加载官网统计失败：") + (r.status === 503 ? "" : " " + errMsg(r)) };
        renderSite();
        return;
      }
      state.site = r.data;
      state.siteError = null;
      renderSite();
    }).catch(function (e) {
      if (!state.token) return;
      state.site = null;
      state.siteError = { msg: "加载官网统计失败：" + e.message };
      renderSite();
    });
  }

  function siteCard(label, value, sub, cls) {
    return el("div", { class: "stat-card " + cls }, [
      el("div", { class: "label", text: label }),
      el("div", { class: "value", text: String(value == null ? 0 : value) }),
      el("div", { class: "sub", text: sub })
    ]);
  }

  function siteTrendHasData(days) {
    if (!days || !days.length) return false;
    return days.some(function (d) { return Number(d.pv) > 0 || Number(d.uv) > 0; });
  }

  function siteSourcesTotal(sources) {
    var t = 0;
    SITE_SOURCES.forEach(function (p) { t += Number(sources[p[0]]) || 0; });
    return t;
  }

  function renderSiteTrend(days) {
    var svgNS = "http://www.w3.org/2000/svg";
    var W = 960, H = 240, padL = 44, padR = 12, padT = 14, padB = 26;
    var innerW = W - padL - padR, innerH = H - padT - padB;
    var svg = document.createElementNS(svgNS, "svg");
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);
    svg.setAttribute("preserveAspectRatio", "none");
    svg.id = "site-trend-chart";

    var series = [
      { key: "pv", label: "PV", color: "oklch(62% 0.18 256)" },
      { key: "uv", label: "UV", color: "oklch(62% 0.2 25)" }
    ];
    var n = days.length;
    var maxV = 1;
    days.forEach(function (d) {
      series.forEach(function (s) { maxV = Math.max(maxV, Number(d[s.key]) || 0); });
    });
    maxV = Math.ceil((maxV * 1.15) / 10) * 10;

    // 网格 + Y 轴（同总览趋势图做法）
    for (var g = 0; g <= 4; g++) {
      var gy = padT + innerH - (innerH * g / 4);
      var line = document.createElementNS(svgNS, "line");
      line.setAttribute("x1", padL); line.setAttribute("y1", gy);
      line.setAttribute("x2", W - padR); line.setAttribute("y2", gy);
      line.setAttribute("stroke", "oklch(36% 0.016 258)");
      line.setAttribute("stroke-width", "1");
      line.setAttribute("stroke-dasharray", "3 4");
      svg.appendChild(line);
      var label = document.createElementNS(svgNS, "text");
      label.setAttribute("x", padL - 8); label.setAttribute("y", gy + 4);
      label.setAttribute("text-anchor", "end");
      label.setAttribute("font-size", "10");
      label.setAttribute("fill", "oklch(70% 0.012 252)");
      label.textContent = String(Math.round(maxV * g / 4));
      svg.appendChild(label);
    }

    // X 轴日期（约 6 个刻度）
    var tickEvery = Math.max(1, Math.ceil(n / 6));
    for (var i = 0; i < n; i += tickEvery) {
      var lx = padL + (n === 1 ? innerW / 2 : (innerW * i / (n - 1)));
      var dl = document.createElementNS(svgNS, "text");
      dl.setAttribute("x", lx); dl.setAttribute("y", H - 8);
      dl.setAttribute("text-anchor", "middle");
      dl.setAttribute("font-size", "10");
      dl.setAttribute("fill", "oklch(70% 0.012 252)");
      var d = String(days[i].date || "");
      dl.textContent = d.length === 8 ? d.slice(2) : d;
      svg.appendChild(dl);
    }

    function xAt(idx) { return padL + (n === 1 ? innerW / 2 : (innerW * idx / (n - 1))); }
    function yAt(v) { return padT + innerH - (Number(v) / maxV) * innerH; }

    // 系列折线 + 面积
    series.forEach(function (s) {
      var path = "";
      var area = "";
      days.forEach(function (d, idx) {
        var px = xAt(idx), py = yAt(d[s.key] || 0);
        path += (idx === 0 ? "M" : "L") + px.toFixed(1) + " " + py.toFixed(1);
        area += (idx === 0 ? "M" : "L") + px.toFixed(1) + " " + py.toFixed(1);
      });
      if (n > 0) {
        area += " L" + xAt(n - 1).toFixed(1) + " " + (padT + innerH) +
                " L" + xAt(0).toFixed(1) + " " + (padT + innerH) + " Z";
        var areaEl = document.createElementNS(svgNS, "path");
        areaEl.setAttribute("d", area);
        areaEl.setAttribute("fill", s.color);
        areaEl.setAttribute("opacity", "0.10");
        svg.appendChild(areaEl);
      }
      var lineEl = document.createElementNS(svgNS, "path");
      lineEl.setAttribute("d", path);
      lineEl.setAttribute("fill", "none");
      lineEl.setAttribute("stroke", s.color);
      lineEl.setAttribute("stroke-width", "2");
      lineEl.setAttribute("stroke-linejoin", "round");
      lineEl.setAttribute("stroke-linecap", "round");
      svg.appendChild(lineEl);
    });

    var wrap = el("div", {}, [svg]);
    var legend = el("div", { class: "trend-legend" });
    series.forEach(function (s) {
      legend.appendChild(el("span", {}, [
        el("span", { class: "sw", style: "background:" + s.color }),
        document.createTextNode(s.label)
      ]));
    });
    wrap.appendChild(legend);
    return wrap;
  }

  function renderSourceBars(sources) {
    var max = 1;
    SITE_SOURCES.forEach(function (p) { max = Math.max(max, Number(sources[p[0]]) || 0); });
    var wrap = el("div", {});
    SITE_SOURCES.forEach(function (p, i) {
      var n = Number(sources[p[0]]) || 0;
      var pct = (n / max) * 100;
      wrap.appendChild(el("div", { class: "dist-row" }, [
        el("div", { class: "dist-label src-label", text: p[1] }),
        el("div", { class: "dist-track" }, [
          el("div", { class: "dist-fill src-" + i, style: "width:" + pct + "%" })
        ]),
        el("div", { class: "dist-num", text: String(n) })
      ]));
    });
    return wrap;
  }

  function renderTopIps(rows) {
    var list = (rows && Array.isArray(rows)) ? rows : [];
    if (!list.length) return el("div", { class: "empty", text: "暂无访问 IP 数据" });
    var tbody = el("tbody", {});
    list.forEach(function (r, i) {
      tbody.appendChild(el("tr", {}, [
        el("td", { class: "rank", text: String(i + 1) }),
        el("td", { class: "mono", text: r.ip }),
        el("td", { class: "mono", text: String(r.pv) }),
        el("td", { class: "mono", text: fmtIso(r.lastSeen) })
      ]));
    });
    return el("table", { class: "plain-table" }, [
      el("thead", {}, [el("tr", {}, [
        el("th", { text: "#" }), el("th", { text: "IP" }), el("th", { text: "PV" }), el("th", { text: "最后访问" })
      ])]),
      tbody
    ]);
  }

  function renderTopPages(rows) {
    var list = (rows && Array.isArray(rows)) ? rows : [];
    if (!list.length) return el("div", { class: "empty", text: "暂无页面访问数据" });
    var tbody = el("tbody", {});
    list.forEach(function (r, i) {
      tbody.appendChild(el("tr", {}, [
        el("td", { class: "rank", text: String(i + 1) }),
        el("td", { class: "mono path", text: r.path }),
        el("td", { class: "mono", text: String(r.pv) })
      ]));
    });
    return el("table", { class: "plain-table" }, [
      el("thead", {}, [el("tr", {}, [
        el("th", { text: "#" }), el("th", { text: "路径" }), el("th", { text: "PV" })
      ])]),
      tbody
    ]);
  }

  function siteContent() {
    var s = state.site;
    var head = el("div", { class: "page-head" }, [
      el("h1", { text: "官网" }),
      el("div", { class: "desc", text: "zenche.top 访问统计：PV / UV / 下载 / bot 拦截（nginx 访问日志聚合）" })
    ]);
    if (state.siteError || !s) {
      return el("div", {}, [
        head,
        el("div", { class: "notice" }, [
          el("div", { class: "nt-ico", text: "⚠" }),
          el("div", { class: "nt-body" }, [
            el("div", { class: "nt-title", text: state.siteError ? state.siteError.msg : "加载中…" }),
            el("div", { class: "nt-sub", text: "官网访问日志暂不可读，统计无法展示。请检查站点日志路径与权限（ZENCHE_AI_SITE_LOG），确认后重试。" })
          ]),
          el("button", { class: "btn", text: "重试", onclick: function () { loadSite(); } })
        ])
      ]);
    }
    var today = s.today || {};
    var range = s.range || {};
    var cards = el("div", { class: "cards-grid" }, [
      siteCard("今日 PV", today.pv, today.date || "—", "accent"),
      siteCard("今日 UV", today.uv, "独立 IP", "live"),
      siteCard("下载次数", today.downloads, "downloads/*", "success"),
      siteCard("bot 拦截", today.botPv, "spider/bot/crawler", "warning")
    ]);
    var seg = el("div", { class: "seg" }, [
      el("button", { class: "seg-btn" + (state.siteDays === 7 ? " active" : ""), text: "7 天", onclick: function () { setSiteDays(7); } }),
      el("button", { class: "seg-btn" + (state.siteDays === 30 ? " active" : ""), text: "30 天", onclick: function () { setSiteDays(30); } })
    ]);
    var trendCard = el("div", { class: "card" }, [
      el("div", { class: "card-head" }, [
        el("h2", {}, ["访问趋势", el("span", { class: "tag", text: "PV / UV · " + (range.from || "—") + " ~ " + (range.to || "—") })]),
        seg
      ]),
      siteTrendHasData(s.days) ? renderSiteTrend(s.days) : el("div", { class: "empty", text: "所选周期暂无访问数据（日志可能刚开始采集）" })
    ]);
    var cols = el("div", { class: "site-cols" }, [
      el("div", { class: "card" }, [
        el("h2", {}, ["来源分布", el("span", { class: "tag", text: "Referer 分类" })]),
        siteSourcesTotal(s.sources || {}) > 0 ? renderSourceBars(s.sources) : el("div", { class: "empty", text: "暂无来源数据" })
      ]),
      el("div", { class: "card" }, [
        el("h2", {}, ["TOP 页面", el("span", { class: "tag", text: "按 PV" })]),
        renderTopPages(s.topPages)
      ])
    ]);
    var topIpsCard = el("div", { class: "card" }, [
      el("h2", {}, ["TOP IP", el("span", { class: "tag", text: "按 PV · 最后访问本地时区" })]),
      renderTopIps(s.topIps)
    ]);
    var meta = el("div", { class: "site-meta", text: "日志 " + String(s.logBytes || 0) + " 字节 · 生成于 " + fmtIso(s.generated_at) + " · 统计范围 " + (range.from || "—") + " ~ " + (range.to || "—") });
    return el("div", {}, [head, cards, trendCard, cols, topIpsCard, meta]);
  }

  function renderSite() {
    if (state.view !== "site") return;
    var mainEl = document.querySelector(".main");
    if (!mainEl) return;
    mainEl.innerHTML = "";
    mainEl.appendChild(siteContent());
  }

  /* ── 登录视图 ──────────────────────────────────── */
  function renderLogin() {
    var tokenInput = el("input", { type: "password", id: "login-token", placeholder: "管理员令牌", autocomplete: "off" });
    var errBox = el("div", { class: "err", id: "login-err" });
    function doLogin() {
      var v = tokenInput.value.trim();
      if (!v) { errBox.textContent = "请输入管理员令牌"; return; }
      state.token = v;
      sessionStorage.setItem(TOKEN_KEY, v);
      // 试探：拉取 stats 验证令牌有效
      api("/stats").then(function (r) {
        if (r.ok) { render(); loadOverview(); toast("登录成功", true); }
        else {
          state.token = "";
          sessionStorage.removeItem(TOKEN_KEY);
          errBox.textContent = errMsg(r);
        }
      }).catch(function (e) {
        state.token = "";
        sessionStorage.removeItem(TOKEN_KEY);
        errBox.textContent = e.message;
      });
    }
    tokenInput.addEventListener("keydown", function (ev) { if (ev.key === "Enter") doLogin(); });

    return el("div", { class: "login-wrap" }, [
      el("div", { class: "login-card" }, [
        el("div", { class: "mark", text: "Z" }),
        el("h1", { text: "ZENCHE 后台监控" }),
        el("div", { class: "hint", text: "管理员令牌 · Bearer 鉴权" }),
        tokenInput,
        el("button", { class: "btn primary", text: "登录", onclick: doLogin }),
        errBox
      ])
    ]);
  }

  /* ── 主渲染 ────────────────────────────────────── */
  function nav() {
    var items = [
      { key: "overview", label: "总览", icon: "◉" },
      { key: "devices", label: "账号列表", icon: "☰" },
      { key: "issue", label: "签发新码", icon: "＋" },
      { key: "accounts", label: "账号", icon: "@" },
      { key: "site", label: "官网", icon: "◈" }
    ];
    var navEl = el("div", { class: "sidebar" }, [
      el("div", { class: "brand" }, [
        el("div", { class: "mark", text: "Z" }),
        el("div", {}, [
          el("div", { class: "name", text: "ZENCHE" }),
          el("div", { class: "sub", text: "admin console" })
        ])
      ])
    ]);
    items.forEach(function (it) {
      navEl.appendChild(el("button", { class: "nav-item" + (state.view === it.key ? " active" : ""), onclick: function () { setView(it.key); } }, [
        el("span", { class: "ico", text: it.icon }),
        document.createTextNode(it.label)
      ]));
    });
    navEl.appendChild(el("div", { class: "spacer" }));
    navEl.appendChild(el("button", { class: "nav-item logout-btn", onclick: function () { logout(false); } }, [
      el("span", { class: "ico", text: "⏻" }),
      document.createTextNode("退出登录")
    ]));
    return navEl;
  }

  function mount(root) {
    app.innerHTML = "";
    app.appendChild(root);
  }

  function render() {
    if (!state.token) { mount(renderLogin()); return; }
    var content;
    if (state.view === "overview") content = placeholder("overview");
    else if (state.view === "devices") content = devicesPage();
    else if (state.view === "accounts") content = accountsPage();
    else if (state.view === "site") content = placeholder("site");
    else content = renderIssue();
    mount(el("div", { class: "shell" }, [nav(), el("div", { class: "main" }, [content])]));
    if (state.view === "overview" && state.stats) renderOverview();
    if (state.view === "site" && state.site) renderSite();
  }

  function placeholder() {
    return el("div", { class: "loading", text: "加载中…" });
  }

  function devicesPage() {
    var search = el("input", { type: "search", id: "device-search", placeholder: "搜索设备 ID / 激活码…", value: state.query });
    var filterSel = el("select", { id: "device-filter" });
    [
      ["all", "全部"],
      ["active24h", "24h 活跃"],
      ["active7d", "7d 活跃"],
      ["expired", "已到期"],
      ["expiring7d", "7d 内到期"],
      ["exhausted", "已用尽"],
      ["revoked", "已吊销"]
    ].forEach(function (f) {
      var o = el("option", { value: f[0], text: f[1] });
      if (f[0] === state.filter) o.selected = true;
      filterSel.appendChild(o);
    });

    var debounce = null;
    search.addEventListener("input", function () {
      clearTimeout(debounce);
      debounce = setTimeout(function () {
        state.query = search.value.trim();
        state.pages = [];
        state.pageIndex = 0;
        state.cursor = null;
        loadDevices();
      }, 320);
    });
    filterSel.addEventListener("change", function () {
      state.filter = filterSel.value;
      state.pages = [];
      state.pageIndex = 0;
      state.cursor = null;
      loadDevices();
    });

    return el("div", {}, [
      el("div", { class: "page-head" }, [
        el("h1", { text: "账号列表" }),
        el("div", { class: "desc", text: "激活码设备管理：搜索、过滤、分页与行内操作" })
      ]),
      el("div", { class: "card", id: "devices-card" }, [
        el("div", { class: "toolbar" }, [
          search,
          filterSel,
          el("span", { class: "count", id: "pager-info", text: "—" })
        ]),
        el("div", { style: "overflow-x:auto" }, [
          el("table", {}, [
            el("thead", {}, [el("tr", {}, [
              el("th", { text: "设备 ID" }), el("th", { text: "激活码" }), el("th", { text: "到期" }),
              el("th", { text: "用量" }), el("th", { text: "剩余" }), el("th", { text: "最后活跃" }),
              el("th", { text: "状态" }), el("th", { text: "操作" })
            ])]),
            el("tbody", { id: "devices-body" })
          ])
        ]),
        el("div", { class: "pager" }, [
          el("button", { class: "btn", id: "pager-prev", text: "← 上一页", onclick: function () {
            if (state.pageIndex === 0) return;
            state.pageIndex -= 1;
            state.cursor = state.pages[state.pageIndex];
            loadDevices();
          } }),
          el("button", { class: "btn", id: "pager-next", text: "下一页 →", onclick: function () {
            if (!state.cursor) return;
            state.pageIndex += 1;
            state.cursor = state.cursor; // 本页 next_cursor 即下一页起点
            loadDevices();
          } })
        ])
      ])
    ]);
  }

  // 分页：state.pages 存每页起点游标（pageIndex 指向当前页）；下一页用
  // 本页 next_cursor 作起点，上一页取 pages[pageIndex-1]。

  /* ── 启动 ──────────────────────────────────────── */
  state.view = viewFromHash();
  render();
  if (state.token) {
    if (state.view === "devices") loadDevices();
    else if (state.view === "accounts") loadAccounts();
    else if (state.view === "site") loadSite();
    else if (state.view === "issue") { /* 静态表单 */ }
    else loadOverview();
  }
  window.addEventListener("hashchange", function () {
    var v = viewFromHash();
    if (v !== state.view) { state.view = v; render(); if (v === "devices") loadDevices(); else if (v === "overview") loadOverview(); else if (v === "accounts") loadAccounts(); else if (v === "site") loadSite(); }
  });
})();
