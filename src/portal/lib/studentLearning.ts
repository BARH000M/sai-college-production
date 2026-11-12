export function visibleLearningItems<T extends { is_published: boolean }>(
  items: T[],
  learnerOnly: boolean,
): T[] {
  return learnerOnly ? items.filter((item) => item.is_published) : items;
}

export function canAccessOperations(roles: readonly string[]): boolean {
  return roles.some((role) => role === "super_admin" || role === "admin");
}
