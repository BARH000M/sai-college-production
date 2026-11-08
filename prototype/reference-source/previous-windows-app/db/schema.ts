import {
  mysqlTable,
  mysqlEnum,
  serial,
  varchar,
  text,
  timestamp,
  bigint,
} from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: serial("id").primaryKey(),
  unionId: varchar("unionId", { length: 255 }).notNull().unique(),
  name: varchar("name", { length: 255 }),
  email: varchar("email", { length: 320 }),
  avatar: text("avatar"),
  role: mysqlEnum("role", ["user", "admin"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt")
    .defaultNow()
    .notNull()
    .$onUpdate(() => new Date()),
  lastSignInAt: timestamp("lastSignInAt").defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

export const programs = mysqlTable("programs", {
  id: serial("id").primaryKey(),
  slug: varchar("slug", { length: 120 }).notNull().unique(),
  title: varchar("title", { length: 255 }).notNull(),
  category: varchar("category", { length: 80 }).notNull(),
  subtitle: varchar("subtitle", { length: 255 }).notNull(),
  description: text("description").notNull(),
  level: varchar("level", { length: 120 }).notNull(),
  duration: varchar("duration", { length: 120 }).notNull(),
  schedule: varchar("schedule", { length: 120 }).notNull(),
  imageUrl: varchar("imageUrl", { length: 255 }).notNull(),
  sortOrder: bigint("sortOrder", { mode: "number" }).notNull().default(0),
});

export const news = mysqlTable("news", {
  id: serial("id").primaryKey(),
  slug: varchar("slug", { length: 120 }).notNull().unique(),
  title: varchar("title", { length: 255 }).notNull(),
  summary: text("summary").notNull(),
  content: text("content").notNull(),
  publishedAt: timestamp("publishedAt").notNull(),
});

export const admissionRequests = mysqlTable("admission_requests", {
  id: serial("id").primaryKey(),
  reference: varchar("reference", { length: 24 }).notNull().unique(),
  userId: bigint("userId", { mode: "number", unsigned: true }).notNull(),
  studentName: varchar("studentName", { length: 255 }).notNull(),
  phone: varchar("phone", { length: 40 }).notNull(),
  programSlug: varchar("programSlug", { length: 120 }).notNull(),
  message: text("message"),
  status: mysqlEnum("status", ["received", "reviewing", "contacted"]).default("received").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const documents = mysqlTable("documents", {
  id: serial("id").primaryKey(),
  verificationCode: varchar("verificationCode", { length: 40 }).notNull().unique(),
  title: varchar("title", { length: 255 }).notNull(),
  holderName: varchar("holderName", { length: 255 }).notNull(),
  issuedAt: timestamp("issuedAt").notNull(),
  status: mysqlEnum("status", ["valid", "expired", "revoked"]).default("valid").notNull(),
});

export type Program = typeof programs.$inferSelect;
export type NewsItem = typeof news.$inferSelect;
export type AdmissionRequest = typeof admissionRequests.$inferSelect;
