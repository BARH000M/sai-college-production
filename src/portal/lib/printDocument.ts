/**
 * Sends the currently open sheet to the browser print dialog while making the
 * suggested file name match the document itself (for example "كشف طلاب الصف").
 * Browsers derive the "Save as PDF" / saved file name from the page title, so
 * the title is swapped for the document title during printing and restored
 * afterwards.
 */

const DEFAULT_TITLE = "كلية ساي";

/** Removes characters that operating systems refuse inside file names. */
export function printFileName(title: string): string {
  const cleaned = title
    .replace(/[\\/:*?"<>|]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 120);
  return cleaned || DEFAULT_TITLE;
}

export function printSheet(title?: string): void {
  if (typeof window === "undefined") return;

  const originalTitle = document.title;
  const nextTitle = title?.trim() ? printFileName(title) : "";
  let restored = false;
  let timer = 0;

  const restore = () => {
    if (restored) return;
    restored = true;
    window.clearTimeout(timer);
    window.removeEventListener("afterprint", restore);
    if (nextTitle) document.title = originalTitle;
  };

  if (nextTitle) {
    document.title = nextTitle;
    window.addEventListener("afterprint", restore);
    // Safety net for browsers that never fire afterprint.
    timer = window.setTimeout(restore, 120000);
  }

  window.print();
}