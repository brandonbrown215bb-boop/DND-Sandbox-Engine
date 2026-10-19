// Run the actual workbench handlers with controlled transport ordering.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");

function harness() {
  const context = vm.createContext({
    console, document: { addEventListener() {} },
    setTimeout: () => 0, clearTimeout() {},
  });
  const source = fs.readFileSync(path.join(__dirname, "ui/workbench.js"), "utf8");
  vm.runInContext(source + `
    globalThis.gets = [];
    globalThis.posts = [];
    apiGet = url => new Promise(resolve => gets.push({url, resolve}));
    apiPost = (url, body) => new Promise(resolve => posts.push({url, body: JSON.parse(JSON.stringify(body)), resolve}));
    for (const name of ['syncTypeNavButtons','renderCatalogList','renderDraftsTray','renderWorkbenchHeader','renderWorkbenchCenter','renderInspectorPane','showToast']) globalThis[name] = () => {};
    loadWorkspaceState = async () => {};
    loadCatalogList = async () => {};
    globalThis.review = {state, selectEntry, runLiveValidation, handleSaveWorkingDraft, handleConvertToShared, onWorkingRecordMutated};
    selectEntry = async () => {};
  `, context);
  return context;
}

function payload(id, name = id) {
  return {draft: {record: {id, name, damage: "2d6"}}, diagnostics: {status: "original"}};
}

async function load(h, id) {
  const request = h.review.selectEntry("spell", id);
  h.gets.at(-1).resolve(payload(id));
  await request;
}

test("a late selection response cannot replace the current record or its save", async () => {
  const h = harness();
  const first = h.review.selectEntry("spell", "demo:first");
  const second = h.review.selectEntry("spell", "demo:second");
  h.gets[1].resolve(payload("demo:second"));
  await second;
  h.gets[0].resolve(payload("demo:first"));
  await first;
  assert.equal(h.review.state.workingRecord.id, "demo:second");
  const save = h.review.handleSaveWorkingDraft();
  assert.equal(h.posts[0].body.record_id, "demo:second");
  assert.equal(h.posts[0].body.record.id, "demo:second");
  h.posts[0].resolve({});
  await save;
});

test("save refuses an unfinished selection, a mismatched record, and an old workspace", async () => {
  const h = harness();
  await load(h, "demo:first");
  const loading = h.review.selectEntry("spell", "demo:second");
  await h.review.handleSaveWorkingDraft();
  assert.equal(h.posts.length, 0);
  h.gets.at(-1).resolve(payload("demo:second"));
  await loading;
  h.review.state.workingRecord.id = "demo:first";
  await h.review.handleSaveWorkingDraft();
  assert.equal(h.posts.length, 0);
  h.review.state.workingRecord.id = "demo:second";
  h.review.state.packId = "other_pack";
  await h.review.handleSaveWorkingDraft();
  assert.equal(h.posts.length, 0);
});

test("reselecting the same ID still rejects an earlier request generation", async () => {
  const h = harness();
  const old = h.review.selectEntry("spell", "demo:first");
  const latest = h.review.selectEntry("spell", "demo:first");
  h.gets[1].resolve(payload("demo:first", "Latest"));
  await latest;
  h.gets[0].resolve(payload("demo:first", "Old"));
  await old;
  assert.equal(h.review.state.workingRecord.name, "Latest");
});

test("late validation cannot alter a newer selection", async () => {
  const h = harness();
  await load(h, "demo:first");
  const validation = h.review.runLiveValidation();
  await load(h, "demo:second");
  h.posts[0].resolve({diagnostics: {status: "stale"}});
  await validation;
  assert.equal(h.review.state.activeEntryPayload.diagnostics.status, "original");
});

test("edits invalidate older validation results on the same selection", async () => {
  const h = harness();
  await load(h, "demo:first");
  const old = h.review.runLiveValidation();
  h.review.state.workingRecord.damage = "3d6";
  h.review.onWorkingRecordMutated();
  const latest = h.review.runLiveValidation();
  h.posts[1].resolve({diagnostics: {status: "latest"}});
  await latest;
  h.posts[0].resolve({diagnostics: {status: "stale"}});
  await old;
  assert.equal(h.review.state.activeEntryPayload.diagnostics.status, "latest");
});

test("a finishing save preserves edits made while that save was pending", async () => {
  const h = harness();
  await load(h, "demo:first");
  const saving = h.review.handleSaveWorkingDraft();
  h.review.state.workingRecord.damage = "3d6";
  h.review.onWorkingRecordMutated();
  assert.equal(h.posts[0].body.record.damage, "2d6");
  h.posts[0].resolve({});
  await saving;
  assert.equal(h.review.state.workingRecord.damage, "3d6");
  assert.equal(h.review.state.isDirty, true);
});

test("a late conversion cannot replace a newer selection of the same record ID", async () => {
  const h = harness();
  await load(h, "demo:first");
  const conversion = h.review.handleConvertToShared();
  await load(h, "demo:first");
  h.posts[0].resolve({record: {id: "demo:first", name: "Old conversion", damage: "1d6"}});
  await conversion;
  assert.equal(h.review.state.workingRecord.damage, "2d6");
});

test("a finishing conversion preserves edits made while it was pending", async () => {
  const h = harness();
  await load(h, "demo:first");
  const conversion = h.review.handleConvertToShared();
  h.review.state.workingRecord.damage = "3d6";
  h.review.onWorkingRecordMutated();
  h.posts[0].resolve({record: {id: "demo:first", damage: "1d6"}});
  await conversion;
  assert.equal(h.review.state.workingRecord.damage, "3d6");
  assert.equal(h.review.state.isDirty, true);
});
