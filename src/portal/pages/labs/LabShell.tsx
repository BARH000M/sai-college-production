import type { ReactNode } from "react";

/** Shared header for the Chinese-learning practice screens. */
export function LabPage({ eyebrow, title, intro, badge, children }: {
  eyebrow: string;
  title: string;
  intro: string;
  badge?: string;
  children: ReactNode;
}) {
  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p className="muted">{intro}</p>
      </div>
      {badge && <span className="learn-pill">{badge}</span>}
    </div>
    {children}
  </main>;
}

export type LabTab<T extends string> = { id: T; label: string; icon?: string };

export function LabTabs<T extends string>({ tabs, value, onChange, label }: {
  tabs: readonly LabTab<T>[];
  value: T;
  onChange: (next: T) => void;
  label: string;
}) {
  return <div className="lab-tabs" role="tablist" aria-label={label}>
    {tabs.map((tab) => <button
      key={tab.id}
      type="button"
      role="tab"
      aria-selected={value === tab.id}
      className={`lab-tab${value === tab.id ? " active" : ""}`}
      onClick={() => onChange(tab.id)}
    >
      {tab.icon && <i className={tab.icon} aria-hidden="true"></i>}
      {tab.label}
    </button>)}
  </div>;
}

/** Small metric strip used across the lab screens. */
export function LabStats({ items }: { items: readonly { label: string; value: string; detail?: string }[] }) {
  return <div className="lab-stats">
    {items.map((item, index) => <div className={`lab-stat lab-stat-${index % 4}`} key={item.label}>
      <span>{item.label}</span>
      <strong>{item.value}</strong>
      {item.detail && <small>{item.detail}</small>}
    </div>)}
  </div>;
}

/** Correct / incorrect marker used by the practice quizzes. */
export function AnswerMark({ state }: { state: "correct" | "wrong" | null }) {
  if (!state) return null;
  return <span className={`lab-answer-mark ${state}`} aria-hidden="true">
    <i className={state === "correct" ? "ri-check-line" : "ri-close-line"}></i>
  </span>;
}