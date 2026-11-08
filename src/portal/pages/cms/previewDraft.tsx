import { createContext, useContext } from "react";
import type { CmsNews, CmsProgram } from "@/portal/lib/cms";

export type PreviewContent = Record<string, { value_ar: string; value_en: string }>;

export type PreviewDraftState = {
  content: PreviewContent | null;
  programs: CmsProgram[] | null;
  news: CmsNews[] | null;
};

export type CmsDraftKind = "content" | "programs" | "news";

export type CmsDirtyCounts = Record<CmsDraftKind, number>;

type PreviewDraftContextValue = {
  draft: PreviewDraftState;
  publish: (patch: Partial<PreviewDraftState>) => void;
  dirty: CmsDirtyCounts;
  setDirty: (kind: CmsDraftKind, count: number) => void;
  /** Increments whenever the user asks to discard unsaved edits; panels reset on change. */
  resetSignal: number;
  requestDiscard: () => void;
};

const emptyDraft: PreviewDraftState = { content: null, programs: null, news: null };
const emptyDirty: CmsDirtyCounts = { content: 0, programs: 0, news: 0 };

/**
 * Holds the in-progress (unsaved) CMS edits so the live preview can render the
 * public page exactly as it would look once these edits are published, and keeps
 * the per-tab "unsaved changes" counters visible before the tab is opened.
 */
export const PreviewDraftContext = createContext<PreviewDraftContextValue>({
  draft: emptyDraft,
  publish: () => {},
  dirty: emptyDirty,
  setDirty: () => {},
  resetSignal: 0,
  requestDiscard: () => {},
});

export function usePreviewDraft(): PreviewDraftContextValue {
  return useContext(PreviewDraftContext);
}