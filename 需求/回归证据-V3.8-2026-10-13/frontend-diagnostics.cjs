const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(process.argv[2], 'utf8');
const part = (start, end) => {
  const a = source.indexOf(start), b = source.indexOf(end, a);
  assert.ok(a >= 0 && b > a, 'source boundaries changed');
  return source.slice(a, b);
};
const core = part('  const pending = new Set();', '  function toast(')
  + part('  class APIError', '  function empty(')
  + part('  function accountStatusForm(', '  function render()');
async function run(result, status = 200) {
  const observed = { toast: '', closed: false, callback: null };
  const context = vm.createContext({
    AbortController, setTimeout, clearTimeout,
    apiBase: '', token: 'synthetic-token', timeoutMs: 100,
    D: { uid: () => 'synthetic-request' },
    fetch: async () => ({ ok: status >= 200 && status < 300, status, json: async () => result }),
    modal: (_title, _body, cb) => { observed.callback = cb; },
    field: () => '', render: () => {},
    $: () => ({ close: () => { observed.closed = true; } }),
    toast: value => { observed.toast = value; },
  });
  vm.runInContext(core + '\naccountStatusForm("customer", "disabled");', context);
  let error = null;
  try { await observed.callback({ get: () => 'synthetic reason' }); }
  catch (e) { error = e.message; }
  return { closed: observed.closed, toast: observed.toast, error };
}
(async () => {
  // Deliberately assert current defects; success means the defect was reproduced.
  for (const result of [null, {}]) {
    const actual = await run(result);
    assert.equal(actual.closed, true);
    assert.equal(actual.toast, '账号状态已更新。');
    console.log(JSON.stringify({ finding: 'R05', response: result, ...actual }));
  }
  const denied = await run({ message: 'synthetic denial' }, 403);
  assert.equal(denied.closed, false);
  assert.equal(denied.error, 'synthetic denial');
  console.log(JSON.stringify({ control: 'HTTP403 remains rejected', ...denied }));
  assert.ok(part('  function modal(', '  function showAction(').includes('formKeys = new Map();'));
  console.log('Control: opening a new modal resets formKeys; identical independent modal submissions are NOT reported as an idempotency defect.');
  assert.ok(source.includes('apiBase = "http://127.0.0.1:8380"'));
  console.log('R06: file protocol fallback points to 8380; deployed workbench default is 8098.');
})().catch(error => { console.error(error); process.exitCode = 1; });
