export class SupabaseInitializationError extends Error {
  constructor(message: string, readonly cause?: unknown) {
    super(message);
    this.name = "SupabaseInitializationError";
  }
}
