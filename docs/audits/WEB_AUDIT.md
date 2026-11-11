# Web audit — TWO separate web projects

**Main deployed app candidate:** root `package.json` uses React 19, TypeScript 5.8, Vite 8, `src/` portal and public routes; build output `out/` in user's last local log. **Secondary project:** `web/` uses a separate `package.json`, TypeScript 7 and `web/tests/*.test.cjs` (7 test files).

The user's prior local log: `npm install` PASS, root `npm run build` PASS, root `npm run type-check` FAIL with 10 TS errors. GitHub's latest source was inspected; it already implements asynchronous Supabase query fixes and the new CMS detail page. Do not reapply older blanket patch scripts on newer remote source.

Current remote typecheck **not executed**. One remaining probable risk: `src/portal/lib/initializationError.ts` still has a parameter property incompatible with `erasableSyntaxOnly`; this patch converts it to an explicit class field.

UI baseline: root `src/index.css` uses existing color tokens with red/gold; portal `src/portal/styles.css` already uses Cairo and RTL. Existing Chinese font asset resides under `mobile/assets/fonts/NotoSansSC.otf`. Phase-one additive CSS provides Cairo and Chinese glyph fallback globally, focus indicators, consistent spacing/radius, reduced-motion rules and responsive portal refinements. Existing UI is preserved; design must still be reviewed visually on actual devices.

The main website https://www.sai-academic.com is an external deployment target, but this audit did not publish changes or confirm current live assets/Hostinger configuration. Route /page functionality and authenticated CRUD must be tested after deployment.
