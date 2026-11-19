import { defineConfig, loadEnv } from "vite";
import { assertProductionEnvironment, securityHeaders, verifyProductionBundle } from "./scripts/security-production.mjs";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";
import AutoImport from "unplugin-auto-import/vite";

const base = process.env.BASE_PATH || "/";
const isPreview = process.env.IS_PREVIEW ? true : false;
// https://vite.dev/config/
export default defineConfig(({ command, mode }) => {
  if (command === "build") assertProductionEnvironment({ ...loadEnv(mode, process.cwd(), ""), ...process.env }, mode);
  return {
  define: {
    __BASE_PATH__: JSON.stringify(base),
    __IS_PREVIEW__: JSON.stringify(isPreview),
    __READDY_PROJECT_ID__: JSON.stringify(process.env.PROJECT_ID || ""),
    __READDY_VERSION_ID__: JSON.stringify(process.env.VERSION_ID || ""),
    __READDY_AI_DOMAIN__: JSON.stringify(process.env.READDY_AI_DOMAIN || ""),
  },
  plugins: [
    {
      name: "sai-production-security",
      apply: "build",
      generateBundle() {
        this.emitFile({ type: "asset", fileName: "_headers", source: "/*\n" + Object.entries(securityHeaders).map(([key, value]) => `  ${key}: ${value}`).join("\n") + "\n" });
      },
      closeBundle() { verifyProductionBundle(resolve(process.cwd(), "out")); },
    },
    // ...proxyPlugins,
    react(),
    AutoImport({
      imports: [
        {
          react: [
            ["default", "React"],
            "useState",
            "useEffect",
            "useContext",
            "useReducer",
            "useCallback",
            "useMemo",
            "useRef",
            "useImperativeHandle",
            "useLayoutEffect",
            "useDebugValue",
            "useDeferredValue",
            "useId",
            "useInsertionEffect",
            "useSyncExternalStore",
            "useTransition",
            "startTransition",
            "lazy",
            "memo",
            "forwardRef",
            "createContext",
            "createElement",
            "cloneElement",
            "isValidElement",
          ],
        },
        {
          "react-router-dom": [
            "useNavigate",
            "useLocation",
            "useParams",
            "useSearchParams",
            "Link",
            "NavLink",
            "Navigate",
            "Outlet",
          ],
        },
        // React i18n
        {
          "react-i18next": ["useTranslation", "Trans"],
        },
      ],
      dts: true,
    }),
  ],
  base,
  build: {
    sourcemap: false,
    outDir: 'out',
  },
  resolve: {
    alias: {
      "@": resolve(import.meta.dirname, "./src"),
    },
  },
  server: {
    port: 3000,
    host: "0.0.0.0",
  },
  };
});
