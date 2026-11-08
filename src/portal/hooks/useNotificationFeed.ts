import { useCallback, useEffect, useState } from "react";
import {
  loadNotifications, notificationsSeenEvent, readSeenAt, unreadCount,
  type AppNotification,
} from "@/portal/lib/notifications";

type FeedState = {
  items: AppNotification[];
  userId: string | null;
  seenAt: string | null;
  loading: boolean;
  error: string | null;
};

const emptyState: FeedState = { items: [], userId: null, seenAt: null, loading: true, error: null };

/** Shared feed used by both the header bell and the notifications centre. */
export function useNotificationFeed(roles: readonly string[]) {
  const [state, setState] = useState<FeedState>(emptyState);
  const roleKey = roles.join(",");

  const load = useCallback(async () => {
    try {
      const feed = await loadNotifications(roles);
      const seenAt = feed.userId ? readSeenAt(feed.userId) : null;
      setState({ items: feed.items, userId: feed.userId, seenAt, loading: false, error: null });
    } catch (failure) {
      setState({ items: [], userId: null, seenAt: null, loading: false, error: failure instanceof Error ? failure.message : String(failure) });
    }
    // roles is stable for the lifetime of the session, roleKey captures it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roleKey]);

  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    const handler = () => { void load(); };
    const onVisible = () => { if (document.visibilityState === "visible") handler(); };
    window.addEventListener(notificationsSeenEvent, handler);
    window.addEventListener("focus", handler);
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      window.removeEventListener(notificationsSeenEvent, handler);
      window.removeEventListener("focus", handler);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [load]);

  return {
    items: state.items,
    userId: state.userId,
    seenAt: state.seenAt,
    loading: state.loading,
    error: state.error,
    unread: unreadCount(state.items, state.seenAt),
    refresh: load,
    applySeen: (seenAt: string) => setState((current) => ({ ...current, seenAt })),
  };
}