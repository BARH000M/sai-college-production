import { createContext, useContext } from "react";
import type { CmsNews, CmsProgram } from "@/portal/lib/cms";

export type PreviewContent = Record<string, { value_ar: string; value_en: string }>;

export type PreviewDraftState = {
  content: PreviewContent | null;
  programs: CmsProgram[] | null;
  news: CmsNews[] | null;
};

type PreviewDraftContextValue = {
  draft: PreviewDraftState;
  publish: (patch: Partial<PreviewDraftState>) => void;
};

const emptyDraft: PreviewDraftState = { content: null, programs: null, news: null };

/**
 * Holds the in-progress (unsaved) CMS edits so the live preview can render the
 * public page exactly as it would look once these edits are published.
 */
export const PreviewDraftContext = createContext<PreviewDraftContextValue>({
  draft: emptyDraft,
  publish: () => {},
});

export function usePreviewDraft(): PreviewDraftContextValue {
  return useContext(PreviewDraftContext);
}