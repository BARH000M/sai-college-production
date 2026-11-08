import { useEffect } from "react";

const DEFAULT_MESSAGE =
  "لديك تعديلات غير محفوظة في الموقع التعريفي. إذا غادرت الصفحة الآن ستفقد هذه التعديلات. هل تريد المغادرة؟";

/**
 * Protects unsaved edits from being lost.
 * - Reloading or closing the browser tab triggers the native "leave site?" prompt.
 * - Clicking any in-app link while unsaved edits exist shows a confirmation dialog
 *   first; rejecting it cancels the navigation from the capture phase.
 */
export function useUnsavedChangesGuard(unsavedCount: number, message: string = DEFAULT_MESSAGE): void {
  useEffect(() => {
    if (unsavedCount <= 0) return undefined;

    const handleBeforeUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
      return "";
    };

    const handleLinkClick = (event: MouseEvent) => {
      if (event.defaultPrevented || event.button !== 0) return;
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      const target = event.target as Element | null;
      const anchor = target?.closest?.("a[href]") as HTMLAnchorElement | null;
      if (!anchor) return;
      if (anchor.dataset.guard === "skip" || anchor.hasAttribute("download")) return;
      if (anchor.target && anchor.target !== "_self") return;

      const raw = anchor.getAttribute("href") ?? "";
      if (!raw || raw.startsWith("#") || raw.startsWith("mailto:") || raw.startsWith("tel:")) return;

      const next = new URL(anchor.href, window.location.href);
      if (next.origin !== window.location.origin) return;
      if (next.pathname === window.location.pathname && next.search === window.location.search) return;

      if (window.confirm(message)) return;
      event.preventDefault();
      event.stopPropagation();
    };

    window.addEventListener("beforeunload", handleBeforeUnload);
    document.addEventListener("click", handleLinkClick, true);
    return () => {
      window.removeEventListener("beforeunload", handleBeforeUnload);
      document.removeEventListener("click", handleLinkClick, true);
    };
  }, [unsavedCount, message]);
}