/**
 * Official identity printed on every sheet that leaves the college.
 * Keep this as the single source of truth so all printed documents
 * (reports, receipts, rosters) carry the same letterhead.
 */
export const collegeIdentity = {
  nameAr: "كلية ساي التعليمية اليمنية الصينية",
  nameEn: "SAI Yemeni–Chinese College",
  addressAr: "شارع حدة، صنعاء، الجمهورية اليمنية",
  phone: "+967 1 234 567",
  email: "info@saicollege.com",
  website: "www.saicollege.com",
  paper: "A4",
} as const;

/**
 * Optional formal-archiving header shared by every printed sheet:
 * the academic term/semester and the staff member who prepared the sheet.
 */
export type ArchiveHeader = { term?: string; preparedBy?: string };

export type SheetMeta = { label: string; value: string };

/**
 * Builds the meta rows shown under the document title on every printed sheet.
 * Always carries the issue date and paper size, and appends the term and
 * prepared-by name whenever they were supplied for formal archiving.
 */
export function buildSheetMeta(archive?: ArchiveHeader, extra?: readonly SheetMeta[]): SheetMeta[] {
  const meta: SheetMeta[] = [
    { label: "تاريخ الإصدار", value: printDate() },
    { label: "حجم الورق", value: "A4" },
  ];
  const term = archive?.term?.trim();
  const preparedBy = archive?.preparedBy?.trim();
  if (term) meta.push({ label: "الفصل / الفترة", value: term });
  if (preparedBy) meta.push({ label: "أعدّه", value: preparedBy });
  if (extra?.length) meta.push(...extra);
  return meta;
}

export function printDate(): string {
  return new Date().toLocaleDateString("ar-EG", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

/** Small reference code so a printed sheet can be traced back to its issue date. */
export function printReference(prefix: string): string {
  const date = new Date();
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${prefix}-${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`;
}