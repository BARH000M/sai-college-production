function escapeCell(value: string | null): string {
  const cell = value == null ? "" : value;
  return `"${cell.replace(/"/g, '""')}"`;
}

export function buildCsv(headers: readonly string[], rows: readonly (readonly (string | null)[])[]): string {
  const lines = [headers.map(escapeCell).join(","), ...rows.map((row) => row.map(escapeCell).join(","))];
  // The BOM keeps Arabic readable when the file is opened in Excel.
  return `\uFEFF${lines.join("\r\n")}`;
}

export function downloadCsv(filename: string, content: string): void {
  const blob = new Blob([content], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.rel = "noopener";
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}