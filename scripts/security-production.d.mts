export const productionRef: string;
export const productionUrl: string;
export const securityHeaders: Record<string, string>;
export function assertProductionEnvironment(env: Record<string, string | undefined>, mode?: string): void;
export function verifyProductionBundle(directory: string): string[];
