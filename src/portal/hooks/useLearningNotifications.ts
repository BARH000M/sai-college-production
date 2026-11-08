import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/portal/lib/supabase";
import { learningSeenEvent, loadLearningSeen } from "@/portal/lib/learningNotifications";

type CountRow = { id: string; created_at?: string; published_at?: string | null; graded_at?: string | null; status?: string; is_published?: boolean };

/**
 * Counts unread homework releases and released grades for the signed-in learner.
 * Both the data and the acknowledgement marker are read from the server, so the
 * badge matches on every device the account signs in from.
 */
export function useLearningNotifications(roles: readonly string[]) {
  const isLearner = roles.includes("student") || roles.includes("parent");
  const [count, setCount] = useState(0);

  const load = useCallback(async () => {
    if (!isLearner) {
      setCount(0);
      return;
    }
    try {
      const { userId, seenAt } = await loadLearningSeen();
      if (!userId) {
        setCount(0);
        return;
      }
      const seenTime = seenAt ? new Date(seenAt).getTime() : null;

      const [students, homework, submissions] = await Promise.all([
        supabase.from("students").select("id"),
        supabase.from("learning_homework").select("id,published_at,created_at,is_published").eq("is_published", true),
        supabase.from("learning_homework_submissions").select("id,status,graded_at"),
      ]);

      const isNew = (value?: string | null) => {
        if (!value) return false;
        if (seenTime === null) return true;
        return new Date(value).getTime() > seenTime;
      };

      let total = 0;
      if (!homework.error) {
        total += ((homework.data ?? []) as CountRow[])
          .filter((row) => row.is_published !== false && isNew(row.published_at ?? row.created_at)).length;
      }
      if (!submissions.error) {
        total += ((submissions.data ?? []) as CountRow[])
          .filter((row) => row.status === "graded" && isNew(row.graded_at)).length;
      }
      // The students query is only needed to confirm a linked record exists.
      if (students.error) {
        setCount(0);
        return;
      }
      setCount(total);
    } catch {
      setCount(0);
    }
  }, [isLearner]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    const handler = () => { void load(); };
    const onVisible = () => { if (document.visibilityState === "visible") handler(); };
    window.addEventListener(learningSeenEvent, handler);
    window.addEventListener("focus", handler);
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      window.removeEventListener(learningSeenEvent, handler);
      window.removeEventListener("focus", handler);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [load]);

  return { count, refresh: load };
}