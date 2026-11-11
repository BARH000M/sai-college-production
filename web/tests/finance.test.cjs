const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/finance.ts"), "utf8");
const code = stripTypeScriptTypes(source, { mode: "strip" });
const finance = import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}`);

test("YER rounding is decimal half-up and respects numeric(12,2)", async () => {
  const { normalizeYER, formatYER } = await finance;
  assert.equal(normalizeYER("2.345"), "2.35");
  assert.equal(normalizeYER("2.3449"), "2.34");
  assert.equal(normalizeYER("0001.2"), "1.20");
  assert.equal(normalizeYER("9999999999.994"), "9999999999.99");
  assert.throws(() => normalizeYER("9999999999.995"));
  for (const value of ["", "-1", "1e2", ".5", "1.", "NaN", "1,000"]) assert.throws(() => normalizeYER(value));
  assert.equal(formatYER("5.00"), "5 ر.ي");
  assert.equal(formatYER("5.50"), "5.5 ر.ي");
  assert.equal(formatYER("5.05"), "5.05 ر.ي");
});

test("payment validation rejects nonpositive amounts and missing electronic references", async () => {
  const { validateFinancePayment } = await finance;
  assert.equal(validateFinancePayment("0.004", "cash", ""), "يجب أن يكون مبلغ الدفع أكبر من صفر.");
  assert.equal(validateFinancePayment("0.005", "cash", ""), null);
  assert.ok(validateFinancePayment("-1", "cash", ""));
  assert.ok(validateFinancePayment("2", "unknown", ""));
  for (const method of ["bank_transfer", "wallet", "card"]) {
    assert.ok(validateFinancePayment("2", method, "  "));
    assert.equal(validateFinancePayment("2", method, "reference"), null);
  }
});

test("finance controls reflect role decisions without widening unrelated roles", async () => {
  const { financePermissions } = await finance;
  assert.deepEqual(financePermissions(["super_admin"]), {
    view: true, manageGroups: true, assignFees: true, postPayment: true, waive: true, void: true, refund: true,
  });

  assert.deepEqual(financePermissions(["accountant"]), {
    view: true, manageGroups: true, assignFees: true, postPayment: true, waive: true, void: true, refund: false,
  });

  test("saved payment and refund recovery validates the entire payload", async () => {
    const { parsePendingFinancePayment, parsePendingFinanceRefund } = await finance;
    const payment = { assignment: "a", amount: "12.50", method: "card", reference: "ref", key: "key" };
    assert.deepEqual(parsePendingFinancePayment(JSON.stringify(payment)), payment);
    assert.throws(() => parsePendingFinancePayment(JSON.stringify({ ...payment, reference: "" })));
    assert.throws(() => parsePendingFinancePayment(JSON.stringify({ ...payment, key: "" })));
    assert.throws(() => parsePendingFinancePayment("not-json"));
    const refund = { ...payment, payment: "p", reason: "reason" };
    assert.deepEqual(parsePendingFinanceRefund(JSON.stringify(refund)), refund);
    assert.throws(() => parsePendingFinanceRefund(JSON.stringify({ ...refund, payment: "" })));
    assert.throws(() => parsePendingFinanceRefund(JSON.stringify({ ...refund, reason: " " })));
  });
  assert.deepEqual(financePermissions(["admin"]), {
    view: true, manageGroups: true, assignFees: true, postPayment: true, waive: false, void: false, refund: false,
  });
  assert.deepEqual(financePermissions(["receptionist"]), {
    view: true, manageGroups: false, assignFees: false, postPayment: true, waive: false, void: false, refund: false,
  });
  for (const role of ["student", "parent"]) {
    const permissions = financePermissions([role]);
    assert.equal(permissions.view, true);
    assert.equal(permissions.postPayment, false);
  }
  for (const role of ["teacher", "librarian", "content_editor", "unknown"]) {
    assert.equal(financePermissions([role]).view, false);
  }
});
