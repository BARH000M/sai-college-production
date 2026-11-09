import { authRouter } from "./auth-router";
import { createRouter, publicQuery } from "./middleware";
import { collegeRouter } from "./collegeRouter";

export const appRouter = createRouter({
  ping: publicQuery.query(() => ({ ok: true, ts: Date.now() })),
  auth: authRouter,
  college: collegeRouter,
});

export type AppRouter = typeof appRouter;
