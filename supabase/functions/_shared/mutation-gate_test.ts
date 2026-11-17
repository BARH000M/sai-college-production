import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { mutationGateOpen } from "./mutation-gate.ts";

Deno.test("mutation gate allows only a successful server assertion", async () => {
  const allowed = await mutationGateOpen({
    rpc: async () => ({ error: null }),
  });
  assertEquals(allowed, true);

  const maintenance = await mutationGateOpen({
    rpc: async () => ({ error: { code: "55000" } }),
  });
  assertEquals(maintenance, false);

  const unavailable = await mutationGateOpen({
    rpc: async () => ({ error: { code: "PGRST202" } }),
  });
  assertEquals(unavailable, false);

  await assertRejects(
    () => mutationGateOpen({
      rpc: async () => { throw new Error("network unavailable"); },
    }),
    Error,
    "network unavailable",
  );
});
