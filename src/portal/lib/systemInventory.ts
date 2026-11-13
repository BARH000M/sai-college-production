import { canAccessModule, isModuleAvailable, modulePath, navigation } from "./navigation.ts";
import type { InventoryReferenceEntry } from "./systemInventoryEntries";

export type SystemCategory = {
  id: string;
  name: string;
  expectedEntries: number;
  moduleIds: readonly string[];
};

export const systemCategories: readonly SystemCategory[] = [
  { id: "front-office", name: "Front Office", expectedEntries: 7, moduleIds: ["admissions", "scanner"] },
  { id: "student-information", name: "Student Information", expectedEntries: 15, moduleIds: ["students", "classes", "profile"] },
  { id: "fees-collection", name: "Fees Collection", expectedEntries: 9, moduleIds: ["finance"] },
  { id: "income", name: "Income", expectedEntries: 2, moduleIds: ["finance", "reports"] },
  { id: "expenses", name: "Expenses", expectedEntries: 2, moduleIds: ["finance", "reports"] },
  { id: "attendance", name: "Attendance", expectedEntries: 3, moduleIds: ["attendance", "qr"] },
  { id: "examinations", name: "Examinations", expectedEntries: 4, moduleIds: ["quizzes", "exams"] },
  { id: "cbse-examinations", name: "CBSE Examinations", expectedEntries: 10, moduleIds: ["exams", "quizzes"] },
  { id: "cbse-exam", name: "CBSE Exam", expectedEntries: 8, moduleIds: ["exams", "quizzes"] },
  { id: "academics", name: "Academics", expectedEntries: 6, moduleIds: ["academics", "timetable", "classes", "branches", "sessions"] },
  { id: "homework", name: "Homework", expectedEntries: 1, moduleIds: ["homework"] },
  { id: "download-center", name: "Download Center", expectedEntries: 2, moduleIds: ["downloads"] },
  { id: "library", name: "Library", expectedEntries: 3, moduleIds: ["library"] },
  { id: "transport", name: "Transport", expectedEntries: 3, moduleIds: ["transport"] },
  { id: "hostel", name: "Hostel", expectedEntries: 1, moduleIds: ["housing"] },
  { id: "inventory", name: "Inventory", expectedEntries: 2, moduleIds: ["inventory"] },
  { id: "human-resources", name: "Human Resources", expectedEntries: 5, moduleIds: ["staff"] },
  { id: "communicate", name: "Communicate", expectedEntries: 3, moduleIds: ["communications", "notifications"] },
  { id: "online-courses", name: "Online Courses", expectedEntries: 5, moduleIds: ["courses", "vocabulary", "progress"] },
  { id: "live-classes", name: "Live Classes", expectedEntries: 2, moduleIds: [] },
  { id: "behaviour-records", name: "Behaviour Records", expectedEntries: 2, moduleIds: [] },
  { id: "certificates-cards", name: "Certificates and Cards", expectedEntries: 3, moduleIds: ["certificates"] },
  { id: "front-cms", name: "Front CMS", expectedEntries: 1, moduleIds: ["cms", "frontCms"] },
  { id: "alumni", name: "Alumni", expectedEntries: 2, moduleIds: ["alumni"] },
  { id: "continuity-center", name: "Continuity Center", expectedEntries: 1, moduleIds: [] },
  { id: "calendar", name: "Calendar", expectedEntries: 1, moduleIds: ["timetable"] },
  { id: "reports", name: "Reports", expectedEntries: 6, moduleIds: ["reports"] },
  { id: "internal-messaging", name: "Internal Messaging", expectedEntries: 1, moduleIds: ["communications"] },
  { id: "student-personal-services", name: "Student Personal Services", expectedEntries: 2, moduleIds: ["home", "courses", "homework", "progress"] },
  { id: "parent-personal-services", name: "Parent Personal Services", expectedEntries: 3, moduleIds: ["home", "courses", "homework", "finance"] },
  { id: "backup-restore", name: "Backup and Restore", expectedEntries: 1, moduleIds: [] },
  { id: "system-settings", name: "System Settings", expectedEntries: 31, moduleIds: ["settings", "roles"] },
];

export const expectedSystemEntryCount = systemCategories.reduce((total, category) => total + category.expectedEntries, 0);

export function inventoryRelatedModulePath(entry: InventoryReferenceEntry): string | null {
  if (entry.status === "pending" || !entry.moduleId) return null;
  const item = navigation.find((module) => module.id === entry.moduleId);
  if (!item || !isModuleAvailable(item.id) || !canAccessModule(item.id, ["super_admin"])) return null;
  return modulePath(item);
}
