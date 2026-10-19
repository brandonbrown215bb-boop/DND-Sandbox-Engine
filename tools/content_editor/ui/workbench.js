/* Grimoire Content Workbench — Interactive Visual Builders & Live VS-83 Inspector */

const state = {
  packId: "ember_pack",
  contract: null,
  templates: {},
  metadata: {},
  drafts: [],
  availablePacks: [],
  packManifestPreview: null,
  catalogCounts: {},

  currentType: "spell",
  statusFilter: "",
  searchQuery: "",
  catalogItems: [],

  selectedId: null,
  selectionGeneration: 0,
  loadedSelection: null,
  validationGeneration: 0,
  activeEntryPayload: null,
  workingRecord: null,
  isDirty: false,
  inspectorTab: "diagnostics",
  jsonPreviewMode: "candidate", // "candidate" | "lossless"
  selectedTemplateId: "spell_attack_cantrip",
};

let liveValidateTimer = null;

function esc(val) {
  return String(val ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function showToast(message) {
  const container = document.getElementById("toast-container");
  if (!container) return;
  const el = document.createElement("div");
  el.className = "toast";
  el.innerHTML = `<span style="color: var(--accent-primary);">❖</span> <span>${esc(message)}</span>`;
  container.appendChild(el);
  setTimeout(() => {
    el.style.opacity = "0";
    el.style.transition = "opacity 0.2s ease";
    setTimeout(() => el.remove(), 220);
  }, 2600);
}

function renderStatusBadge(status, label) {
  const cls = "status-" + (status || "staged-reference");
  const shortLabels = {
    "shared-ready": "Shared-Ready",
    "native-id-bound": "Native-ID-Bound",
    "draft-unsupported": "Blocked / Draft",
    "staged-reference": "Reference",
  };
  return `<span class="status-badge ${esc(cls)}" title="${esc(label || status)}">${esc(label || shortLabels[status] || status)}</span>`;
}

function renderShortStatusBadge(status) {
  const cls = "status-" + (status || "staged-reference");
  const shortLabels = {
    "shared-ready": "Ready",
    "native-id-bound": "Native-ID",
    "draft-unsupported": "Blocked",
    "staged-reference": "Ref",
  };
  return `<span class="status-badge ${esc(cls)}">${esc(shortLabels[status] || status)}</span>`;
}

async function apiGet(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

async function apiPost(url, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

/* ============================================================================
 * Initialization & Global State Loading
 * ========================================================================== */

async function initWorkbench() {
  bindTopbarAndModals();
  bindKeyboardShortcuts();
  await loadWorkspaceState();
  await loadCatalogList(true);
}

async function loadWorkspaceState() {
  const packId = state.packId;
  const data = await apiGet(`/api/state?pack=${encodeURIComponent(packId)}`);
  if (state.packId !== packId) return;
  state.contract = data.contract;
  state.templates = data.templates || {};
  state.metadata = data.metadata || {};
  state.drafts = data.drafts || [];
  state.availablePacks = data.available_packs || [];
  state.packManifestPreview = data.pack_manifest_preview || {};
  state.catalogCounts = data.catalog_counts || {};

  document.getElementById("contract-rev-pill").textContent =
    `VS-83 (${state.contract.revision || "pinned"})`;
  document.getElementById("active-pack-badge").textContent = state.packId;

  // Populate pack selector
  const packSel = document.getElementById("pack-selector");
  packSel.innerHTML = state.availablePacks
    .map(
      (p) =>
        `<option value="${esc(p)}" ${p === state.packId ? "selected" : ""}>${esc(p)}</option>`
    )
    .join("");

  // Populate type counts
  for (const t of ["spell", "item", "class", "monster", "race"]) {
    const el = document.getElementById(`count-type-${t}`);
    if (el && state.catalogCounts[t]) {
      el.textContent = state.catalogCounts[t].total ?? "—";
    }
  }

  renderDraftsTray();
  renderFilterCounts();
}

function renderFilterCounts() {
  const tc = state.catalogCounts[state.currentType] || {};
  const setTxt = (id, v) => {
    const el = document.getElementById(id);
    if (el) el.textContent = v !== undefined ? `(${v})` : "";
  };
  setTxt("filter-count-all", tc.total);
  setTxt("filter-count-ready", tc["shared-ready"]);
  setTxt("filter-count-native", tc["native-id-bound"]);
  setTxt("filter-count-unsupported", tc["draft-unsupported"]);
}

async function loadCatalogList(autoSelectFirst = false) {
  renderFilterCounts();
  const url =
    `/api/catalog?type=${encodeURIComponent(state.currentType)}` +
    `&search=${encodeURIComponent(state.searchQuery)}` +
    `&status=${encodeURIComponent(state.statusFilter)}`;
  const data = await apiGet(url);
  state.catalogItems = data.items || [];
  renderCatalogList();

  if (autoSelectFirst && !state.selectedId) {
    if (state.drafts.length > 0 && state.drafts[0].content_type === state.currentType) {
      await selectEntry(state.drafts[0].content_type, state.drafts[0].id);
    } else if (state.catalogItems.length > 0) {
      await selectEntry(state.currentType, state.catalogItems[0].id);
    }
  }
}

function renderCatalogList() {
  const listEl = document.getElementById("catalog-list");
  const draftMap = new Map(state.drafts.map((d) => [`${d.content_type}:${d.id}`, d]));

  if (state.catalogItems.length === 0) {
    listEl.innerHTML = `<div class="empty-builder-state" style="margin-top: 16px;">No catalog records match current filter.</div>`;
    return;
  }

  listEl.innerHTML = state.catalogItems
    .map((item) => {
      const isSelected =
        state.currentType === item.content_type && state.selectedId === item.id;
      const hasDraft = draftMap.has(`${item.content_type}:${item.id}`);
      const statusToUse = hasDraft
        ? draftMap.get(`${item.content_type}:${item.id}`).diagnostics.status
        : item.status;
      return `
        <div class="catalog-row ${isSelected ? "selected" : ""}" data-ctype="${esc(item.content_type)}" data-id="${esc(item.id)}">
          <div class="catalog-row-top">
            <span class="catalog-row-name">${esc(item.name)}</span>
            <div style="display:flex; gap:4px; align-items:center;">
              ${hasDraft ? `<span class="origin-tag">DRAFT</span>` : ""}
              ${renderShortStatusBadge(statusToUse)}
            </div>
          </div>
          <div class="catalog-row-meta">
            <span class="catalog-row-id">${esc(item.id)}</span>
            <span>${esc(item.summary)}</span>
          </div>
        </div>
      `;
    })
    .join("");

  listEl.querySelectorAll(".catalog-row").forEach((row) => {
    row.addEventListener("click", () => {
      selectEntry(row.dataset.ctype, row.dataset.id);
    });
  });
}

function renderDraftsTray() {
  document.getElementById("drafts-count").textContent = state.drafts.length;
  const trayEl = document.getElementById("drafts-list");
  if (state.drafts.length === 0) {
    trayEl.innerHTML = `<div class="empty-builder-state">No drafts staged in <code>${esc(state.packId)}</code> yet.</div>`;
    return;
  }
  trayEl.innerHTML = state.drafts
    .map((d) => {
      const isSelected =
        state.currentType === d.content_type && state.selectedId === d.id;
      const modeTag =
        d.origin?.mode === "override"
          ? "OVERRIDE"
          : d.origin?.mode === "homebrew_clone"
          ? "CLONE"
          : "NEW";
      return `
        <div class="catalog-row ${isSelected ? "selected" : ""}" data-ctype="${esc(d.content_type)}" data-id="${esc(d.id)}">
          <div class="catalog-row-top">
            <span class="catalog-row-name">${esc(d.record.name || d.id)}</span>
            ${renderShortStatusBadge(d.diagnostics.status)}
          </div>
          <div class="catalog-row-meta">
            <span class="catalog-row-id">${esc(d.id)}</span>
            <span class="origin-tag">${esc(modeTag)} · ${esc(d.content_type)}</span>
          </div>
        </div>
      `;
    })
    .join("");

  trayEl.querySelectorAll(".catalog-row").forEach((row) => {
    row.addEventListener("click", async () => {
      const targetType = row.dataset.ctype;
      const targetId = row.dataset.id;
      if (state.currentType !== targetType) {
        state.currentType = targetType;
        syncTypeNavButtons();
        await loadCatalogList(false);
      }
      await selectEntry(targetType, targetId);
    });
  });
}

function syncTypeNavButtons() {
  document.querySelectorAll("#type-nav .type-nav-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.type === state.currentType);
  });
}

/* ============================================================================
 * Selecting & Rendering an Entry in the Center Workbench
 * ========================================================================== */

async function selectEntry(contentType, recordId) {
  const selection = { packId: state.packId, contentType, recordId, generation: ++state.selectionGeneration };
  state.currentType = contentType;
  state.selectedId = recordId;
  state.loadedSelection = null;
  state.activeEntryPayload = null;
  state.workingRecord = null;
  state.isDirty = false;
  ++state.validationGeneration;
  clearTimeout(liveValidateTimer);
  syncTypeNavButtons();
  renderCatalogList();
  renderDraftsTray();
  renderWorkbenchHeader();
  renderWorkbenchCenter();
  renderInspectorPane();

  const data = await apiGet(
    `/api/entry?pack=${encodeURIComponent(selection.packId)}` +
      `&type=${encodeURIComponent(contentType)}` +
      `&id=${encodeURIComponent(recordId)}`
  );
  if (!isCurrentSelection(selection)) return;
  state.loadedSelection = selection;
  state.activeEntryPayload = data;
  const baseRec = data.draft
    ? data.draft.record
    : data.catalog_entry
    ? data.catalog_entry.active_record
    : null;
  state.workingRecord = baseRec ? JSON.parse(JSON.stringify(baseRec)) : null;

  renderWorkbenchHeader();
  renderWorkbenchCenter();
  renderInspectorPane();
}

function isCurrentSelection(selection) {
  return selection && selection.generation === state.selectionGeneration &&
    selection.packId === state.packId && selection.contentType === state.currentType &&
    selection.recordId === state.selectedId;
}

function onWorkingRecordMutated(rerenderCenter = false) {
  state.isDirty = true;
  ++state.validationGeneration;
  renderWorkbenchHeader();
  if (rerenderCenter) {
    renderWorkbenchCenter();
  }
  clearTimeout(liveValidateTimer);
  liveValidateTimer = setTimeout(runLiveValidation, 90);
}

async function runLiveValidation() {
  const selection = state.loadedSelection;
  if (!isCurrentSelection(selection) || !state.workingRecord || !state.activeEntryPayload) return;
  const generation = ++state.validationGeneration;
  const payload = state.activeEntryPayload;
  const isClone =
    state.activeEntryPayload.draft?.origin?.mode === "homebrew_clone" ||
    state.activeEntryPayload.draft?.origin?.mode === "homebrew_new" ||
    String(state.workingRecord.id || "").includes(":");
  try {
    const res = await apiPost("/api/validate_live", {
      pack_id: state.packId,
      content_type: state.currentType,
      record: state.workingRecord,
      is_cloned_homebrew: isClone,
    });
    if (!isCurrentSelection(selection) || generation !== state.validationGeneration || state.activeEntryPayload !== payload) return;
    state.activeEntryPayload.diagnostics = res.diagnostics;
    state.activeEntryPayload.candidate_preview = res.candidate_preview;
    state.activeEntryPayload.field_diff = res.field_diff;
    renderWorkbenchHeader();
    renderInspectorPane();
  } catch (err) {
    console.error("Live validation error:", err);
  }
}

function renderWorkbenchHeader() {
  const payload = state.activeEntryPayload;
  const rec = state.workingRecord;
  const titleEl = document.getElementById("wb-title");
  const idChip = document.getElementById("wb-id-chip");
  const originChip = document.getElementById("wb-origin-chip");
  const statusChip = document.getElementById("wb-status-chip");
  const dirtyChip = document.getElementById("wb-dirty-chip");
  const provLine = document.getElementById("wb-provenance-line");
  const actionsEl = document.getElementById("wb-actions");

  if (!payload || !rec) {
    titleEl.textContent = "Select a Catalog Entry or Draft";
    idChip.style.display = "none";
    originChip.innerHTML = "";
    statusChip.innerHTML = "";
    dirtyChip.style.display = "none";
    provLine.textContent = "Choose any spell, item, or 2024 class from the left catalog.";
    actionsEl.innerHTML = "";
    return;
  }

  const draft = payload.draft;
  const cat = payload.catalog_entry;
  const diag = payload.diagnostics || {};

  titleEl.textContent = rec.name || rec.id;
  idChip.style.display = "inline-flex";
  idChip.innerHTML = `<span>🔒 ID:</span> <strong>${esc(rec.id)}</strong>`;

  if (draft) {
    const modeLabel =
      draft.origin?.mode === "override"
        ? "Pack Override Draft"
        : draft.origin?.mode === "homebrew_clone"
        ? `Homebrew Clone (from ${draft.origin.cloned_from_id})`
        : "New Homebrew Draft";
    originChip.innerHTML = `<span class="origin-tag">${esc(modeLabel)}</span>`;
  } else {
    originChip.innerHTML = `<span class="origin-tag" style="background:rgba(147,172,203,0.12); color:var(--state-info); border-color:var(--state-info-border);">Catalog Source</span>`;
  }

  statusChip.innerHTML = renderStatusBadge(diag.status, diag.status_label);
  dirtyChip.style.display = state.isDirty ? "inline-flex" : "none";

  if (cat) {
    const repCount = (cat.replaced_sources || []).length;
    provLine.innerHTML =
      `Manifest Winner: <code>${esc(cat.winner_coord)}</code>` +
      (repCount > 0
        ? ` · Merged missing fields from <strong>${repCount}</strong> replaced source(s)`
        : " · Single canonical source");
  } else if (draft) {
    provLine.innerHTML = `Workspace File: <code>tools/content_editor/workspaces/${esc(state.packId)}/drafts/${esc(state.currentType)}s/</code>`;
  }

  const isEditableType = state.currentType === "spell" || state.currentType === "item";
  const btns = [];

  if (isEditableType) {
    if (!draft) {
      btns.push(
        `<button class="btn" id="act-stage-override" title="Stage this record in ${esc(state.packId)} with its original ID to override base game values">✎ Stage Override</button>`
      );
    }
    btns.push(
      `<button class="btn" id="act-open-clone" title="Duplicate into a new homebrew record with a stable ${esc(state.packId)}:<slug> ID">⎘ Duplicate as Homebrew</button>`
    );
    if (state.currentType === "spell" && diag.convertible_to_shared) {
      btns.push(
        `<button class="btn btn-gold" id="act-convert-shared" title="Set execution='shared' and normalize area/duration fields">⚡ Convert to Shared</button>`
      );
    }
    if (draft) {
      btns.push(
        `<button class="btn btn-danger btn-sm" id="act-delete-draft" title="Remove this draft from the active workspace">✕ Discard Draft</button>`
      );
    }
    btns.push(
      `<button class="btn btn-gold" id="act-save-draft">${draft ? "💾 Save Draft (Ctrl+S)" : "💾 Save as Override (Ctrl+S)"}</button>`
    );
  }

  actionsEl.innerHTML = btns.join("");

  // Bind header action buttons
  document.getElementById("act-stage-override")?.addEventListener("click", handleStageOverride);
  document.getElementById("act-open-clone")?.addEventListener("click", openCloneModal);
  document.getElementById("act-convert-shared")?.addEventListener("click", handleConvertToShared);
  document.getElementById("act-delete-draft")?.addEventListener("click", handleDeleteDraft);
  document.getElementById("act-save-draft")?.addEventListener("click", handleSaveWorkingDraft);
}

function renderWorkbenchCenter() {
  const scrollEl = document.getElementById("workbench-scroll");
  const payload = state.activeEntryPayload;
  const rec = state.workingRecord;

  if (!payload || !rec) {
    scrollEl.innerHTML = `<div class="empty-builder-state">Select a spell, item, or class from the left catalog to begin.</div>`;
    return;
  }

  if (state.currentType === "spell") {
    scrollEl.innerHTML = buildSpellWorkbenchHTML(rec, payload.diagnostics);
    bindSpellWorkbenchEvents();
  } else if (state.currentType === "item") {
    scrollEl.innerHTML = buildItemWorkbenchHTML(rec, payload.diagnostics);
    bindItemWorkbenchEvents();
  } else if (state.currentType === "class") {
    scrollEl.innerHTML = buildClassComparisonHTML(payload.class_comparison, rec);
  } else {
    scrollEl.innerHTML = buildReadOnlyReferenceHTML(rec);
  }
}

/* ============================================================================
 * SPELL WORKBENCH — Visual Builders (Zero Raw JSON Textareas)
 * ========================================================================== */

function buildSpellWorkbenchHTML(rec, diag) {
  const sc = state.contract.shared_spell;
  const abilities = state.contract.abilities;
  const damageTypes = state.contract.damage_types;
  const classes = state.contract.classes;
  const presets = state.contract.units.duration_presets;

  const isStepsMode = Array.isArray(rec.steps);
  const rangeHex = Number(rec.range ?? 0);
  const rangeFeet = rangeHex * 5;
  const areaHex = Number(rec.area_radius ?? 0);
  const coneHex = Number(rec.cone_size ?? 0);
  const durSecs = rec.duration_seconds ?? "";
  const durRounds = durSecs !== "" && durSecs !== null ? (Number(durSecs) / 6).toFixed(1).replace(/\.0$/, "") : "0";
  const comps = Array.isArray(rec.components) ? rec.components : [];
  const selectedClasses = Array.isArray(rec.classes) ? rec.classes : [];
  const upcast = rec.upcast && typeof rec.upcast === "object" ? rec.upcast : {};
  const scaling = rec.scaling && typeof rec.scaling === "object" ? rec.scaling : {};

  let calloutHTML = "";
  if (diag.status === "native-id-bound") {
    calloutHTML = `
      <div class="callout-banner callout-warning">
        <div class="callout-text">
          <h4>⚠ Native-ID-Bound Spell (<code>SpellSupport.AVAILABLE_SLICES</code>)</h4>
          <p>
            <code>${esc(rec.id)}</code> works on its original ID via dedicated GDScript routing, but a homebrew clone with a new ID will be rejected unless converted to <code>"execution": "shared"</code>.
          </p>
        </div>
        <button class="btn btn-gold" id="banner-convert-shared">⚡ Convert to Shared Contract</button>
      </div>
    `;
  } else if (diag.status === "draft-unsupported") {
    calloutHTML = `
      <div class="callout-banner callout-danger">
        <div class="callout-text">
          <h4>✕ Blocked on VS-83 SharedSpell Contract (${diag.errors.length} issue${diag.errors.length === 1 ? "" : "s"})</h4>
          <p>${esc(diag.errors[0] || "Inspect the VS-83 Check tab on the right for details.")}</p>
        </div>
        ${diag.convertible_to_shared ? `<button class="btn btn-gold" id="banner-convert-shared">⚡ Convert to Shared</button>` : ""}
      </div>
    `;
  }

  return `
    ${calloutHTML}

    <!-- CARD 1: Identity, Pipeline & School -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">I. Spell Identity, Execution Pipeline & School</span>
        <span class="grimoire-card-subtitle">Renaming Display Name never rewrites the locked record ID</span>
      </div>
      <div class="grimoire-card-body">
        <div class="field-grid-4">
          <div class="field-group" style="grid-column: span 2;">
            <label class="field-label">Display Name</label>
            <input type="text" id="sp-name" value="${esc(rec.name || "")}" />
          </div>
          <div class="field-group">
            <label class="field-label">
              <span>Execution Pipeline</span>
              <span class="field-hint">ADR-0018</span>
            </label>
            <select id="sp-execution">
              <option value="shared" ${rec.execution === "shared" ? "selected" : ""}>shared (Data-Driven SharedSpell)</option>
              <option value="" ${!rec.execution ? "selected" : ""}>omitted (Native ID / Unmigrated)</option>
            </select>
          </div>
          <div class="field-group">
            <label class="field-label">Spell Level</label>
            <select id="sp-level">
              ${[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
                .map(
                  (lvl) =>
                    `<option value="${lvl}" ${Number(rec.level ?? 0) === lvl ? "selected" : ""}>${
                      lvl === 0 ? "0 — Cantrip" : `Level ${lvl}`
                    }</option>`
                )
                .join("")}
            </select>
          </div>
        </div>

        <div class="field-grid-4">
          <div class="field-group">
            <label class="field-label">School of Magic</label>
            <select id="sp-school">
              ${sc.schools
                .map(
                  (s) =>
                    `<option value="${esc(s)}" ${rec.school === s ? "selected" : ""}>${esc(
                      s.charAt(0).toUpperCase() + s.slice(1)
                    )}</option>`
                )
                .join("")}
            </select>
          </div>
          <div class="field-group">
            <label class="field-label">Casting Time</label>
            <select id="sp-casting-time">
              ${["action", "bonus_action", "reaction", "1 minute", "10 minutes", "1 hour"]
                .map(
                  (ct) =>
                    `<option value="${esc(ct)}" ${(rec.casting_time || "action") === ct ? "selected" : ""}>${esc(ct)}</option>`
                )
                .join("")}
            </select>
          </div>
          <div class="field-group">
            <label class="field-label">Target Selector</label>
            <select id="sp-target">
              ${["single", "self", "multi", "area", "cone", "single_ally", "all_allies", "all_enemies"]
                .map(
                  (t) =>
                    `<option value="${esc(t)}" ${(rec.target || "single") === t ? "selected" : ""}>${esc(t)}${
                      sc.targets.includes(t) ? "" : " (legacy)"
                    }</option>`
                )
                .join("")}
            </select>
          </div>
          <div class="field-group">
            <label class="field-label">
              <span>Base Targets</span>
              <span class="field-hint">for multi</span>
            </label>
            <input type="number" id="sp-base-targets" min="1" max="20" value="${esc(rec.base_targets ?? "")}" placeholder="1" />
          </div>
        </div>

        <div class="field-group">
          <label class="field-label">Rules Description / Spell Text</label>
          <textarea id="sp-description" rows="2">${esc(rec.description || "")}</textarea>
        </div>
      </div>
    </div>

    <!-- CARD 2: Dual-Unit Geometry, Timing & Components -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">II. Spatial Geometry (Hexes ↔ Feet), Timing & Components</span>
        <span class="grimoire-card-subtitle">1 Hex = 5 Feet · 1 Round = 6 Seconds</span>
      </div>
      <div class="grimoire-card-body">
        <div class="field-grid-3">
          <!-- Range Hex <-> Feet -->
          <div class="field-group">
            <label class="field-label">
              <span>Cast Range</span>
              <span class="field-hint">stored in hexes</span>
            </label>
            <div class="dual-unit-box">
              <div class="dual-unit-col">
                <span class="dual-unit-tag">Hexes (Engine)</span>
                <input type="number" id="sp-range-hex" min="0" max="1000" value="${rangeHex}" />
              </div>
              <span class="dual-unit-sep">⇄</span>
              <div class="dual-unit-col">
                <span class="dual-unit-tag">Feet (5e Table)</span>
                <input type="number" id="sp-range-feet" min="0" max="5000" step="5" value="${rangeFeet}" />
              </div>
            </div>
          </div>

          <!-- Area Radius Hex <-> Feet -->
          <div class="field-group">
            <label class="field-label">
              <span>Sphere / Cube Radius</span>
              <span class="field-hint">area_radius</span>
            </label>
            <div class="dual-unit-box">
              <div class="dual-unit-col">
                <span class="dual-unit-tag">Hexes</span>
                <input type="number" id="sp-area-hex" min="0" max="100" value="${areaHex}" />
              </div>
              <span class="dual-unit-sep">⇄</span>
              <div class="dual-unit-col">
                <span class="dual-unit-tag">Feet</span>
                <input type="number" id="sp-area-feet" min="0" max="500" step="5" value="${areaHex * 5}" />
              </div>
            </div>
          </div>

          <!-- Cone Size Hex <-> Feet -->
          <div class="field-group">
            <label class="field-label">
              <span>Cone Length</span>
              <span class="field-hint">cone_size</span>
            </label>
            <div class="dual-unit-box">
              <div class="dual-unit-col">
                <span class="dual-unit-tag">Hexes</span>
                <input type="number" id="sp-cone-hex" min="0" max="100" value="${coneHex}" />
              </div>
              <span class="dual-unit-sep">⇄</span>
              <div class="dual-unit-col">
                <span class="dual-unit-tag">Feet</span>
                <input type="number" id="sp-cone-feet" min="0" max="500" step="5" value="${coneHex * 5}" />
              </div>
            </div>
          </div>
        </div>

        <!-- Duration Coupled Row -->
        <div class="field-grid-3">
          <div class="field-group">
            <label class="field-label">Duration Preset</label>
            <select id="sp-duration-preset">
              <option value="__custom__">— Custom / Manual —</option>
              ${presets
                .map(
                  (p) =>
                    `<option value="${esc(p.duration)}" ${
                      String(rec.duration || "").toLowerCase() === p.duration ? "selected" : ""
                    }>${esc(p.label)}</option>`
                )
                .join("")}
            </select>
          </div>
          <div class="field-group">
            <label class="field-label">Duration Text (<code>duration</code>)</label>
            <input type="text" id="sp-duration-text" value="${esc(rec.duration || "instantaneous")}" />
          </div>
          <div class="field-group">
            <label class="field-label">
              <span>Engine Seconds (<code>duration_seconds</code>)</span>
              <span class="field-hint">${durRounds} rounds</span>
            </label>
            <input type="number" id="sp-duration-seconds" min="0" max="86400" value="${esc(durSecs)}" placeholder="None (instantaneous)" />
          </div>
        </div>

        <!-- Components & Flags -->
        <div class="field-grid-2">
          <div class="field-group">
            <label class="field-label">Spell Flags & Target Rules</label>
            <div class="pill-group">
              <label class="toggle-pill ${rec.concentration ? "active" : ""}">
                <input type="checkbox" id="sp-flag-concentration" ${rec.concentration ? "checked" : ""} hidden />
                <span>Concentration</span>
              </label>
              <label class="toggle-pill ${rec.ritual ? "active" : ""}">
                <input type="checkbox" id="sp-flag-ritual" ${rec.ritual ? "checked" : ""} hidden />
                <span>Ritual</span>
              </label>
              <label class="toggle-pill ${rec.requires_target_sight ? "active" : ""}">
                <input type="checkbox" id="sp-flag-sight" ${rec.requires_target_sight ? "checked" : ""} hidden />
                <span>Requires Target Sight</span>
              </label>
              <label class="toggle-pill ${rec.ignore_cover_on_save ? "active" : ""}">
                <input type="checkbox" id="sp-flag-cover" ${rec.ignore_cover_on_save ? "checked" : ""} hidden />
                <span>Ignore Cover on Save</span>
              </label>
            </div>
          </div>

          <div class="field-group">
            <label class="field-label">Components (V / S / M)</label>
            <div style="display:flex; gap:8px; align-items:center;">
              <div class="pill-group">
                ${["V", "S", "M"]
                  .map(
                    (c) => `
                  <label class="toggle-pill ${comps.includes(c) ? "active" : ""}" data-comp="${c}">
                    <span>${c}</span>
                  </label>
                `
                  )
                  .join("")}
              </div>
              <input
                type="text"
                id="sp-material"
                placeholder="Material description (if M)..."
                value="${esc(rec.material || "")}"
                style="flex:1;"
              />
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- CARD 3: Delivery & Payload Pipeline (Flat vs Ordered Steps ADR-0019) -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">III. Delivery & Mechanical Payload</span>
        <div class="mode-switcher">
          <button type="button" class="mode-switcher-btn ${!isStepsMode ? "active" : ""}" id="btn-mode-flat">
            Flat Delivery
          </button>
          <button type="button" class="mode-switcher-btn ${isStepsMode ? "active" : ""}" id="btn-mode-steps">
            Ordered Steps Pipeline (ADR-0019)
          </button>
        </div>
      </div>
      <div class="grimoire-card-body">
        ${
          !isStepsMode
            ? buildFlatDeliveryHTML(rec, sc, abilities, damageTypes)
            : buildOrderedStepsBuilderHTML(rec.steps || [], sc, abilities, damageTypes)
        }
      </div>
    </div>

    <!-- CARD 4: Shared Effects Builder (Flat Mode) -->
    ${
      !isStepsMode
        ? `
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <div>
          <span class="grimoire-card-title">IV. Shared Effects Builder (<code>effects</code>)</span>
          <span class="grimoire-card-subtitle" style="margin-left:8px;">Visual cards for heal, temporary_hp, conditions, area_selection, and source_benefits</span>
        </div>
        <div class="pill-group">
          <button type="button" class="btn btn-sm btn-gold" data-add-effect="heal">+ Heal</button>
          <button type="button" class="btn btn-sm btn-gold" data-add-effect="temporary_hp">+ Temp HP</button>
          <button type="button" class="btn btn-sm btn-gold" data-add-effect="grant_condition">+ Condition</button>
          <button type="button" class="btn btn-sm btn-gold" data-add-effect="remove_condition">+ Cure</button>
          <button type="button" class="btn btn-sm btn-gold" data-add-effect="grant_source_benefits">+ Stat Buff</button>
          <button type="button" class="btn btn-sm" data-add-effect="area_selection">+ Area Shape</button>
        </div>
      </div>
      <div class="grimoire-card-body">
        ${buildEffectsStackHTML(rec.effects || [], sc, "root")}
      </div>
    </div>
    `
        : ""
    }

    <!-- CARD 5: Upcast & Cantrip Scaling -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">V. Slot Upcasting & Cantrip Tier Scaling</span>
        <span class="grimoire-card-subtitle">Structured <code>upcast</code> and cantrip <code>scaling</code></span>
      </div>
      <div class="grimoire-card-body">
        <div class="field-grid-4">
          <div class="field-group">
            <label class="field-label">
              <span>Damage / Slot Level</span>
              <span class="field-hint">damage_per_level</span>
            </label>
            <input type="text" id="sp-up-dmg" class="mono-input" placeholder="e.g. 1d6" value="${esc(upcast.damage_per_level || "")}" />
          </div>
          <div class="field-group">
            <label class="field-label">
              <span>Heal Dice / Level</span>
              <span class="field-hint">healing_dice_per_level</span>
            </label>
            <input type="text" id="sp-up-healdice" class="mono-input" placeholder="e.g. 1d8" value="${esc(upcast.healing_dice_per_level || "")}" />
          </div>
          <div class="field-group">
            <label class="field-label">
              <span>Flat Heal / Level</span>
              <span class="field-hint">healing_per_level</span>
            </label>
            <input type="number" id="sp-up-healflat" min="0" max="100" placeholder="0" value="${esc(upcast.healing_per_level ?? "")}" />
          </div>
          <div class="field-group">
            <label class="field-label">
              <span>Temp HP / Level</span>
              <span class="field-hint">temporary_hp_per_level</span>
            </label>
            <input type="number" id="sp-up-thp" min="0" max="100" placeholder="0" value="${esc(upcast.temporary_hp_per_level ?? "")}" />
          </div>
        </div>

        <div class="field-grid-4">
          <div class="field-group">
            <label class="field-label">
              <span>Extra Targets / Level</span>
              <span class="field-hint">additional_targets_per_level</span>
            </label>
            <input type="number" id="sp-up-targets" min="0" max="20" placeholder="0" value="${esc(upcast.additional_targets_per_level ?? "")}" />
          </div>
          <div class="field-group">
            <label class="field-label">Cantrip Lvl 5 Dice</label>
            <input type="text" id="sp-scale-5" class="mono-input" placeholder="e.g. 2d10" value="${esc(scaling["5"] || "")}" />
          </div>
          <div class="field-group">
            <label class="field-label">Cantrip Lvl 11 Dice</label>
            <input type="text" id="sp-scale-11" class="mono-input" placeholder="e.g. 3d10" value="${esc(scaling["11"] || "")}" />
          </div>
          <div class="field-group">
            <label class="field-label">Cantrip Lvl 17 Dice</label>
            <input type="text" id="sp-scale-17" class="mono-input" placeholder="e.g. 4d10" value="${esc(scaling["17"] || "")}" />
          </div>
        </div>
      </div>
    </div>

    <!-- CARD 6: Lifetimes, Repeat Saves & Source-End Rules -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">VI. Repeat Saves, Stages & Source-End Rules</span>
        <div class="pill-group">
          <button type="button" class="btn btn-sm" id="btn-add-repeat-stage">+ Add Repeat Stage</button>
          <button type="button" class="btn btn-sm" id="btn-add-end-rule">+ Add Source-End Rule</button>
        </div>
      </div>
      <div class="grimoire-card-body">
        <div class="field-grid-3">
          <div class="field-group">
            <label class="field-label">Repeat Save & Damage Termination</label>
            <div class="pill-group">
              <label class="toggle-pill ${rec.repeat_save ? "active" : ""}">
                <input type="checkbox" id="sp-repeat-save" ${rec.repeat_save ? "checked" : ""} hidden />
                <span>Repeat Save</span>
              </label>
              <label class="toggle-pill ${rec.end_on_target_damage ? "active" : ""}">
                <input type="checkbox" id="sp-end-target-dmg" ${rec.end_on_target_damage ? "checked" : ""} hidden />
                <span>End on Target Damage</span>
              </label>
              <label class="toggle-pill ${rec.end_on_any_damage ? "active" : ""}">
                <input type="checkbox" id="sp-end-any-dmg" ${rec.end_on_any_damage ? "checked" : ""} hidden />
                <span>End on Any Damage</span>
              </label>
            </div>
          </div>
          <div class="field-group">
            <label class="field-label">Repeat Save Schedule</label>
            <select id="sp-repeat-schedule">
              <option value="" ${!rec.repeat_save_schedule ? "selected" : ""}>default (end_of_turn)</option>
              <option value="end_of_turn" ${rec.repeat_save_schedule === "end_of_turn" ? "selected" : ""}>end_of_turn</option>
              <option value="start_of_turn" ${rec.repeat_save_schedule === "start_of_turn" ? "selected" : ""}>start_of_turn</option>
              <option value="interval" ${rec.repeat_save_schedule === "interval" ? "selected" : ""}>interval (seconds)</option>
            </select>
          </div>
          <div class="field-group">
            <label class="field-label">Repeat Interval (Seconds)</label>
            <input type="number" id="sp-repeat-interval" min="6" max="86400" step="6" value="${esc(rec.repeat_save_interval_seconds ?? "")}" placeholder="6" />
          </div>
        </div>

        ${buildRepeatSaveStagesHTML(rec.repeat_save_stages || [], sc)}
        ${buildSourceEndRulesHTML(rec.source_end_rules || [], sc)}
      </div>
    </div>

    <!-- CARD 7: Composable Class Spell Lists -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">VII. Composable Class Spell List Additions (<code>pack.json -> spell_list_additions</code>)</span>
        <span class="grimoire-card-subtitle">Never overwrites <code>data/core/classes/*.json</code></span>
      </div>
      <div class="grimoire-card-body">
        <div class="pill-group" id="sp-class-pills">
          ${classes
            .map(
              (cls) => `
            <label class="toggle-pill ${selectedClasses.includes(cls) ? "active" : ""}" data-cls="${esc(cls)}">
              <span>${esc(cls.charAt(0).toUpperCase() + cls.slice(1))}</span>
            </label>
          `
            )
            .join("")}
        </div>
      </div>
    </div>
  `;
}

function buildFlatDeliveryHTML(rec, sc, abilities, damageTypes) {
  const dPolicy = rec.damage_dice_policy || {};
  const dMult = rec.damage_result_multiplier || {};
  return `
    <div class="field-grid-4">
      <div class="field-group">
        <label class="field-label">Attack Roll (<code>attack_type</code>)</label>
        <select id="sp-attack-type">
          ${sc.attack_types
            .map(
              (at) =>
                `<option value="${esc(at)}" ${(rec.attack_type || "none") === at ? "selected" : ""}>${esc(at)}</option>`
            )
            .join("")}
        </select>
      </div>
      <div class="field-group">
        <label class="field-label">Saving Throw (<code>save</code>)</label>
        <select id="sp-save">
          <option value="" ${!rec.save ? "selected" : ""}>None</option>
          ${abilities
            .map(
              (ab) =>
                `<option value="${esc(ab)}" ${rec.save === ab ? "selected" : ""}>${esc(ab)}</option>`
            )
            .join("")}
        </select>
      </div>
      <div class="field-group">
        <label class="field-label">Damage Formula (<code>damage</code>)</label>
        <input type="text" id="sp-damage" class="mono-input" placeholder="e.g. 1d10 or 8d6" value="${esc(rec.damage ?? "")}" />
      </div>
      <div class="field-group">
        <label class="field-label">Damage Type</label>
        <select id="sp-damage-type">
          <option value="" ${!rec.damage_type ? "selected" : ""}>None</option>
          ${damageTypes
            .map(
              (dt) =>
                `<option value="${esc(dt)}" ${rec.damage_type === dt ? "selected" : ""}>${esc(dt)}</option>`
            )
            .join("")}
        </select>
      </div>
    </div>

    <div class="field-grid-4">
      <div class="field-group">
        <label class="field-label">Save Outcome</label>
        <label class="toggle-pill ${rec.half_on_save ? "active" : ""}" style="width:fit-content;">
          <input type="checkbox" id="sp-half-save" ${rec.half_on_save ? "checked" : ""} hidden />
          <span>Half Damage on Successful Save</span>
        </label>
      </div>
      <div class="field-group">
        <label class="field-label">Dice Policy: Maximize Count</label>
        <input type="number" id="sp-dp-max" min="0" max="20" value="${esc(dPolicy.maximize ?? "")}" placeholder="0" />
      </div>
      <div class="field-group">
        <label class="field-label">Dice Policy: Die Sides</label>
        <select id="sp-dp-sides">
          <option value="">None</option>
          ${[4, 6, 8, 10, 12, 20]
            .map(
              (s) =>
                `<option value="${s}" ${Number(dPolicy.sides) === s ? "selected" : ""}>d${s}</option>`
            )
            .join("")}
        </select>
      </div>
      <div class="field-group">
        <label class="field-label">Result Multiplier (Num / Den)</label>
        <div style="display:flex; gap:4px;">
          <input type="number" id="sp-dm-num" min="0" max="20" placeholder="Num" value="${esc(dMult.numerator ?? "")}" />
          <input type="number" id="sp-dm-den" min="1" max="20" placeholder="Den" value="${esc(dMult.denominator ?? "")}" />
        </div>
      </div>
    </div>
  `;
}

function buildOrderedStepsBuilderHTML(steps, sc, abilities, damageTypes) {
  return `
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
      <span style="font-size:12px; color:var(--text-secondary);">
        Ordered <code>steps</code> execute sequentially in <code>SharedStepExecutor</code> with outcome gating (<code>hit</code>, <code>miss</code>, <code>failed_save</code>, <code>successful_save</code>).
      </span>
      <div class="pill-group">
        <button type="button" class="btn btn-sm btn-gold" data-add-step="attack">+ Attack Step</button>
        <button type="button" class="btn btn-sm btn-gold" data-add-step="save">+ Save Step</button>
        <button type="button" class="btn btn-sm btn-gold" data-add-step="damage">+ Damage Step</button>
        <button type="button" class="btn btn-sm btn-gold" data-add-step="effect">+ Effect Step</button>
      </div>
    </div>
    <div class="builder-stack">
      ${
        steps.length === 0
          ? `<div class="empty-builder-state">No ordered steps defined. Add an Attack, Save, Damage, or Effect step above.</div>`
          : steps
              .map((st, idx) => buildSingleStepCardHTML(st, idx, steps.length, sc, abilities, damageTypes))
              .join("")
      }
    </div>
  `;
}

function buildSingleStepCardHTML(step, idx, total, sc, abilities, damageTypes) {
  const stype = step.type || "attack";
  const starget = step.target || "target";
  const shape = step.shape || "sphere";
  const geomKey = shape === "sphere" ? "radius" : "size";
  const geomVal = Number(step[geomKey] ?? 1);

  return `
    <div class="subcard subcard-step" data-step-idx="${idx}">
      <div class="subcard-header">
        <div class="subcard-title">
          <span class="step-index-badge">STEP ${idx + 1}</span>
          <span>${esc(stype.toUpperCase())}</span>
          ${step.id ? `<code style="color:var(--accent-primary-bright);">#${esc(step.id)}</code>` : ""}
        </div>
        <div style="display:flex; gap:4px;">
          <button type="button" class="btn btn-sm" data-step-move="-1" data-idx="${idx}" ${idx === 0 ? "disabled" : ""}>↑</button>
          <button type="button" class="btn btn-sm" data-step-move="1" data-idx="${idx}" ${idx === total - 1 ? "disabled" : ""}>↓</button>
          <button type="button" class="btn btn-sm btn-danger" data-step-del="${idx}">✕ Remove</button>
        </div>
      </div>

      <div class="field-grid-4">
        <div class="field-group">
          <label class="field-label">Step ID (for <code>gate_step</code>)</label>
          <input type="text" class="mono-input step-field" data-idx="${idx}" data-key="id" value="${esc(step.id || "")}" placeholder="e.g. primary_attack" />
        </div>
        <div class="field-group">
          <label class="field-label">Step Type</label>
          <select class="step-field" data-idx="${idx}" data-key="type">
            ${sc.step_types
              .map((t) => `<option value="${esc(t)}" ${stype === t ? "selected" : ""}>${esc(t)}</option>`)
              .join("")}
          </select>
        </div>
        <div class="field-group">
          <label class="field-label">Execution Gate</label>
          <select class="step-field" data-idx="${idx}" data-key="gate">
            ${sc.step_gates
              .map(
                (g) =>
                  `<option value="${esc(g)}" ${(step.gate || "always") === g ? "selected" : ""}>${esc(g)}</option>`
              )
              .join("")}
          </select>
        </div>
        <div class="field-group">
          <label class="field-label">Gate Step ID (Optional)</label>
          <input type="text" class="mono-input step-field" data-idx="${idx}" data-key="gate_step" value="${esc(step.gate_step || "")}" placeholder="prior step id" />
        </div>
      </div>

      <div class="field-grid-4">
        <div class="field-group">
          <label class="field-label">Step Target</label>
          <select class="step-field" data-idx="${idx}" data-key="target">
            ${sc.step_targets
              .map((t) => `<option value="${esc(t)}" ${starget === t ? "selected" : ""}>${esc(t)}</option>`)
              .join("")}
          </select>
        </div>

        ${
          starget === "area"
            ? `
          <div class="field-group">
            <label class="field-label">Area Shape</label>
            <select class="step-field" data-idx="${idx}" data-key="shape">
              ${sc.area_shapes
                .map((sh) => `<option value="${esc(sh)}" ${shape === sh ? "selected" : ""}>${esc(sh)}</option>`)
                .join("")}
            </select>
          </div>
          <div class="field-group" style="grid-column: span 2;">
            <label class="field-label">Step Area ${shape === "sphere" ? "Radius" : "Size"} (Hexes ↔ Feet)</label>
            <div class="dual-unit-box">
              <div class="dual-unit-col">
                <span class="dual-unit-tag">Hexes</span>
                <input type="number" class="step-geom-hex" data-idx="${idx}" data-gkey="${geomKey}" min="1" max="100" value="${geomVal}" />
              </div>
              <span class="dual-unit-sep">⇄</span>
              <div class="dual-unit-col">
                <span class="dual-unit-tag">Feet</span>
                <input type="number" class="step-geom-feet" data-idx="${idx}" data-gkey="${geomKey}" min="5" max="500" step="5" value="${geomVal * 5}" />
              </div>
            </div>
          </div>
        `
            : ""
        }

        ${
          stype === "attack"
            ? `
          <div class="field-group">
            <label class="field-label">Attack Type</label>
            <select class="step-field" data-idx="${idx}" data-key="attack_type">
              <option value="ranged_spell" ${step.attack_type === "ranged_spell" ? "selected" : ""}>ranged_spell</option>
              <option value="melee_spell" ${step.attack_type === "melee_spell" ? "selected" : ""}>melee_spell</option>
            </select>
          </div>
        `
            : ""
        }

        ${
          stype === "save"
            ? `
          <div class="field-group">
            <label class="field-label">Save Ability</label>
            <select class="step-field" data-idx="${idx}" data-key="save">
              ${abilities
                .map((ab) => `<option value="${esc(ab)}" ${step.save === ab ? "selected" : ""}>${esc(ab)}</option>`)
                .join("")}
            </select>
          </div>
          <div class="field-group">
            <label class="field-label">Half on Save</label>
            <select class="step-field-bool" data-idx="${idx}" data-key="half_on_save">
              <option value="false" ${!step.half_on_save ? "selected" : ""}>No (0 on save)</option>
              <option value="true" ${step.half_on_save ? "selected" : ""}>Yes (Half on save)</option>
            </select>
          </div>
        `
            : ""
        }
      </div>

      ${
        stype !== "effect"
          ? `
        <div class="field-grid-2">
          <div class="field-group">
            <label class="field-label">Step Damage Formula</label>
            <input type="text" class="mono-input step-field" data-idx="${idx}" data-key="damage" value="${esc(step.damage || "")}" placeholder="e.g. 2d6" />
          </div>
          <div class="field-group">
            <label class="field-label">Step Damage Type</label>
            <select class="step-field" data-idx="${idx}" data-key="damage_type">
              <option value="">None</option>
              ${damageTypes
                .map(
                  (dt) => `<option value="${esc(dt)}" ${step.damage_type === dt ? "selected" : ""}>${esc(dt)}</option>`
                )
                .join("")}
            </select>
          </div>
        </div>
      `
          : ""
      }

      ${
        stype !== "damage"
          ? `
        <div style="border-top: 1px solid rgba(255,255,255,0.06); padding-top: 8px;">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
            <span style="font-size:11px; color:var(--text-muted); font-weight:600;">Step Effects (<code>steps[${idx}].effects</code>)</span>
            <div class="pill-group">
              <button type="button" class="btn btn-sm" data-add-step-eff="${idx}" data-eff-type="grant_condition">+ Condition</button>
              <button type="button" class="btn btn-sm" data-add-step-eff="${idx}" data-eff-type="heal">+ Heal</button>
              <button type="button" class="btn btn-sm" data-add-step-eff="${idx}" data-eff-type="temporary_hp">+ Temp HP</button>
              <button type="button" class="btn btn-sm" data-add-step-eff="${idx}" data-eff-type="grant_source_benefits">+ Stat Buff</button>
            </div>
          </div>
          ${buildEffectsStackHTML(step.effects || [], sc, `step-${idx}`)}
        </div>
      `
          : ""
      }
    </div>
  `;
}

function buildEffectsStackHTML(effects, sc, scopeKey) {
  if (!Array.isArray(effects) || effects.length === 0) {
    return `<div class="empty-builder-state">No effects in this list. Use the + buttons above to add shared operations.</div>`;
  }

  return `
    <div class="builder-stack">
      ${effects.map((eff, idx) => buildSingleEffectCardHTML(eff, idx, sc, scopeKey)).join("")}
    </div>
  `;
}

function buildSingleEffectCardHTML(eff, idx, sc, scopeKey) {
  const etype = eff.type || "heal";
  const allowedKnown = new Set([
    "type",
    "on_spell_hit",
    "on_failed_save",
    "rider_by_outcome",
    "when",
    "value",
    "ability_bonus_from_caster",
    "condition",
    "benefits",
    "shape",
    "radius",
    "size",
  ]);
  const extraKeys = Object.keys(eff).filter((k) => !allowedKnown.has(k));

  let bodyFields = "";
  if (etype === "heal" || etype === "temporary_hp") {
    const valStr = typeof eff.value === "object" ? JSON.stringify(eff.value) : String(eff.value ?? "1d8");
    bodyFields = `
      <div class="field-grid-3">
        <div class="field-group">
          <label class="field-label">Dice / Formula (<code>value</code>)</label>
          <input type="text" class="mono-input eff-field" data-scope="${esc(scopeKey)}" data-idx="${idx}" data-key="value" value="${esc(valStr)}" />
        </div>
        <div class="field-group">
          <label class="field-label">Caster Ability Modifier</label>
          <select class="eff-field-bool" data-scope="${esc(scopeKey)}" data-idx="${idx}" data-key="ability_bonus_from_caster">
            <option value="false" ${!eff.ability_bonus_from_caster ? "selected" : ""}>No</option>
            <option value="true" ${eff.ability_bonus_from_caster ? "selected" : ""}>+ Spellcasting Ability Mod</option>
          </select>
        </div>
        <div class="field-group">
          <label class="field-label">Trigger Gate</label>
          <select class="eff-gate-select" data-scope="${esc(scopeKey)}" data-idx="${idx}">
            <option value="always" ${!eff.on_spell_hit && !eff.on_failed_save ? "selected" : ""}>Always</option>
            <option value="on_spell_hit" ${eff.on_spell_hit ? "selected" : ""}>On Spell Hit (on_spell_hit)</option>
            <option value="on_failed_save" ${eff.on_failed_save ? "selected" : ""}>On Failed Save (on_failed_save)</option>
          </select>
        </div>
      </div>
    `;
  } else if (etype === "grant_condition" || etype === "remove_condition") {
    bodyFields = `
      <div class="field-grid-2">
        <div class="field-group">
          <label class="field-label">Condition ID (<code>condition</code>)</label>
          <select class="eff-field" data-scope="${esc(scopeKey)}" data-idx="${idx}" data-key="condition">
            ${sc.conditions
              .map(
                (c) => `<option value="${esc(c)}" ${eff.condition === c ? "selected" : ""}>${esc(c)}</option>`
              )
              .join("")}
            ${
              eff.condition && !sc.conditions.includes(eff.condition)
                ? `<option value="${esc(eff.condition)}" selected>${esc(eff.condition)} (unsupported)</option>`
                : ""
            }
          </select>
        </div>
        <div class="field-group">
          <label class="field-label">Outcome Trigger</label>
          <select class="eff-gate-select" data-scope="${esc(scopeKey)}" data-idx="${idx}">
            <option value="always" ${!eff.on_spell_hit && !eff.on_failed_save ? "selected" : ""}>Always / Automatic</option>
            <option value="on_failed_save" ${eff.on_failed_save ? "selected" : ""}>On Failed Save (on_failed_save)</option>
            <option value="on_spell_hit" ${eff.on_spell_hit ? "selected" : ""}>On Spell Hit (on_spell_hit)</option>
          </select>
        </div>
      </div>
    `;
  } else if (etype === "area_selection") {
    const shape = eff.shape || "sphere";
    const gKey = shape === "sphere" ? "radius" : "size";
    const gVal = Number(eff[gKey] ?? 2);
    bodyFields = `
      <div class="field-grid-3">
        <div class="field-group">
          <label class="field-label">Area Shape</label>
          <select class="eff-area-shape" data-scope="${esc(scopeKey)}" data-idx="${idx}">
            <option value="sphere" ${shape === "sphere" ? "selected" : ""}>sphere (uses radius)</option>
            <option value="cone" ${shape === "cone" ? "selected" : ""}>cone (uses size)</option>
            <option value="cube" ${shape === "cube" ? "selected" : ""}>cube (uses size)</option>
          </select>
        </div>
        <div class="field-group" style="grid-column: span 2;">
          <label class="field-label">${shape === "sphere" ? "Radius" : "Size"} in Hexes ↔ Feet</label>
          <div class="dual-unit-box">
            <div class="dual-unit-col">
              <span class="dual-unit-tag">Hexes (${gKey})</span>
              <input type="number" class="eff-area-hex" data-scope="${esc(scopeKey)}" data-idx="${idx}" data-gkey="${gKey}" min="1" max="100" value="${gVal}" />
            </div>
            <span class="dual-unit-sep">⇄</span>
            <div class="dual-unit-col">
              <span class="dual-unit-tag">Feet</span>
              <input type="number" class="eff-area-feet" data-scope="${esc(scopeKey)}" data-idx="${idx}" data-gkey="${gKey}" min="5" max="500" step="5" value="${gVal * 5}" />
            </div>
          </div>
        </div>
      </div>
    `;
  } else if (etype === "grant_source_benefits") {
    const benefits = Array.isArray(eff.benefits) ? eff.benefits : [];
    const acObj = benefits.find((b) => b.stat === "AC");
    const spdObj = benefits.find((b) => b.stat === "speed");
    bodyFields = `
      <div class="field-grid-2">
        <div class="field-group">
          <label class="field-label">Armor Class Bonus (+AC)</label>
          <input type="number" class="eff-sb-stat" data-scope="${esc(scopeKey)}" data-idx="${idx}" data-stat="AC" min="0" max="10" value="${esc(acObj?.amount ?? 0)}" />
        </div>
        <div class="field-group">
          <label class="field-label">Walking Speed Bonus (+Hexes · 1 hex = 5 ft)</label>
          <input type="number" class="eff-sb-stat" data-scope="${esc(scopeKey)}" data-idx="${idx}" data-stat="speed" min="0" max="10" value="${esc(spdObj?.amount ?? 0)}" />
        </div>
      </div>
    `;
  } else {
    bodyFields = `
      <div class="diag-warn">
        Legacy / non-shared effect type <code>${esc(etype)}</code>. Preserved losslessly in draft; convert or replace to make shared-ready.
      </div>
    `;
  }

  return `
    <div class="subcard">
      <div class="subcard-header">
        <div class="subcard-title">
          <select class="eff-type-select" data-scope="${esc(scopeKey)}" data-idx="${idx}" style="width:auto; font-weight:700;">
            ${sc.effects
              .map((t) => `<option value="${esc(t)}" ${etype === t ? "selected" : ""}>${esc(t)}</option>`)
              .join("")}
            ${
              !sc.effects.includes(etype)
                ? `<option value="${esc(etype)}" selected>${esc(etype)} (non-shared)</option>`
                : ""
            }
          </select>
          ${
            extraKeys.length > 0
              ? `<span class="origin-tag" title="Extra keys parked into _editor_meta on Game Pack Export">${extraKeys.length} parked key(s): ${esc(extraKeys.join(", "))}</span>`
              : ""
          }
        </div>
        <button type="button" class="btn btn-sm btn-danger" data-del-eff="${idx}" data-scope="${esc(scopeKey)}">✕</button>
      </div>
      ${bodyFields}
    </div>
  `;
}

function buildRepeatSaveStagesHTML(stages, sc) {
  if (!Array.isArray(stages) || stages.length === 0) return "";
  return `
    <div class="builder-stack">
      <div style="font-size:11px; font-weight:700; color:var(--accent-primary-bright);">Repeat Save Progression Stages (<code>repeat_save_stages</code>)</div>
      ${stages
        .map(
          (stg, idx) => `
        <div class="subcard">
          <div class="subcard-header">
            <span class="subcard-title">Stage ${idx + 1}</span>
            <button type="button" class="btn btn-sm btn-danger" data-del-stage="${idx}">✕</button>
          </div>
          <div class="field-grid-4">
            <div class="field-group">
              <label class="field-label">Condition</label>
              <select class="stage-field" data-idx="${idx}" data-key="condition">
                ${sc.conditions
                  .map((c) => `<option value="${esc(c)}" ${stg.condition === c ? "selected" : ""}>${esc(c)}</option>`)
                  .join("")}
              </select>
            </div>
            <div class="field-group">
              <label class="field-label">Successes Required</label>
              <input type="number" class="stage-field-int" data-idx="${idx}" data-key="successes_required" min="1" max="20" value="${esc(stg.successes_required ?? 1)}" />
            </div>
            <div class="field-group">
              <label class="field-label">On Failure</label>
              <select class="stage-field" data-idx="${idx}" data-key="on_failure">
                <option value="stay" ${(stg.on_failure || "stay") === "stay" ? "selected" : ""}>stay</option>
                <option value="advance" ${stg.on_failure === "advance" ? "selected" : ""}>advance</option>
                <option value="end" ${stg.on_failure === "end" ? "selected" : ""}>end</option>
              </select>
            </div>
            <div class="field-group">
              <label class="field-label">Minimum Margin</label>
              <input type="number" class="stage-field-int" data-idx="${idx}" data-key="minimum_margin" min="0" max="100" value="${esc(stg.minimum_margin ?? 0)}" />
            </div>
          </div>
        </div>
      `
        )
        .join("")}
    </div>
  `;
}

function buildSourceEndRulesHTML(rules, sc) {
  if (!Array.isArray(rules) || rules.length === 0) return "";
  return `
    <div class="builder-stack">
      <div style="font-size:11px; font-weight:700; color:var(--accent-primary-bright);">Structured Source-End Rules (<code>source_end_rules</code>)</div>
      ${rules
        .map(
          (r, idx) => `
        <div class="subcard">
          <div class="subcard-header">
            <span class="subcard-title">End Rule ${idx + 1}: on <code>${esc(r.event || "damage")}</code></span>
            <button type="button" class="btn btn-sm btn-danger" data-del-endrule="${idx}">✕</button>
          </div>
          <div class="field-grid-3">
            <div class="field-group">
              <label class="field-label">Trigger Event</label>
              <select class="endrule-field" data-idx="${idx}" data-key="event">
                ${sc.source_end_events
                  .map((ev) => `<option value="${esc(ev)}" ${r.event === ev ? "selected" : ""}>${esc(ev)}</option>`)
                  .join("")}
              </select>
            </div>
            <div class="field-group">
              <label class="field-label">Actor</label>
              <select class="endrule-field" data-idx="${idx}" data-key="actor">
                ${sc.source_end_actors
                  .map((ac) => `<option value="${esc(ac)}" ${(r.actor || "any") === ac ? "selected" : ""}>${esc(ac)}</option>`)
                  .join("")}
              </select>
            </div>
            <div class="field-group">
              <label class="field-label">Filter (<code>except_source_id</code> / <code>status</code>)</label>
              <input
                type="text"
                class="mono-input endrule-filter"
                data-idx="${idx}"
                placeholder="e.g. this_source or incapacitated"
                value="${esc(r.except_source_id || r.status || r.school || "")}"
              />
            </div>
          </div>
        </div>
      `
        )
        .join("")}
    </div>
  `;
}

function bindSpellWorkbenchEvents() {
  const rec = state.workingRecord;
  if (!rec) return;

  document.getElementById("banner-convert-shared")?.addEventListener("click", handleConvertToShared);

  const bindText = (id, key, emptyDeletes = false) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.addEventListener("input", () => {
      const val = el.value;
      if (emptyDeletes && val.trim() === "") {
        delete rec[key];
      } else {
        rec[key] = val;
      }
      onWorkingRecordMutated(false);
    });
  };

  bindText("sp-name", "name");
  bindText("sp-execution", "execution", true);
  bindText("sp-school", "school");
  bindText("sp-casting-time", "casting_time");
  bindText("sp-description", "description");
  bindText("sp-material", "material", true);
  bindText("sp-repeat-schedule", "repeat_save_schedule", true);

  document.getElementById("sp-level")?.addEventListener("change", (e) => {
    rec.level = parseInt(e.target.value, 10) || 0;
    onWorkingRecordMutated(false);
  });

  document.getElementById("sp-target")?.addEventListener("change", (e) => {
    rec.target = e.target.value;
    onWorkingRecordMutated(false);
  });

  document.getElementById("sp-base-targets")?.addEventListener("input", (e) => {
    const v = e.target.value.trim();
    if (v === "") delete rec.base_targets;
    else rec.base_targets = parseInt(v, 10) || 1;
    onWorkingRecordMutated(false);
  });

  // Coupled Hex <-> Feet for Range, Area Radius, Cone Size
  const bindHexFeet = (hexId, feetId, fieldKey, syncAreaShape = null) => {
    const hexEl = document.getElementById(hexId);
    const feetEl = document.getElementById(feetId);
    if (!hexEl || !feetEl) return;

    const applyHex = (h) => {
      if (fieldKey === "range") {
        rec.range = Math.max(0, h);
      } else if (h <= 0) {
        delete rec[fieldKey];
      } else {
        rec[fieldKey] = h;
        if (syncAreaShape && Array.isArray(rec.effects)) {
          const areaEff = rec.effects.find((ef) => ef && ef.type === "area_selection");
          if (areaEff) {
            if (syncAreaShape === "sphere") areaEff.radius = h;
            else areaEff.size = h;
          }
        }
      }
      onWorkingRecordMutated(false);
    };

    hexEl.addEventListener("input", () => {
      const h = parseInt(hexEl.value || "0", 10);
      feetEl.value = isNaN(h) ? 0 : h * 5;
      if (!isNaN(h)) applyHex(h);
    });
    feetEl.addEventListener("input", () => {
      const f = parseInt(feetEl.value || "0", 10);
      const h = isNaN(f) ? 0 : Math.round(f / 5);
      hexEl.value = h;
      applyHex(h);
    });
  };

  bindHexFeet("sp-range-hex", "sp-range-feet", "range");
  bindHexFeet("sp-area-hex", "sp-area-feet", "area_radius", "sphere");
  bindHexFeet("sp-cone-hex", "sp-cone-feet", "cone_size", "cone");

  // Coupled Duration Preset / Text / Seconds
  const presetMap = {
    instantaneous: null,
    "1 round": 6,
    "1 minute": 60,
    "10 minutes": 600,
    "1 hour": 3600,
    "8 hours": 28800,
    "24 hours": 86400,
  };
  const durPresetEl = document.getElementById("sp-duration-preset");
  const durTextEl = document.getElementById("sp-duration-text");
  const durSecsEl = document.getElementById("sp-duration-seconds");

  durPresetEl?.addEventListener("change", () => {
    const val = durPresetEl.value;
    if (val === "__custom__") return;
    rec.duration = val;
    durTextEl.value = val;
    const secs = presetMap[val];
    if (secs === null || secs === undefined) {
      delete rec.duration_seconds;
      durSecsEl.value = "";
    } else {
      rec.duration_seconds = secs;
      durSecsEl.value = secs;
    }
    onWorkingRecordMutated(false);
  });

  durTextEl?.addEventListener("input", () => {
    rec.duration = durTextEl.value;
    const norm = durTextEl.value.trim().toLowerCase();
    if (norm in presetMap) {
      durPresetEl.value = norm;
      const secs = presetMap[norm];
      if (secs === null) {
        delete rec.duration_seconds;
        durSecsEl.value = "";
      } else {
        rec.duration_seconds = secs;
        durSecsEl.value = secs;
      }
    } else {
      durPresetEl.value = "__custom__";
    }
    onWorkingRecordMutated(false);
  });

  durSecsEl?.addEventListener("input", () => {
    const v = durSecsEl.value.trim();
    if (v === "") delete rec.duration_seconds;
    else rec.duration_seconds = parseInt(v, 10) || 0;
    onWorkingRecordMutated(false);
  });

  // Boolean Flags
  const bindFlag = (id, key) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.addEventListener("change", () => {
      if (el.checked) rec[key] = true;
      else if (key === "concentration" || key === "ritual") rec[key] = false;
      else delete rec[key];
      el.closest(".toggle-pill")?.classList.toggle("active", el.checked);
      onWorkingRecordMutated(false);
    });
  };
  bindFlag("sp-flag-concentration", "concentration");
  bindFlag("sp-flag-ritual", "ritual");
  bindFlag("sp-flag-sight", "requires_target_sight");
  bindFlag("sp-flag-cover", "ignore_cover_on_save");
  bindFlag("sp-repeat-save", "repeat_save");
  bindFlag("sp-end-target-dmg", "end_on_target_damage");
  bindFlag("sp-end-any-dmg", "end_on_any_damage");

  document.getElementById("sp-repeat-interval")?.addEventListener("input", (e) => {
    const v = e.target.value.trim();
    if (v === "") delete rec.repeat_save_interval_seconds;
    else rec.repeat_save_interval_seconds = parseInt(v, 10) || 6;
    onWorkingRecordMutated(false);
  });

  // V / S / M components
  document.querySelectorAll("[data-comp]").forEach((pill) => {
    pill.addEventListener("click", () => {
      const c = pill.dataset.comp;
      const arr = Array.isArray(rec.components) ? [...rec.components] : [];
      const idx = arr.indexOf(c);
      if (idx >= 0) arr.splice(idx, 1);
      else arr.push(c);
      rec.components = arr;
      pill.classList.toggle("active", arr.includes(c));
      onWorkingRecordMutated(false);
    });
  });

  // Pipeline Mode Switcher: Flat vs Ordered Steps (ADR-0019)
  document.getElementById("btn-mode-flat")?.addEventListener("click", () => {
    if (!Array.isArray(rec.steps)) return;
    const first = rec.steps[0] || {};
    delete rec.steps;
    rec.attack_type = first.attack_type || "none";
    if (first.save) rec.save = first.save;
    if (first.half_on_save !== undefined) rec.half_on_save = first.half_on_save;
    if (first.damage) rec.damage = first.damage;
    if (first.damage_type) rec.damage_type = first.damage_type;
    rec.effects = Array.isArray(first.effects) ? first.effects : [];
    onWorkingRecordMutated(true);
  });

  document.getElementById("btn-mode-steps")?.addEventListener("click", () => {
    if (Array.isArray(rec.steps)) return;
    const initialStep = {
      id: "step_1",
      type: rec.attack_type && rec.attack_type !== "none" ? "attack" : rec.save ? "save" : rec.damage ? "damage" : "effect",
      gate: "always",
      target: rec.target === "area" || rec.target === "cone" ? "area" : rec.target === "self" ? "self" : "target",
    };
    if (initialStep.type === "attack") initialStep.attack_type = rec.attack_type || "ranged_spell";
    if (initialStep.type === "save") {
      initialStep.save = rec.save || "DEX";
      initialStep.half_on_save = Boolean(rec.half_on_save);
    }
    if (rec.damage) {
      initialStep.damage = rec.damage;
      initialStep.damage_type = rec.damage_type || "force";
    }
    if (Array.isArray(rec.effects) && rec.effects.length > 0) {
      const nonArea = rec.effects.filter((e) => e && e.type !== "area_selection");
      if (nonArea.length > 0) initialStep.effects = nonArea;
    }
    delete rec.attack_type;
    delete rec.save;
    delete rec.half_on_save;
    delete rec.damage;
    delete rec.damage_type;
    rec.effects = [];
    rec.steps = [initialStep];
    onWorkingRecordMutated(true);
  });

  // Flat Delivery Controls
  document.getElementById("sp-attack-type")?.addEventListener("change", (e) => {
    rec.attack_type = e.target.value;
    onWorkingRecordMutated(false);
  });
  document.getElementById("sp-save")?.addEventListener("change", (e) => {
    if (!e.target.value) delete rec.save;
    else rec.save = e.target.value;
    onWorkingRecordMutated(false);
  });
  bindText("sp-damage", "damage", true);
  bindText("sp-damage-type", "damage_type", true);
  bindFlag("sp-half-save", "half_on_save");

  // Dice Policy & Result Multiplier
  const syncDicePolicy = () => {
    const maxV = parseInt(document.getElementById("sp-dp-max")?.value || "0", 10);
    const sidesV = parseInt(document.getElementById("sp-dp-sides")?.value || "0", 10);
    if (maxV > 0 && sidesV > 0) {
      rec.damage_dice_policy = { maximize: maxV, remove: 0, sides: sidesV };
    } else {
      delete rec.damage_dice_policy;
    }
    onWorkingRecordMutated(false);
  };
  document.getElementById("sp-dp-max")?.addEventListener("input", syncDicePolicy);
  document.getElementById("sp-dp-sides")?.addEventListener("change", syncDicePolicy);

  const syncMultiplier = () => {
    const num = parseInt(document.getElementById("sp-dm-num")?.value || "", 10);
    const den = parseInt(document.getElementById("sp-dm-den")?.value || "", 10);
    if (!isNaN(num) && !isNaN(den) && den > 0) {
      rec.damage_result_multiplier = { numerator: num, denominator: den, rounding: "floor" };
    } else {
      delete rec.damage_result_multiplier;
    }
    onWorkingRecordMutated(false);
  };
  document.getElementById("sp-dm-num")?.addEventListener("input", syncMultiplier);
  document.getElementById("sp-dm-den")?.addEventListener("input", syncMultiplier);

  // Ordered Steps Controls
  document.querySelectorAll("[data-add-step]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const stype = btn.dataset.addStep;
      if (!Array.isArray(rec.steps)) rec.steps = [];
      const nextNum = rec.steps.length + 1;
      const newStep = { id: `step_${nextNum}`, type: stype, gate: "always", target: "target" };
      if (stype === "attack") {
        newStep.attack_type = "ranged_spell";
        newStep.damage = "1d8";
        newStep.damage_type = "force";
      } else if (stype === "save") {
        newStep.save = "DEX";
        newStep.half_on_save = false;
        newStep.damage = "2d6";
        newStep.damage_type = "fire";
      } else if (stype === "damage") {
        newStep.damage = "1d6";
        newStep.damage_type = "force";
      } else if (stype === "effect") {
        newStep.effects = [{ type: "grant_condition", condition: "prone" }];
      }
      rec.steps.push(newStep);
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll("[data-step-del]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const idx = parseInt(btn.dataset.stepDel, 10);
      rec.steps.splice(idx, 1);
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll("[data-step-move]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const idx = parseInt(btn.dataset.idx, 10);
      const dir = parseInt(btn.dataset.stepMove, 10);
      const targetIdx = idx + dir;
      if (targetIdx < 0 || targetIdx >= rec.steps.length) return;
      const tmp = rec.steps[idx];
      rec.steps[idx] = rec.steps[targetIdx];
      rec.steps[targetIdx] = tmp;
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".step-field").forEach((el) => {
    const evt = el.tagName === "SELECT" ? "change" : "input";
    el.addEventListener(evt, () => {
      const idx = parseInt(el.dataset.idx, 10);
      const key = el.dataset.key;
      const val = el.value;
      const step = rec.steps[idx];
      if (!step) return;
      if (val === "") delete step[key];
      else step[key] = val;

      if (key === "type" || key === "target" || key === "shape") {
        if (key === "target" && val === "area" && !step.shape) {
          step.shape = "sphere";
          step.radius = 2;
        }
        onWorkingRecordMutated(true);
      } else {
        onWorkingRecordMutated(false);
      }
    });
  });

  document.querySelectorAll(".step-field-bool").forEach((el) => {
    el.addEventListener("change", () => {
      const idx = parseInt(el.dataset.idx, 10);
      const key = el.dataset.key;
      rec.steps[idx][key] = el.value === "true";
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".step-geom-hex").forEach((el) => {
    el.addEventListener("input", () => {
      const idx = parseInt(el.dataset.idx, 10);
      const gkey = el.dataset.gkey;
      const h = Math.max(1, parseInt(el.value || "1", 10));
      rec.steps[idx][gkey] = h;
      const ftEl = el.closest(".dual-unit-box")?.querySelector(".step-geom-feet");
      if (ftEl) ftEl.value = h * 5;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".step-geom-feet").forEach((el) => {
    el.addEventListener("input", () => {
      const idx = parseInt(el.dataset.idx, 10);
      const gkey = el.dataset.gkey;
      const f = Math.max(5, parseInt(el.value || "5", 10));
      const h = Math.max(1, Math.round(f / 5));
      rec.steps[idx][gkey] = h;
      const hexEl = el.closest(".dual-unit-box")?.querySelector(".step-geom-hex");
      if (hexEl) hexEl.value = h;
      onWorkingRecordMutated(false);
    });
  });

  // Effects Builder Controls (both root and step-<idx>)
  const getEffectArray = (scope) => {
    if (scope === "root") {
      if (!Array.isArray(rec.effects)) rec.effects = [];
      return rec.effects;
    }
    if (scope.startsWith("step-")) {
      const sIdx = parseInt(scope.split("-")[1], 10);
      if (!Array.isArray(rec.steps[sIdx].effects)) rec.steps[sIdx].effects = [];
      return rec.steps[sIdx].effects;
    }
    return [];
  };

  const makeDefaultEffect = (etype) => {
    if (etype === "heal" || etype === "temporary_hp") return { type: etype, value: "1d8" };
    if (etype === "grant_condition" || etype === "remove_condition")
      return { type: etype, condition: "blinded" };
    if (etype === "grant_source_benefits")
      return { type: "grant_source_benefits", benefits: [{ stat: "AC", amount: 2 }] };
    if (etype === "area_selection")
      return { type: "area_selection", shape: "sphere", radius: Number(rec.area_radius || 2) };
    return { type: etype };
  };

  document.querySelectorAll("[data-add-effect]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const arr = getEffectArray("root");
      arr.push(makeDefaultEffect(btn.dataset.addEffect));
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll("[data-add-step-eff]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const sIdx = btn.dataset.addStepEff;
      const arr = getEffectArray(`step-${sIdx}`);
      arr.push(makeDefaultEffect(btn.dataset.effType));
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll("[data-del-eff]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const arr = getEffectArray(btn.dataset.scope);
      arr.splice(parseInt(btn.dataset.delEff, 10), 1);
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".eff-type-select").forEach((el) => {
    el.addEventListener("change", () => {
      const arr = getEffectArray(el.dataset.scope);
      const idx = parseInt(el.dataset.idx, 10);
      arr[idx] = makeDefaultEffect(el.value);
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".eff-field").forEach((el) => {
    const evt = el.tagName === "SELECT" ? "change" : "input";
    el.addEventListener(evt, () => {
      const arr = getEffectArray(el.dataset.scope);
      const eff = arr[parseInt(el.dataset.idx, 10)];
      if (!eff) return;
      eff[el.dataset.key] = el.value;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".eff-field-bool").forEach((el) => {
    el.addEventListener("change", () => {
      const arr = getEffectArray(el.dataset.scope);
      const eff = arr[parseInt(el.dataset.idx, 10)];
      if (!eff) return;
      if (el.value === "true") eff[el.dataset.key] = true;
      else delete eff[el.dataset.key];
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".eff-gate-select").forEach((el) => {
    el.addEventListener("change", () => {
      const arr = getEffectArray(el.dataset.scope);
      const eff = arr[parseInt(el.dataset.idx, 10)];
      if (!eff) return;
      delete eff.on_spell_hit;
      delete eff.on_failed_save;
      if (el.value === "on_spell_hit") eff.on_spell_hit = true;
      if (el.value === "on_failed_save") eff.on_failed_save = true;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".eff-area-shape").forEach((el) => {
    el.addEventListener("change", () => {
      const arr = getEffectArray(el.dataset.scope);
      const eff = arr[parseInt(el.dataset.idx, 10)];
      if (!eff) return;
      const prevVal = eff.radius || eff.size || 2;
      delete eff.radius;
      delete eff.size;
      eff.shape = el.value;
      if (el.value === "sphere") eff.radius = prevVal;
      else eff.size = prevVal;
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".eff-area-hex").forEach((el) => {
    el.addEventListener("input", () => {
      const arr = getEffectArray(el.dataset.scope);
      const eff = arr[parseInt(el.dataset.idx, 10)];
      const h = Math.max(1, parseInt(el.value || "1", 10));
      eff[el.dataset.gkey] = h;
      const ft = el.closest(".dual-unit-box")?.querySelector(".eff-area-feet");
      if (ft) ft.value = h * 5;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".eff-area-feet").forEach((el) => {
    el.addEventListener("input", () => {
      const arr = getEffectArray(el.dataset.scope);
      const eff = arr[parseInt(el.dataset.idx, 10)];
      const f = Math.max(5, parseInt(el.value || "5", 10));
      const h = Math.max(1, Math.round(f / 5));
      eff[el.dataset.gkey] = h;
      const hx = el.closest(".dual-unit-box")?.querySelector(".eff-area-hex");
      if (hx) hx.value = h;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".eff-sb-stat").forEach((el) => {
    el.addEventListener("input", () => {
      const arr = getEffectArray(el.dataset.scope);
      const eff = arr[parseInt(el.dataset.idx, 10)];
      if (!eff) return;
      const box = el.closest(".subcard");
      const nextBenefits = [];
      box.querySelectorAll(".eff-sb-stat").forEach((inp) => {
        const amt = parseInt(inp.value || "0", 10);
        if (amt > 0) nextBenefits.push({ stat: inp.dataset.stat, amount: amt });
      });
      eff.benefits = nextBenefits;
      onWorkingRecordMutated(false);
    });
  });

  // Upcast & Cantrip Scaling
  const syncUpcast = () => {
    const nextUp = {};
    const strKeys = [
      ["sp-up-dmg", "damage_per_level"],
      ["sp-up-healdice", "healing_dice_per_level"],
    ];
    const intKeys = [
      ["sp-up-healflat", "healing_per_level"],
      ["sp-up-thp", "temporary_hp_per_level"],
      ["sp-up-targets", "additional_targets_per_level"],
    ];
    for (const [id, k] of strKeys) {
      const v = document.getElementById(id)?.value.trim();
      if (v) nextUp[k] = v;
    }
    for (const [id, k] of intKeys) {
      const v = document.getElementById(id)?.value.trim();
      if (v !== "" && v !== undefined) nextUp[k] = parseInt(v, 10) || 0;
    }
    if (Object.keys(nextUp).length > 0) rec.upcast = nextUp;
    else delete rec.upcast;
    onWorkingRecordMutated(false);
  };
  ["sp-up-dmg", "sp-up-healdice", "sp-up-healflat", "sp-up-thp", "sp-up-targets"].forEach((id) =>
    document.getElementById(id)?.addEventListener("input", syncUpcast)
  );

  const syncScaling = () => {
    const nextSc = {};
    for (const lvl of ["5", "11", "17"]) {
      const v = document.getElementById(`sp-scale-${lvl}`)?.value.trim();
      if (v) nextSc[lvl] = v;
    }
    if (Object.keys(nextSc).length > 0) rec.scaling = nextSc;
    else delete rec.scaling;
    onWorkingRecordMutated(false);
  };
  ["sp-scale-5", "sp-scale-11", "sp-scale-17"].forEach((id) =>
    document.getElementById(id)?.addEventListener("input", syncScaling)
  );

  // Repeat Save Stages & Source-End Rules
  document.getElementById("btn-add-repeat-stage")?.addEventListener("click", () => {
    rec.repeat_save = true;
    if (!Array.isArray(rec.repeat_save_stages)) rec.repeat_save_stages = [];
    rec.repeat_save_stages.push({
      condition: "restrained",
      successes_required: 1,
      on_failure: "stay",
      minimum_margin: 0,
    });
    onWorkingRecordMutated(true);
  });

  document.querySelectorAll("[data-del-stage]").forEach((btn) => {
    btn.addEventListener("click", () => {
      rec.repeat_save_stages.splice(parseInt(btn.dataset.delStage, 10), 1);
      if (rec.repeat_save_stages.length === 0) delete rec.repeat_save_stages;
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".stage-field").forEach((el) => {
    el.addEventListener("change", () => {
      rec.repeat_save_stages[parseInt(el.dataset.idx, 10)][el.dataset.key] = el.value;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".stage-field-int").forEach((el) => {
    el.addEventListener("input", () => {
      rec.repeat_save_stages[parseInt(el.dataset.idx, 10)][el.dataset.key] =
        parseInt(el.value || "0", 10);
      onWorkingRecordMutated(false);
    });
  });

  document.getElementById("btn-add-end-rule")?.addEventListener("click", () => {
    if (!Array.isArray(rec.source_end_rules)) rec.source_end_rules = [];
    rec.source_end_rules.push({
      event: "damage",
      actor: "recipient",
      except_source_id: "this_source",
    });
    onWorkingRecordMutated(true);
  });

  document.querySelectorAll("[data-del-endrule]").forEach((btn) => {
    btn.addEventListener("click", () => {
      rec.source_end_rules.splice(parseInt(btn.dataset.delEndrule, 10), 1);
      if (rec.source_end_rules.length === 0) delete rec.source_end_rules;
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".endrule-field").forEach((el) => {
    el.addEventListener("change", () => {
      rec.source_end_rules[parseInt(el.dataset.idx, 10)][el.dataset.key] = el.value;
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".endrule-filter").forEach((el) => {
    el.addEventListener("input", () => {
      const rule = rec.source_end_rules[parseInt(el.dataset.idx, 10)];
      const val = el.value.trim();
      delete rule.except_source_id;
      delete rule.status;
      delete rule.school;
      if (val) {
        if (rule.event === "damage") rule.except_source_id = val;
        else if (rule.event === "status") rule.status = val;
        else if (rule.event === "cast") rule.school = val;
      }
      onWorkingRecordMutated(false);
    });
  });

  // Composable Class Spell Lists
  document.querySelectorAll("#sp-class-pills [data-cls]").forEach((pill) => {
    pill.addEventListener("click", () => {
      const cls = pill.dataset.cls;
      const arr = Array.isArray(rec.classes) ? [...rec.classes] : [];
      const i = arr.indexOf(cls);
      if (i >= 0) arr.splice(i, 1);
      else arr.push(cls);
      rec.classes = arr;
      pill.classList.toggle("active", arr.includes(cls));
      onWorkingRecordMutated(false);
    });
  });
}

/* ============================================================================
 * ITEM WORKBENCH — Visual Builders (Weapons, Armor, Source Benefits, Wands)
 * ========================================================================== */

function buildItemWorkbenchHTML(rec, diag) {
  const ic = state.contract.item;
  const classes = state.contract.classes;
  const abilities = state.contract.abilities;
  const damageTypes = state.contract.damage_types;
  const itype = rec.type || "weapon";
  const props = Array.isArray(rec.properties) ? rec.properties : [];
  const startClasses = Array.isArray(rec.starting_equipment_classes)
    ? rec.starting_equipment_classes
    : [];
  const sBenefits = Array.isArray(rec.source_benefits) ? rec.source_benefits : [];
  const acBen = sBenefits.find((b) => b.stat === "AC");
  const spdBen = sBenefits.find((b) => b.stat === "speed");
  const perms = Array.isArray(rec.spell_permissions) ? rec.spell_permissions : [];
  const itemEffects = Array.isArray(rec.effects) ? rec.effects : [];
  const rngHex = Number(rec.range ?? 1);

  return `
    ${
      diag.errors && diag.errors.length > 0
        ? `
      <div class="callout-banner callout-danger">
        <div class="callout-text">
          <h4>✕ Item Contract Validation Errors (${diag.errors.length})</h4>
          <p>${esc(diag.errors[0])}</p>
        </div>
      </div>
    `
        : ""
    }

    <!-- CARD 1: Item Identity & Classification -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">I. Item Identity & Classification</span>
        <span class="grimoire-card-subtitle">Validated against <code>DataLoader.ALLOWED_ITEM_TYPES</code></span>
      </div>
      <div class="grimoire-card-body">
        <div class="field-grid-4">
          <div class="field-group" style="grid-column: span 2;">
            <label class="field-label">Display Name</label>
            <input type="text" id="it-name" value="${esc(rec.name || "")}" />
          </div>
          <div class="field-group">
            <label class="field-label">Item Type (<code>type</code>)</label>
            <select id="it-type">
              ${ic.allowed_types
                .map((t) => `<option value="${esc(t)}" ${itype === t ? "selected" : ""}>${esc(t)}</option>`)
                .join("")}
            </select>
          </div>
          <div class="field-group">
            <label class="field-label">Rarity</label>
            <select id="it-rarity">
              ${ic.rarities
                .map(
                  (r) =>
                    `<option value="${esc(r)}" ${(rec.rarity || "standard") === r ? "selected" : ""}>${esc(r)}</option>`
                )
                .join("")}
            </select>
          </div>
        </div>

        <div class="field-grid-4">
          <div class="field-group">
            <label class="field-label">Gold Value (gp)</label>
            <input type="number" id="it-value" min="0" max="1000000" value="${esc(rec.value ?? 0)}" />
          </div>
          <div class="field-group">
            <label class="field-label">Weight (lb)</label>
            <input type="number" id="it-weight" min="0" max="500" step="0.1" value="${esc(rec.weight ?? 0)}" />
          </div>
          <div class="field-group" style="grid-column: span 2;">
            <label class="field-label">Description</label>
            <input type="text" id="it-description" value="${esc(rec.description || "")}" />
          </div>
        </div>
      </div>
    </div>

    <!-- CARD 2: Contextual Combat Stats (Weapon or Armor/Shield) -->
    ${
      itype === "weapon"
        ? `
      <div class="grimoire-card">
        <div class="grimoire-card-header">
          <span class="grimoire-card-title">II. Weapon Combat Profile & Properties</span>
          <span class="grimoire-card-subtitle">1 Hex = 5 Feet</span>
        </div>
        <div class="grimoire-card-body">
          <div class="field-grid-4">
            <div class="field-group">
              <label class="field-label">Weapon Category</label>
              <select id="it-weapon-type">
                ${ic.weapon_types
                  .map(
                    (wt) =>
                      `<option value="${esc(wt)}" ${(rec.weapon_type || "simple_melee") === wt ? "selected" : ""}>${esc(wt)}</option>`
                  )
                  .join("")}
              </select>
            </div>
            <div class="field-group">
              <label class="field-label">Attack Ability</label>
              <select id="it-ability">
                ${abilities
                  .map(
                    (ab) => `<option value="${esc(ab)}" ${(rec.ability || "STR") === ab ? "selected" : ""}>${esc(ab)}</option>`
                  )
                  .join("")}
              </select>
            </div>
            <div class="field-group">
              <label class="field-label">Damage Dice</label>
              <input type="text" id="it-damage" class="mono-input" value="${esc(rec.damage || "1d8")}" />
            </div>
            <div class="field-group">
              <label class="field-label">Damage Type</label>
              <select id="it-damage-type">
                ${damageTypes
                  .map(
                    (dt) =>
                      `<option value="${esc(dt)}" ${(rec.damage_type || "slashing") === dt ? "selected" : ""}>${esc(dt)}</option>`
                  )
                  .join("")}
              </select>
            </div>
          </div>

          <div class="field-grid-2">
            <div class="field-group">
              <label class="field-label">Weapon Reach / Range (Hexes ↔ Feet)</label>
              <div class="dual-unit-box">
                <div class="dual-unit-col">
                  <span class="dual-unit-tag">Hexes</span>
                  <input type="number" id="it-range-hex" min="1" max="120" value="${rngHex}" />
                </div>
                <span class="dual-unit-sep">⇄</span>
                <div class="dual-unit-col">
                  <span class="dual-unit-tag">Feet</span>
                  <input type="number" id="it-range-feet" min="5" max="600" step="5" value="${rngHex * 5}" />
                </div>
              </div>
            </div>
            <div class="field-group">
              <label class="field-label">Weapon Properties</label>
              <div class="pill-group" id="it-prop-pills">
                ${ic.weapon_properties
                  .map(
                    (p) => `
                  <label class="toggle-pill ${props.includes(p) ? "active" : ""}" data-wprop="${esc(p)}">
                    <span>${esc(p)}</span>
                  </label>
                `
                  )
                  .join("")}
              </div>
            </div>
          </div>
        </div>
      </div>
    `
        : ""
    }

    ${
      itype === "armor" || itype === "shield"
        ? `
      <div class="grimoire-card">
        <div class="grimoire-card-header">
          <span class="grimoire-card-title">II. Armor & Shield Defense Profile</span>
        </div>
        <div class="grimoire-card-body">
          <div class="field-grid-4">
            <div class="field-group">
              <label class="field-label">Armor Category</label>
              <select id="it-armor-type">
                ${ic.armor_types
                  .map(
                    (at) => `<option value="${esc(at)}" ${(rec.armor_type || "light") === at ? "selected" : ""}>${esc(at)}</option>`
                  )
                  .join("")}
              </select>
            </div>
            <div class="field-group">
              <label class="field-label">Base Armor Class / Bonus</label>
              <input type="number" id="it-armor-class" min="1" max="30" value="${esc(rec.armor_class ?? 12)}" />
            </div>
            <div class="field-group">
              <label class="field-label">DEX Bonus Cap</label>
              <input type="number" id="it-dex-cap" min="0" max="10" value="${esc(rec.dex_cap ?? "")}" placeholder="Uncapped" />
            </div>
            <div class="field-group">
              <label class="field-label">Stealth Disadvantage</label>
              <label class="toggle-pill ${rec.stealth_disadvantage ? "active" : ""}" style="width:fit-content;">
                <input type="checkbox" id="it-stealth-dis" ${rec.stealth_disadvantage ? "checked" : ""} hidden />
                <span>Disadvantage on Stealth</span>
              </label>
            </div>
          </div>
        </div>
      </div>
    `
        : ""
    }

    <!-- CARD 3: Batch L Source Benefits Carrier -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">III. Passive Source Benefits Carrier (<code>source_benefits</code> · Batch L)</span>
        <span class="grimoire-card-subtitle">Supported on weapon, armor, shield, ring, wand</span>
      </div>
      <div class="grimoire-card-body">
        <div class="field-grid-2">
          <div class="field-group">
            <label class="field-label">Equipped Armor Class Bonus (<code>stat: "AC"</code>, 0–10)</label>
            <input type="number" id="it-sb-ac" min="0" max="10" value="${esc(acBen?.amount ?? 0)}" />
          </div>
          <div class="field-group">
            <label class="field-label">
              <span>Equipped Walking Speed Bonus (<code>stat: "speed"</code> in Hexes)</span>
              <span class="field-hint" id="it-sb-speed-hint">+${(spdBen?.amount ?? 0) * 5} ft</span>
            </label>
            <input type="number" id="it-sb-speed" min="0" max="10" value="${esc(spdBen?.amount ?? 0)}" />
          </div>
        </div>
      </div>
    </div>

    <!-- CARD 4: Batch 021 Spell Permissions & Wand Charges -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">IV. Granted Spell Permissions & Wand Charges (<code>spell_permissions</code> · Batch 021)</span>
        <button type="button" class="btn btn-sm btn-gold" id="btn-add-item-perm">+ Add Permission Block</button>
      </div>
      <div class="grimoire-card-body">
        <div class="builder-stack">
          ${
            perms.length === 0
              ? `<div class="empty-builder-state">No spell_permissions blocks on this item.</div>`
              : perms
                  .map(
                    (p, idx) => `
                <div class="subcard">
                  <div class="subcard-header">
                    <span class="subcard-title">Spell Permission Block ${idx + 1}</span>
                    <button type="button" class="btn btn-sm btn-danger" data-del-perm="${idx}">✕</button>
                  </div>
                  <div class="field-grid-4">
                    <div class="field-group" style="grid-column: span 2;">
                      <label class="field-label">Granted Spell IDs (comma-separated)</label>
                      <input type="text" class="mono-input perm-spells" data-idx="${idx}" value="${esc((p.spells || []).join(", "))}" placeholder="e.g. magic_missile, shield" />
                    </div>
                    <div class="field-group">
                      <label class="field-label">Casting Ability</label>
                      <select class="perm-field" data-idx="${idx}" data-key="ability">
                        <option value="">Default</option>
                        ${abilities
                          .map((ab) => `<option value="${esc(ab)}" ${p.ability === ab ? "selected" : ""}>${esc(ab)}</option>`)
                          .join("")}
                      </select>
                    </div>
                    <div class="field-group">
                      <label class="field-label">Charges / Max Charges</label>
                      <div style="display:flex; gap:4px;">
                        <input type="number" class="perm-int" data-idx="${idx}" data-key="charges" min="1" max="100" placeholder="Charges" value="${esc(p.charges ?? "")}" />
                        <input type="number" class="perm-int" data-idx="${idx}" data-key="maximum_charges" min="1" max="100" placeholder="Max" value="${esc(p.maximum_charges ?? "")}" />
                      </div>
                    </div>
                  </div>
                </div>
              `
                  )
                  .join("")
          }
        </div>
      </div>
    </div>

    <!-- CARD 5: Consumable & Tool Effects -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">V. Consumable & Tool Item Effects (<code>effects</code>)</span>
        <div class="pill-group">
          <button type="button" class="btn btn-sm btn-gold" data-add-iteff="heal">+ Heal</button>
          <button type="button" class="btn btn-sm btn-gold" data-add-iteff="remove_condition">+ Cure Condition</button>
          <button type="button" class="btn btn-sm" data-add-iteff="skill_bonus">+ Skill Bonus</button>
          <button type="button" class="btn btn-sm" data-add-iteff="spellcasting_focus">+ Arcane Focus</button>
        </div>
      </div>
      <div class="grimoire-card-body">
        <div class="builder-stack">
          ${
            itemEffects.length === 0
              ? `<div class="empty-builder-state">No item effects defined.</div>`
              : itemEffects
                  .map(
                    (ef, idx) => `
                <div class="subcard">
                  <div class="subcard-header">
                    <div class="subcard-title">
                      <select class="iteff-type" data-idx="${idx}" style="width:auto; font-weight:700;">
                        ${ic.supported_item_effect_types
                          .map((t) => `<option value="${esc(t)}" ${ef.type === t ? "selected" : ""}>${esc(t)}</option>`)
                          .join("")}
                      </select>
                    </div>
                    <button type="button" class="btn btn-sm btn-danger" data-del-iteff="${idx}">✕</button>
                  </div>
                  <div class="field-grid-2">
                    <div class="field-group">
                      <label class="field-label">Value / Formula / Bonus</label>
                      <input type="text" class="mono-input iteff-val" data-idx="${idx}" value="${esc(ef.value ?? ef.bonus ?? "")}" placeholder="e.g. 2d4+2 or 1" />
                    </div>
                    <div class="field-group">
                      <label class="field-label">Condition or Skill Name (if applicable)</label>
                      <input type="text" class="mono-input iteff-cond" data-idx="${idx}" value="${esc(ef.condition ?? ef.skill ?? "")}" placeholder="e.g. poisoned or Stealth" />
                    </div>
                  </div>
                </div>
              `
                  )
                  .join("")
          }
        </div>
      </div>
    </div>

    <!-- CARD 6: Composable Starting Equipment Additions -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">VI. Composable Starting Equipment Additions (<code>pack.json -> starting_equipment_additions</code>)</span>
        <span class="grimoire-card-subtitle">Grants this item at character creation without overwriting class JSON files</span>
      </div>
      <div class="grimoire-card-body">
        <div class="pill-group" id="it-class-pills">
          ${classes
            .map(
              (cls) => `
            <label class="toggle-pill ${startClasses.includes(cls) ? "active" : ""}" data-itcls="${esc(cls)}">
              <span>${esc(cls.charAt(0).toUpperCase() + cls.slice(1))}</span>
            </label>
          `
            )
            .join("")}
        </div>
      </div>
    </div>
  `;
}

function bindItemWorkbenchEvents() {
  const rec = state.workingRecord;
  if (!rec) return;

  document.getElementById("it-name")?.addEventListener("input", (e) => {
    rec.name = e.target.value;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-type")?.addEventListener("change", (e) => {
    rec.type = e.target.value;
    onWorkingRecordMutated(true);
  });
  document.getElementById("it-rarity")?.addEventListener("change", (e) => {
    rec.rarity = e.target.value;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-value")?.addEventListener("input", (e) => {
    rec.value = parseInt(e.target.value || "0", 10) || 0;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-weight")?.addEventListener("input", (e) => {
    rec.weight = parseFloat(e.target.value || "0") || 0;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-description")?.addEventListener("input", (e) => {
    rec.description = e.target.value;
    onWorkingRecordMutated(false);
  });

  // Weapon fields
  document.getElementById("it-weapon-type")?.addEventListener("change", (e) => {
    rec.weapon_type = e.target.value;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-ability")?.addEventListener("change", (e) => {
    rec.ability = e.target.value;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-damage")?.addEventListener("input", (e) => {
    rec.damage = e.target.value;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-damage-type")?.addEventListener("change", (e) => {
    rec.damage_type = e.target.value;
    onWorkingRecordMutated(false);
  });

  const rngHexEl = document.getElementById("it-range-hex");
  const rngFtEl = document.getElementById("it-range-feet");
  rngHexEl?.addEventListener("input", () => {
    const h = Math.max(1, parseInt(rngHexEl.value || "1", 10));
    rec.range = h;
    if (rngFtEl) rngFtEl.value = h * 5;
    onWorkingRecordMutated(false);
  });
  rngFtEl?.addEventListener("input", () => {
    const f = Math.max(5, parseInt(rngFtEl.value || "5", 10));
    const h = Math.max(1, Math.round(f / 5));
    rec.range = h;
    if (rngHexEl) rngHexEl.value = h;
    onWorkingRecordMutated(false);
  });

  document.querySelectorAll("#it-prop-pills [data-wprop]").forEach((pill) => {
    pill.addEventListener("click", () => {
      const p = pill.dataset.wprop;
      const arr = Array.isArray(rec.properties) ? [...rec.properties] : [];
      const i = arr.indexOf(p);
      if (i >= 0) arr.splice(i, 1);
      else arr.push(p);
      rec.properties = arr;
      pill.classList.toggle("active", arr.includes(p));
      onWorkingRecordMutated(false);
    });
  });

  // Armor fields
  document.getElementById("it-armor-type")?.addEventListener("change", (e) => {
    rec.armor_type = e.target.value;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-armor-class")?.addEventListener("input", (e) => {
    rec.armor_class = parseInt(e.target.value || "10", 10) || 10;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-dex-cap")?.addEventListener("input", (e) => {
    const v = e.target.value.trim();
    if (v === "") delete rec.dex_cap;
    else rec.dex_cap = parseInt(v, 10) || 0;
    onWorkingRecordMutated(false);
  });
  document.getElementById("it-stealth-dis")?.addEventListener("change", (e) => {
    rec.stealth_disadvantage = e.target.checked;
    e.target.closest(".toggle-pill")?.classList.toggle("active", e.target.checked);
    onWorkingRecordMutated(false);
  });

  // Source benefits
  const syncSourceBenefits = () => {
    const acVal = parseInt(document.getElementById("it-sb-ac")?.value || "0", 10) || 0;
    const spdVal = parseInt(document.getElementById("it-sb-speed")?.value || "0", 10) || 0;
    const hintEl = document.getElementById("it-sb-speed-hint");
    if (hintEl) hintEl.textContent = `+${spdVal * 5} ft`;
    const next = [];
    if (acVal > 0) next.push({ stat: "AC", amount: acVal });
    if (spdVal > 0) next.push({ stat: "speed", amount: spdVal });
    if (next.length > 0) rec.source_benefits = next;
    else delete rec.source_benefits;
    onWorkingRecordMutated(false);
  };
  document.getElementById("it-sb-ac")?.addEventListener("input", syncSourceBenefits);
  document.getElementById("it-sb-speed")?.addEventListener("input", syncSourceBenefits);

  // Spell permissions
  document.getElementById("btn-add-item-perm")?.addEventListener("click", () => {
    if (!Array.isArray(rec.spell_permissions)) rec.spell_permissions = [];
    rec.spell_permissions.push({
      spells: ["magic_missile"],
      ability: "INT",
      charges: 3,
      maximum_charges: 3,
    });
    onWorkingRecordMutated(true);
  });

  document.querySelectorAll("[data-del-perm]").forEach((btn) => {
    btn.addEventListener("click", () => {
      rec.spell_permissions.splice(parseInt(btn.dataset.delPerm, 10), 1);
      if (rec.spell_permissions.length === 0) delete rec.spell_permissions;
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".perm-spells").forEach((el) => {
    el.addEventListener("input", () => {
      const idx = parseInt(el.dataset.idx, 10);
      rec.spell_permissions[idx].spells = el.value
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".perm-field").forEach((el) => {
    el.addEventListener("change", () => {
      const idx = parseInt(el.dataset.idx, 10);
      if (!el.value) delete rec.spell_permissions[idx][el.dataset.key];
      else rec.spell_permissions[idx][el.dataset.key] = el.value;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".perm-int").forEach((el) => {
    el.addEventListener("input", () => {
      const idx = parseInt(el.dataset.idx, 10);
      const v = el.value.trim();
      if (v === "") delete rec.spell_permissions[idx][el.dataset.key];
      else rec.spell_permissions[idx][el.dataset.key] = parseInt(v, 10) || 1;
      onWorkingRecordMutated(false);
    });
  });

  // Item effects
  document.querySelectorAll("[data-add-iteff]").forEach((btn) => {
    btn.addEventListener("click", () => {
      if (!Array.isArray(rec.effects)) rec.effects = [];
      const t = btn.dataset.addIteff;
      if (t === "heal") rec.effects.push({ type: "heal", value: "2d4+2" });
      else if (t === "remove_condition")
        rec.effects.push({ type: "remove_condition", condition: "poisoned" });
      else if (t === "skill_bonus") rec.effects.push({ type: "skill_bonus", skill: "Stealth", bonus: 2 });
      else rec.effects.push({ type: t });
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll("[data-del-iteff]").forEach((btn) => {
    btn.addEventListener("click", () => {
      rec.effects.splice(parseInt(btn.dataset.delIteff, 10), 1);
      if (rec.effects.length === 0) delete rec.effects;
      onWorkingRecordMutated(true);
    });
  });

  document.querySelectorAll(".iteff-type").forEach((el) => {
    el.addEventListener("change", () => {
      rec.effects[parseInt(el.dataset.idx, 10)].type = el.value;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".iteff-val").forEach((el) => {
    el.addEventListener("input", () => {
      const ef = rec.effects[parseInt(el.dataset.idx, 10)];
      const v = el.value.trim();
      if (ef.type === "skill_bonus") ef.bonus = parseInt(v || "0", 10) || 0;
      else ef.value = v;
      onWorkingRecordMutated(false);
    });
  });

  document.querySelectorAll(".iteff-cond").forEach((el) => {
    el.addEventListener("input", () => {
      const ef = rec.effects[parseInt(el.dataset.idx, 10)];
      const v = el.value.trim();
      if (ef.type === "skill_bonus") ef.skill = v;
      else ef.condition = v;
      onWorkingRecordMutated(false);
    });
  });

  // Starting equipment classes
  document.querySelectorAll("#it-class-pills [data-itcls]").forEach((pill) => {
    pill.addEventListener("click", () => {
      const cls = pill.dataset.itcls;
      const arr = Array.isArray(rec.starting_equipment_classes)
        ? [...rec.starting_equipment_classes]
        : [];
      const i = arr.indexOf(cls);
      if (i >= 0) arr.splice(i, 1);
      else arr.push(cls);
      rec.starting_equipment_classes = arr;
      pill.classList.toggle("active", arr.includes(cls));
      onWorkingRecordMutated(false);
    });
  });
}

/* ============================================================================
 * CLASS 2024 SRD 5.2.1 / XPHB PROGRESSION COMPARATOR
 * ========================================================================== */

function buildClassComparisonHTML(comp, rawRec) {
  if (!comp) {
    return buildReadOnlyReferenceHTML(rawRec);
  }
  const sb = comp.curated_spell_breakdown || {};
  return `
    <!-- Class Summary Overview -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">❖ ${esc(comp.name)} — 2024 SRD 5.2.1 vs Engine Core Progression Audit</span>
        <span class="grimoire-card-subtitle">${esc(comp.reference_path || "No 2024 reference file")}</span>
      </div>
      <div class="grimoire-card-body">
        <div class="field-grid-4">
          <div class="subcard">
            <span class="field-hint">Hit Die & Primary</span>
            <strong style="font-size:15px; color:var(--accent-primary-bright);">${esc(comp.hit_die)} · ${esc(comp.primary_ability)}</strong>
            <span style="font-size:11px; color:var(--text-muted);">Saves: ${esc((comp.saving_throw_proficiencies || []).join(", "))}</span>
          </div>
          <div class="subcard">
            <span class="field-hint">Core Engine Features (Lv 1–20)</span>
            <strong style="font-size:15px; color:var(--state-success);">${comp.core_enabled_features} Active</strong>
            <span style="font-size:11px; color:var(--state-warning);">${comp.core_quarantined_features} Quarantined / Effectless</span>
          </div>
          <div class="subcard">
            <span class="field-hint">Curated Class Spell List (${comp.curated_spell_count})</span>
            <div style="display:flex; gap:6px; flex-wrap:wrap; margin-top:4px;">
              ${renderShortStatusBadge("shared-ready")} <span>${sb["shared-ready"] || 0}</span>
              ${renderShortStatusBadge("native-id-bound")} <span>${sb["native-id-bound"] || 0}</span>
              ${renderShortStatusBadge("draft-unsupported")} <span>${sb["draft-unsupported"] || 0}</span>
            </div>
          </div>
          <div class="subcard">
            <span class="field-hint">Active Pack (<code>${esc(state.packId)}</code>) Additions</span>
            <div style="font-size:11.5px;">
              <div><strong>+${(comp.pack_spell_additions || []).length}</strong> spells: <code>${esc((comp.pack_spell_additions || []).join(", ") || "none")}</code></div>
              <div><strong>+${(comp.pack_equipment_additions || []).length}</strong> items: <code>${esc((comp.pack_equipment_additions || []).join(", ") || "none")}</code></div>
            </div>
          </div>
        </div>

        ${
          comp.reference_subclasses && comp.reference_subclasses.length > 0
            ? `
          <div>
            <div class="field-label" style="margin-bottom:6px;">2024 Reference Subclasses (<code>reference/2024/classes/${esc(comp.id)}.json</code>)</div>
            <div class="pill-group">
              ${comp.reference_subclasses
                .map(
                  (sc) => `
                <span class="toggle-pill ${sc.srd52 ? "active" : ""}">
                  <span>${esc(sc.name)}</span>
                  <span class="origin-tag">${sc.srd52 ? "SRD 5.2.1" : esc(sc.source)}</span>
                </span>
              `
                )
                .join("")}
            </div>
          </div>
        `
            : ""
        }
      </div>
    </div>

    <!-- Level 1-20 Side-by-Side Matrix -->
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">Level 1–20 Feature Parity Matrix</span>
        <span class="grimoire-card-subtitle">Left: <code>data/core/classes/${esc(comp.id)}.json</code> · Right: <code>reference/2024/classes/${esc(comp.id)}.json</code></span>
      </div>
      <div class="grimoire-card-body" style="padding:0;">
        <table class="level-matrix-table">
          <thead>
            <tr>
              <th style="width:52px; text-align:center;">Lvl</th>
              <th style="width:45%;">Engine Core (<code>data/core/classes/</code>)</th>
              <th style="width:50%;">2024 Reference Authority (<code>reference/2024/</code>)</th>
            </tr>
          </thead>
          <tbody>
            ${(comp.levels || [])
              .map(
                (row) => `
              <tr>
                <td class="level-num-cell">${row.level}</td>
                <td>
                  ${
                    row.core_features.length === 0
                      ? `<span style="color:var(--text-dim); font-size:11px;">—</span>`
                      : row.core_features
                          .map(
                            (cf) => `
                        <div class="feature-chip">
                          <div style="display:flex; justify-content:space-between; align-items:center; gap:6px;">
                            <strong>${esc(cf.name)}</strong>
                            ${
                              cf.support_state === "enabled"
                                ? `<span class="status-badge status-shared-ready">Enabled (${cf.effect_types.length} effect${cf.effect_types.length === 1 ? "" : "s"})</span>`
                                : `<span class="status-badge status-native-id-bound">Quarantined / No Effects</span>`
                            }
                          </div>
                          <div style="font-size:11px; color:var(--text-muted); margin-top:3px;">${esc(cf.description)}</div>
                          ${
                            cf.effect_types.length > 0
                              ? `<div style="margin-top:4px; font-family:var(--font-mono); font-size:10px; color:var(--accent-secondary);">ops: ${esc(cf.effect_types.join(", "))}</div>`
                              : ""
                          }
                        </div>
                      `
                          )
                          .join("")
                  }
                </td>
                <td>
                  ${
                    row.reference_features.length === 0
                      ? `<span style="color:var(--text-dim); font-size:11px;">—</span>`
                      : row.reference_features
                          .map(
                            (rf) => `
                        <details class="feature-chip">
                          <summary style="cursor:pointer; font-weight:600; display:flex; justify-content:space-between; align-items:center;">
                            <span>${esc(rf.name)}</span>
                            <span class="origin-tag">${rf.srd52 ? "SRD 5.2" : esc(rf.source)}</span>
                          </summary>
                          <div style="margin-top:6px; font-size:11.5px; color:var(--text-secondary); display:flex; flex-direction:column; gap:5px;">
                            ${(rf.paragraphs || []).map((p) => `<div>${esc(p)}</div>`).join("")}
                          </div>
                        </details>
                      `
                          )
                          .join("")
                  }
                </td>
              </tr>
            `
              )
              .join("")}
          </tbody>
        </table>
      </div>
    </div>
  `;
}

function buildReadOnlyReferenceHTML(rec) {
  return `
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">Staged Catalog Record (Read-Only Reference)</span>
      </div>
      <div class="grimoire-card-body">
        <pre class="code-viewer">${esc(JSON.stringify(rec, null, 2))}</pre>
      </div>
    </div>
  `;
}

/* ============================================================================
 * RIGHT PANE INSPECTOR (4 Tabs: VS-83 Check, Source Diff, pack.json, Raw/Meta)
 * ========================================================================== */

function renderInspectorPane() {
  const bodyEl = document.getElementById("inspector-body");
  const payload = state.activeEntryPayload;
  const rec = state.workingRecord;

  if (!payload || !rec) {
    bodyEl.innerHTML = `<div class="empty-builder-state">Select a record to inspect VS-83 contract diagnostics, source diffs, and pack manifests.</div>`;
    return;
  }

  if (state.inspectorTab === "diagnostics") {
    bodyEl.innerHTML = renderDiagnosticsTabHTML(payload.diagnostics, payload.candidate_preview);
  } else if (state.inspectorTab === "diff") {
    bodyEl.innerHTML = renderDiffTabHTML(payload.catalog_entry, payload.field_diff || []);
  } else if (state.inspectorTab === "manifest") {
    bodyEl.innerHTML = renderManifestTabHTML(state.packManifestPreview);
  } else if (state.inspectorTab === "json") {
    bodyEl.innerHTML = renderJsonTabHTML(rec, payload.candidate_preview);
    bindJsonTabEvents();
  }
}

function renderDiagnosticsTabHTML(diag, candidatePreview) {
  if (!diag) return "";
  const errors = diag.errors || [];
  const unitWarns = diag.unit_warnings || [];
  const warns = diag.warnings || [];
  const unknowns = diag.unknown_fields || [];
  const metaParked = candidatePreview?._editor_meta;

  return `
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">Live VS-83 Contract Verdict</span>
        ${renderShortStatusBadge(diag.status)}
      </div>
      <div class="grimoire-card-body">
        <div style="font-size:12px; font-weight:600;">${esc(diag.status_label)}</div>
        ${
          errors.length === 0 && unitWarns.length === 0
            ? `<div class="diag-item diag-ok">✓ Passes all pinned VS-83 structural & contract rules.</div>`
            : ""
        }
        ${errors.map((e) => `<div class="diag-item diag-error">✕ ${esc(e)}</div>`).join("")}
        ${unitWarns.map((u) => `<div class="diag-item diag-warn">📐 Unit Check: ${esc(u)}</div>`).join("")}
        ${warns.map((w) => `<div class="diag-item diag-warn">⚠ ${esc(w)}</div>`).join("")}
      </div>
    </div>

    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">Unknown Field Parking (<code>_editor_meta</code>)</span>
      </div>
      <div class="grimoire-card-body">
        ${
          unknowns.length === 0 && !metaParked
            ? `<div style="font-size:11.5px; color:var(--text-muted);">No non-contract fields present on this record.</div>`
            : `
          <div style="font-size:11.5px; color:var(--text-secondary);">
            In <strong>Draft Lossless</strong> mode, these fields stay in place. In <strong>Game Pack Candidate</strong> mode, they are automatically parked under <code>_editor_meta</code> so <code>SharedSpell</code> accepts the record without data loss:
          </div>
          <pre class="code-viewer">${esc(JSON.stringify(metaParked || unknowns, null, 2))}</pre>
        `
        }
      </div>
    </div>
  `;
}

function renderDiffTabHTML(cat, diffRows) {
  const modifiedRows = diffRows.filter((r) => r.state !== "unchanged");
  const rowsToShow = modifiedRows.length > 0 ? diffRows : diffRows.slice(0, 25);

  return `
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">Provenance & Manifest Deduplication</span>
      </div>
      <div class="grimoire-card-body" style="font-size:11.5px;">
        ${
          cat
            ? `
          <div><strong>Winner:</strong> <code>${esc(cat.winner_coord)}</code></div>
          <div><strong>Replaced Sources:</strong> ${
            (cat.replaced_sources || []).length === 0
              ? "None"
              : cat.replaced_sources.map((r) => `<code>${esc(r.coord)}</code>`).join(", ")
          }</div>
        `
            : `<div>New homebrew record authored in <code>${esc(state.packId)}</code> (no base catalog source).</div>`
        }
      </div>
    </div>

    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">Field-by-Field Diff (${modifiedRows.length} changed)</span>
      </div>
      <div class="grimoire-card-body" style="padding:0; overflow-x:auto;">
        <table class="diff-table">
          <thead>
            <tr>
              <th>Field</th>
              <th>Winner</th>
              <th>Fallback</th>
              <th>Active / Draft</th>
            </tr>
          </thead>
          <tbody>
            ${rowsToShow
              .map((row) => {
                const cls =
                  row.state === "modified_in_draft"
                    ? "diff-row-modified"
                    : row.state === "backfilled_from_fallback"
                    ? "diff-row-backfilled"
                    : row.state === "overridden_by_winner"
                    ? "diff-row-overridden"
                    : "";
                const fmt = (v) =>
                  v === undefined || v === null
                    ? `<span style="color:var(--text-dim);">—</span>`
                    : esc(typeof v === "object" ? JSON.stringify(v) : String(v));
                return `
                  <tr class="${cls}">
                    <td>
                      <strong style="font-family:var(--font-mono);">${esc(row.field)}</strong>
                      ${
                        row.state !== "unchanged"
                          ? `<div style="font-size:9.5px; color:var(--accent-primary-bright);">${esc(row.state.replace(/_/g, " "))}</div>`
                          : ""
                      }
                    </td>
                    <td class="diff-val">${fmt(row.winner)}</td>
                    <td class="diff-val">${fmt(row.fallback)}</td>
                    <td class="diff-val">${fmt(row.draft)}</td>
                  </tr>
                `;
              })
              .join("")}
          </tbody>
        </table>
      </div>
    </div>
  `;
}

function renderManifestTabHTML(manifest) {
  return `
    <div class="grimoire-card">
      <div class="grimoire-card-header">
        <span class="grimoire-card-title">Composable <code>pack.json</code> Preview</span>
        <span class="origin-tag">${esc(state.packId)}</span>
      </div>
      <div class="grimoire-card-body">
        <div style="font-size:11.5px; color:var(--text-secondary);">
          Class spell lists and starting equipment are emitted as additive maps so multiple packs compose cleanly without overwriting <code>wizard.json</code> or <code>fighter.json</code>.
        </div>
        <pre class="code-viewer">${esc(JSON.stringify(manifest || {}, null, 2))}</pre>
      </div>
    </div>
  `;
}

function renderJsonTabHTML(losslessRec, candidateRec) {
  const shown =
    state.jsonPreviewMode === "candidate" && candidateRec ? candidateRec : losslessRec;
  return `
    <div style="display:flex; justify-content:space-between; align-items:center;">
      <div class="mode-switcher">
        <button type="button" class="mode-switcher-btn ${state.jsonPreviewMode === "candidate" ? "active" : ""}" id="json-mode-cand">
          Game Pack Candidate
        </button>
        <button type="button" class="mode-switcher-btn ${state.jsonPreviewMode === "lossless" ? "active" : ""}" id="json-mode-loss">
          Draft Lossless
        </button>
      </div>
      <button type="button" class="btn btn-sm" id="btn-copy-json">📋 Copy JSON</button>
    </div>
    <pre class="code-viewer" id="inspector-json-pre" style="flex:1;">${esc(JSON.stringify(shown, null, 2))}</pre>
  `;
}

function bindJsonTabEvents() {
  document.getElementById("json-mode-cand")?.addEventListener("click", () => {
    state.jsonPreviewMode = "candidate";
    renderInspectorPane();
  });
  document.getElementById("json-mode-loss")?.addEventListener("click", () => {
    state.jsonPreviewMode = "lossless";
    renderInspectorPane();
  });
  document.getElementById("btn-copy-json")?.addEventListener("click", () => {
    const shown =
      state.jsonPreviewMode === "candidate" && state.activeEntryPayload?.candidate_preview
        ? state.activeEntryPayload.candidate_preview
        : state.workingRecord;
    navigator.clipboard.writeText(JSON.stringify(shown, null, 2));
    showToast("Copied JSON to clipboard");
  });
}

/* ============================================================================
 * Workbench Actions (Stage Override, Save Draft, Convert Shared, Clone, Export)
 * ========================================================================== */

async function handleStageOverride() {
  if (!state.selectedId) return;
  await apiPost("/api/stage_override", {
    pack_id: state.packId,
    content_type: state.currentType,
    source_id: state.selectedId,
  });
  await loadWorkspaceState();
  await selectEntry(state.currentType, state.selectedId);
  showToast(`Staged override draft for '${state.selectedId}'`);
}

async function handleSaveWorkingDraft() {
  const selection = state.loadedSelection;
  if (!isCurrentSelection(selection) || !state.workingRecord || state.workingRecord.id !== selection.recordId) return;
  if (state.currentType !== "spell" && state.currentType !== "item") return;
  const recordJSON = JSON.stringify(state.workingRecord);
  const stillSavedSelection = () => isCurrentSelection(selection) && JSON.stringify(state.workingRecord) === recordJSON;

  await apiPost("/api/update_draft", {
    pack_id: selection.packId,
    content_type: selection.contentType,
    record_id: selection.recordId,
    record: JSON.parse(recordJSON),
  });
  if (!stillSavedSelection()) return;
  state.isDirty = false;
  await loadWorkspaceState();
  if (!stillSavedSelection()) return;
  await loadCatalogList(false);
  if (!stillSavedSelection()) return;
  await selectEntry(state.currentType, state.selectedId);
  showToast(`Saved '${state.selectedId}' to workspace '${state.packId}'`);
}

async function handleConvertToShared() {
  const selection = state.loadedSelection;
  if (!isCurrentSelection(selection) || !state.workingRecord || state.currentType !== "spell") return;
  const recordJSON = JSON.stringify(state.workingRecord);
  const res = await apiPost("/api/convert_shared", {
    pack_id: selection.packId,
    record: JSON.parse(recordJSON),
    save_to_workspace: Boolean(state.activeEntryPayload?.draft),
  });
  if (!isCurrentSelection(selection) || JSON.stringify(state.workingRecord) !== recordJSON) return;
  state.workingRecord = res.record;
  state.isDirty = !state.activeEntryPayload?.draft;
  if (state.activeEntryPayload?.draft) {
    await loadWorkspaceState();
    await loadCatalogList(false);
    await selectEntry("spell", state.selectedId);
  } else {
    onWorkingRecordMutated(true);
  }
  showToast(`Converted '${state.workingRecord.id}' toward SharedSpell contract`);
}

async function handleDeleteDraft() {
  if (!state.selectedId) return;
  await apiPost("/api/delete_draft", {
    pack_id: state.packId,
    content_type: state.currentType,
    record_id: state.selectedId,
  });
  await loadWorkspaceState();
  await loadCatalogList(false);
  const existsInCatalog = state.catalogItems.some((i) => i.id === state.selectedId);
  if (existsInCatalog) {
    await selectEntry(state.currentType, state.selectedId);
  } else if (state.catalogItems.length > 0) {
    await selectEntry(state.currentType, state.catalogItems[0].id);
  } else {
    state.selectedId = null;
    state.activeEntryPayload = null;
    state.workingRecord = null;
    renderWorkbenchHeader();
    renderWorkbenchCenter();
    renderInspectorPane();
  }
  showToast(`Removed draft '${state.selectedId}' from workspace`);
}

/* ============================================================================
 * Topbar, Navigation, Modals & Keyboard Shortcuts
 * ========================================================================== */

function bindTopbarAndModals() {
  // Type navigation
  document.querySelectorAll("#type-nav .type-nav-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      state.currentType = btn.dataset.type;
      state.statusFilter = "";
      document.querySelectorAll("#status-filter-pills .filter-pill").forEach((p) => {
        p.classList.toggle("active", p.dataset.status === "");
      });
      syncTypeNavButtons();
      await loadCatalogList(false);
      if (state.catalogItems.length > 0) {
        await selectEntry(state.currentType, state.catalogItems[0].id);
      }
    });
  });

  // Status filter pills
  document.querySelectorAll("#status-filter-pills .filter-pill").forEach((pill) => {
    pill.addEventListener("click", async () => {
      state.statusFilter = pill.dataset.status || "";
      document.querySelectorAll("#status-filter-pills .filter-pill").forEach((p) => {
        p.classList.toggle("active", p === pill);
      });
      await loadCatalogList(false);
    });
  });

  // Search box
  let searchTimer = null;
  document.getElementById("catalog-search")?.addEventListener("input", (e) => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      state.searchQuery = e.target.value;
      loadCatalogList(false);
    }, 100);
  });

  // Inspector tabs
  document.querySelectorAll("#inspector-tabs .inspector-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      state.inspectorTab = tab.dataset.tab;
      document.querySelectorAll("#inspector-tabs .inspector-tab").forEach((t) => {
        t.classList.toggle("active", t === tab);
      });
      renderInspectorPane();
    });
  });

  // Pack switcher
  document.getElementById("pack-selector")?.addEventListener("change", async (e) => {
    state.packId = e.target.value;
    await loadWorkspaceState();
    await loadCatalogList(false);
    if (state.selectedId) {
      await selectEntry(state.currentType, state.selectedId);
    }
    showToast(`Switched active workspace to '${state.packId}'`);
  });

  // Close modal buttons
  document.querySelectorAll("[data-close-modal]").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.getElementById(btn.dataset.closeModal)?.close();
    });
  });

  // MODAL 1: Create from Template
  document.getElementById("btn-open-template")?.addEventListener("click", () => {
    renderTemplateModalGrid();
    document.getElementById("modal-template")?.showModal();
  });

  const tmplNameEl = document.getElementById("tmpl-input-name");
  const tmplSlugEl = document.getElementById("tmpl-input-slug");
  const updateTmplPreview = () => {
    const raw = (tmplSlugEl.value || tmplNameEl.value || "custom_entry")
      .toLowerCase()
      .replace(/[^a-z0-9_]+/g, "_")
      .replace(/^_+|_+$/g, "");
    document.getElementById("tmpl-id-preview").textContent = `${state.packId}:${raw || "custom_entry"}`;
  };
  tmplNameEl?.addEventListener("input", () => {
    if (!tmplSlugEl.dataset.touched) {
      tmplSlugEl.value = tmplNameEl.value
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, "_")
        .replace(/^_+|_+$/g, "");
    }
    updateTmplPreview();
  });
  tmplSlugEl?.addEventListener("input", () => {
    tmplSlugEl.dataset.touched = "1";
    updateTmplPreview();
  });

  document.getElementById("btn-confirm-template")?.addEventListener("click", async () => {
    const name = tmplNameEl.value.trim() || "New Homebrew";
    const slug = tmplSlugEl.value.trim() || name;
    const res = await apiPost("/api/create_template", {
      pack_id: state.packId,
      template_id: state.selectedTemplateId,
      new_slug: slug,
      new_name: name,
    });
    document.getElementById("modal-template")?.close();
    await loadWorkspaceState();
    state.currentType = res.draft.content_type;
    syncTypeNavButtons();
    await loadCatalogList(false);
    await selectEntry(res.draft.content_type, res.draft.id);
    showToast(`Created '${res.draft.id}' from template`);
  });

  // MODAL 2: Clone as Homebrew
  const cloneNameEl = document.getElementById("clone-input-name");
  const cloneSlugEl = document.getElementById("clone-input-slug");
  const updateClonePreview = () => {
    const raw = (cloneSlugEl.value || cloneNameEl.value || "clone")
      .toLowerCase()
      .replace(/[^a-z0-9_]+/g, "_")
      .replace(/^_+|_+$/g, "");
    document.getElementById("clone-id-preview").textContent = `${state.packId}:${raw || "clone"}`;
  };
  cloneNameEl?.addEventListener("input", () => {
    if (!cloneSlugEl.dataset.touched) {
      cloneSlugEl.value = cloneNameEl.value
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, "_")
        .replace(/^_+|_+$/g, "");
    }
    updateClonePreview();
  });
  cloneSlugEl?.addEventListener("input", () => {
    cloneSlugEl.dataset.touched = "1";
    updateClonePreview();
  });

  document.getElementById("btn-confirm-clone")?.addEventListener("click", async () => {
    const newName = cloneNameEl.value.trim();
    const newSlug = cloneSlugEl.value.trim() || newName;
    const autoConvert = document.getElementById("clone-auto-convert")?.checked;
    const res = await apiPost("/api/clone_homebrew", {
      pack_id: state.packId,
      content_type: state.currentType,
      source_id: state.selectedId,
      new_slug: newSlug,
      new_name: newName,
      auto_convert_shared: Boolean(autoConvert),
    });
    document.getElementById("modal-clone")?.close();
    await loadWorkspaceState();
    await selectEntry(state.currentType, res.draft.id);
    showToast(`Created homebrew clone '${res.draft.id}'`);
  });

  // MODAL 3: Export Pack Bundle
  document.getElementById("btn-open-export")?.addEventListener("click", () => {
    document.getElementById("export-receipt-box").style.display = "none";
    document.getElementById("modal-export")?.showModal();
  });

  document.getElementById("btn-confirm-export")?.addEventListener("click", async () => {
    const mode = document.getElementById("export-mode-select").value;
    const revision = document.getElementById("export-revision-input").value.trim() || "r1";
    const res = await apiPost("/api/export", {
      pack_id: state.packId,
      mode,
      revision,
    });
    const box = document.getElementById("export-receipt-box");
    box.style.display = "block";
    box.innerHTML = `
      <div class="diag-item diag-ok" style="margin-bottom:8px;">
        ✓ Exported ${res.exports.length} bundle(s) under <code>tools/content_editor/exports/</code>
      </div>
      <pre class="code-viewer" style="max-height:240px;">${esc(JSON.stringify(res.exports, null, 2))}</pre>
    `;
    showToast(`Exported pack '${state.packId}' (${mode})`);
  });

  // MODAL 4: Pack Settings
  document.getElementById("btn-pack-settings")?.addEventListener("click", () => {
    document.getElementById("pack-meta-id-label").textContent = `pack_id: ${state.packId}`;
    document.getElementById("pack-meta-name").value = state.metadata.name || "";
    document.getElementById("pack-meta-author").value = state.metadata.author || "Rook";
    document.getElementById("pack-meta-version").value = state.metadata.version || "0.1.0";
    document.getElementById("modal-pack")?.showModal();
  });

  document.getElementById("btn-save-pack-meta")?.addEventListener("click", async () => {
    await apiPost("/api/update_pack_meta", {
      pack_id: state.packId,
      name: document.getElementById("pack-meta-name").value,
      author: document.getElementById("pack-meta-author").value,
      version: document.getElementById("pack-meta-version").value,
    });
    await loadWorkspaceState();
    renderInspectorPane();
    showToast("Updated pack metadata");
  });

  document.getElementById("btn-create-switch-pack")?.addEventListener("click", async () => {
    const rawSlug = document.getElementById("new-pack-slug").value.trim();
    if (!rawSlug) return;
    const res = await apiPost("/api/update_pack_meta", {
      pack_id: rawSlug,
      name: rawSlug.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()),
    });
    state.packId = res.pack_id;
    document.getElementById("new-pack-slug").value = "";
    document.getElementById("modal-pack")?.close();
    await loadWorkspaceState();
    await loadCatalogList(true);
    showToast(`Created & switched to workspace '${state.packId}'`);
  });
}

function renderTemplateModalGrid() {
  const grid = document.getElementById("template-grid");
  const entries = Object.values(state.templates || {});
  grid.innerHTML = entries
    .map(
      (t) => `
    <div class="template-card ${t.id === state.selectedTemplateId ? "selected" : ""}" data-tmpl-id="${esc(t.id)}">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
        <strong style="color:var(--accent-primary-bright); font-size:12.5px;">${esc(t.label)}</strong>
        <span class="origin-tag">${esc(t.content_type)}</span>
      </div>
      <div style="font-size:11px; color:var(--text-muted);">${esc(t.description)}</div>
    </div>
  `
    )
    .join("");

  const syncDefaultInputs = () => {
    const cur = state.templates[state.selectedTemplateId];
    if (!cur) return;
    const nameEl = document.getElementById("tmpl-input-name");
    const slugEl = document.getElementById("tmpl-input-slug");
    nameEl.value = cur.record.name;
    const baseSlug = String(cur.record.id).split(":").pop();
    slugEl.value = baseSlug;
    delete slugEl.dataset.touched;
    document.getElementById("tmpl-id-preview").textContent = `${state.packId}:${baseSlug}`;
  };
  syncDefaultInputs();

  grid.querySelectorAll(".template-card").forEach((card) => {
    card.addEventListener("click", () => {
      state.selectedTemplateId = card.dataset.tmplId;
      renderTemplateModalGrid();
    });
  });
}

function openCloneModal() {
  if (!state.workingRecord) return;
  const baseName = `${state.workingRecord.name || state.selectedId} (Homebrew)`;
  const baseSlug = String(state.selectedId)
    .split(":")
    .pop()
    .replace(/[^a-z0-9_]+/g, "_");
  const nameEl = document.getElementById("clone-input-name");
  const slugEl = document.getElementById("clone-input-slug");
  nameEl.value = baseName;
  slugEl.value = `custom_${baseSlug}`;
  delete slugEl.dataset.touched;
  document.getElementById("clone-id-preview").textContent = `${state.packId}:custom_${baseSlug}`;

  const noticeEl = document.getElementById("clone-modal-notice");
  const autoPill = document.getElementById("clone-auto-convert-pill");
  if (state.currentType === "spell") {
    autoPill.style.display = "inline-flex";
    noticeEl.innerHTML = `
      <div class="callout-text">
        <h4>Cloning <code>${esc(state.selectedId)}</code> into <code>${esc(state.packId)}</code></h4>
        <p>New spell IDs are not in <code>SpellSupport.AVAILABLE_SLICES</code>, so they require <code>"execution": "shared"</code> to run in the engine.</p>
      </div>
    `;
  } else {
    autoPill.style.display = "none";
    noticeEl.innerHTML = `
      <div class="callout-text">
        <h4>Cloning Item <code>${esc(state.selectedId)}</code></h4>
        <p>Creates a new standalone item definition with a locked <code>${esc(state.packId)}:&lt;slug&gt;</code> ID.</p>
      </div>
    `;
  }

  document.getElementById("modal-clone")?.showModal();
}

function bindKeyboardShortcuts() {
  window.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") {
      e.preventDefault();
      handleSaveWorkingDraft();
    } else if (
      e.key === "/" &&
      document.activeElement?.tagName !== "INPUT" &&
      document.activeElement?.tagName !== "TEXTAREA" &&
      document.activeElement?.tagName !== "SELECT"
    ) {
      e.preventDefault();
      document.getElementById("catalog-search")?.focus();
    }
  });
}

document.addEventListener("DOMContentLoaded", initWorkbench);
