# Asset inventory — observed and not yet verified
| Asset | Source path | Status | Notes |
|---|---|---|---|
| Official SAI logo | `mobile/assets/images/sai_logo.png` and portal assets | SOURCE PRESENT | Validate resolution and transparent backdrop on devices |
| Cairo Arabic font | `src/portal/assets/Cairo-400.ttf`, `Cairo-700.ttf` and `mobile/assets/fonts/Cairo.ttf` | SOURCE PRESENT | No font files are redistributed outside authorized repository |
| Simplified Chinese glyphs | `mobile/assets/fonts/NotoSansSC.otf` | SOURCE PRESENT | Add font fallback to web; check licensing included in existing asset docs |
| Approved design references | `mobile/assets/images/approved_reference.png`, `prototype/` | SOURCE PRESENT | Treat as references; avoid cropping/embedding in every screen |
| Android launcher icon | `mobile/android/app/src/main/res/mipmap-*` | SOURCE PRESENT | Validate Google Play adaptive/monochrome icon |
| iOS launcher icons | `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset` | SOURCE PRESENT | Confirm platform image size and transparency rules |
| Lesson audio/video | `storage.buckets.id = 'lesson-media'` | MISSING CONTENT | 0 objects; no recorded links in 20 lessons |
| Speech provider recordings/voice samples | No configured provider verified | NOT VERIFIED | Child privacy consent required |
| Offline lesson packages | No signed/offline manifests verified | MISSING | Add per-user authorized download and sync protection |
