const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const base = path.join(__dirname, "../src/lib");
const helpers = stripTypeScriptTypes(fs.readFileSync(path.join(base, "finance.ts"), "utf8"), { mode: "strip" });
const helpersUrl = `data:text/javascript;base64,${Buffer.from(helpers).toString("base64")}`;
const source = fs.readFileSync(path.join(base, "financeApi.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__financeTestClient;")
  .replace('"./finance"', JSON.stringify(helpersUrl));
const code = stripTypeScriptTypes(source, { mode: "strip" });
async function load(client) {
  globalThis.__financeTestClient = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${Math.random()}`);
}

test("payment RPC keeps the idempotency key and sends normalized decimal strings", async () => {
  const calls = [];
  const api = await load({ rpc: async (...args) => { calls.push(args); return { data: "payment-id", error: null }; } });
  assert.equal(await api.postFinancePayment("assignment", "1.235", "bank_transfer", " ref ", "stable-key"), "payment-id");
  assert.deepEqual(calls[0], ["sai_finance_pay", {
    wanted_assignment: "assignment", wanted_amount: "1.24", wanted_method: "bank_transfer",
    wanted_reference: "ref", wanted_key: "stable-key",
  }]);
  assert.throws(() => api.postFinancePayment("assignment", "0", "cash", "", "stable-key"));
  assert.equal(calls.length, 1);
});

test("finance queries surface errors and do not silently truncate pages", async () => {
  const ranges = [];
  const client = { rpc: () => ({ range: async (start, end) => {
    ranges.push([start, end]);
    return start === 0
      ? { data: Array.from({ length: 1000 }, (_, id) => ({ id })), count: 1001, error: null }
      : { data: [{ id: 1000 }], count: 1001, error: null };
  } }) };
  const api = await load(client);
  assert.equal((await api.loadFeeAssignments()).length, 1001);
  assert.deepEqual(ranges, [[0, 999], [1000, 1999]]);
  client.rpc = () => ({ range: async () => ({ data: null, count: null, error: { message: "permission denied" } }) });
  await assert.rejects(api.loadFeeAssignments(), /permission denied/);
  client.rpc = () => ({ range: async () => ({ data: [], count: 1, error: null }) });
  await assert.rejects(api.loadFeeAssignments(), /جميع السجلات/);
});

test("voids, waivers and refunds surface database failures", async () => {
  const api = await load({ rpc: async () => ({ data: null, error: { message: "denied" } }) });
  await assert.rejects(api.voidFinancePayment("payment", "long reason"), /denied/);
  await assert.rejects(api.waiveFee("assignment", "reason"), /denied/);
  await assert.rejects(api.refundFinancePayment("payment", "1", "cash", "", "reason", "refund-key"), /denied/);
});

test("refund RPC preserves idempotency key and normalized request", async () => {
  const calls = [];
  const api = await load({ rpc: async (...args) => { calls.push(args); return { data: "refund-id", error: null }; } });
  assert.equal(await api.refundFinancePayment("payment", "1.235", "card", " ref ", " reason ", "key"), "refund-id");
  assert.deepEqual(calls[0], ["sai_finance_refund", {
    wanted_payment: "payment", wanted_amount: "1.24", wanted_method: "card",
    wanted_reference: "ref", wanted_reason: "reason", wanted_key: "key",
  }]);
});
test("missing mutation identifiers never report success", async () => {
  const api = await load({ rpc: async () => ({ data: null, error: null }) });
  await assert.rejects(api.postFinancePayment("assignment", "1", "cash", "", "key"), /استجابة العملية غير صالحة/);
  await assert.rejects(api.waiveFee("assignment", "reason"), /استجابة العملية غير صالحة/);
});
