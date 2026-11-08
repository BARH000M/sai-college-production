import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { randomUUID } from "node:crypto";
import { asc, desc, eq } from "drizzle-orm";
import { createRouter, publicQuery, authedQuery } from "./middleware";
import { getDb } from "./queries/connection";
import { admissionRequests, documents, news, programs } from "@db/schema";

const requestInput = z.object({
  studentName: z.string().trim().min(3).max(255),
  phone: z.string().trim().min(7).max(40),
  programSlug: z.string().trim().min(1).max(120),
  message: z.string().trim().max(500).optional(),
});

export const collegeRouter = createRouter({
  programs: publicQuery.query(async () => {
    return getDb().select().from(programs).orderBy(asc(programs.sortOrder));
  }),

  news: publicQuery.query(async () => {
    return getDb().select().from(news).orderBy(desc(news.publishedAt));
  }),

  myRequests: authedQuery.query(async ({ ctx }) => {
    return getDb()
      .select()
      .from(admissionRequests)
      .where(eq(admissionRequests.userId, ctx.user.id))
      .orderBy(desc(admissionRequests.createdAt));
  }),

  createRequest: authedQuery.input(requestInput).mutation(async ({ ctx, input }) => {
    const [program] = await getDb().select({ id: programs.id }).from(programs)
      .where(eq(programs.slug, input.programSlug)).limit(1);
    if (!program) throw new TRPCError({ code: "BAD_REQUEST", message: "البرنامج غير موجود" });
    const reference = `SAI-${randomUUID().replaceAll("-", "").slice(0, 20).toUpperCase()}`;
    const [result] = await getDb().insert(admissionRequests).values({
      ...input,
      reference,
      userId: ctx.user.id,
    }).$returningId();
    const [created] = await getDb().select().from(admissionRequests).where(eq(admissionRequests.id, result.id));
    return created;
  }),

  verifyDocument: publicQuery
    .input(z.object({ code: z.string().trim().min(6).max(40) }))
    .query(async ({ input }) => {
      const [document] = await getDb()
        .select()
        .from(documents)
        .where(eq(documents.verificationCode, input.code.toUpperCase()))
        .limit(1);
      return document ?? null;
    }),
});
