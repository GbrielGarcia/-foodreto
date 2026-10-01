export type ScopeKey = string;

export function globalScope(): ScopeKey {
  return "global";
}

export function categoryScope(categoryId: string): ScopeKey {
  return `global:cat:${categoryId}`;
}

export function restaurantCategoryScope(
  restaurantId: string,
  categoryId: string,
): ScopeKey {
  return `restaurant:${restaurantId}:cat:${categoryId}`;
}

export function scopesForResult(input: {
  categoryId: string;
  restaurantId?: string | null;
}): ScopeKey[] {
  const scopes: ScopeKey[] = [globalScope(), categoryScope(input.categoryId)];
  if (input.restaurantId) {
    scopes.push(
      restaurantCategoryScope(input.restaurantId, input.categoryId),
    );
  }
  return scopes;
}
