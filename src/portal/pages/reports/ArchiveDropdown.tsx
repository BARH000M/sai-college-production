import { archiveLabel, type SavedArchive } from "../../lib/archiveHeader";

type Props = {
  entries: SavedArchive[];
  onPick: (value: SavedArchive) => void;
};

/**
 * Dropdown of previously used term / prepared-by pairs. Picking one fills both
 * header fields so staff never retype them for each print.
 */
export function ArchiveDropdown({ entries, onPick }: Props) {
  if (!entries.length) return null;
  return <label>أرشيف الفصول المحفوظة
    <select
      value=""
      onChange={(event) => {
        const picked = entries[Number(event.target.value)];
        if (picked) onPick(picked);
      }}
    >
      <option value="">— تعبئة من آخر طباعة —</option>
      {entries.map((entry, index) => (
        <option key={`${entry.term}|${entry.preparedBy}|${index}`} value={index}>{archiveLabel(entry)}</option>
      ))}
    </select>
  </label>;
}