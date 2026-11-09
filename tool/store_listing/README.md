# Store listing assets

Google Play screenshots and the feature graphic, made from the app itself
with made-up sample data (no one's real journal).

```bash
flutter test tool/store_listing/screenshots_test.dart --update-goldens   # raw screens -> tool/store_listing/raw/
python3 tool/store_listing/frame.py                                      # captions -> assets/google-play/screenshots/
```

- `screenshots_test.dart` seeds about ten weeks of sample days, opens the real
  app on a 1080 × 2340 phone with the app's fonts, and captures Today, Your
  day, the Garden calendar, Metrics, Fun facts and the Year view. It lives
  outside `test/` so CI doesn't run it.
- `frame.py` puts a caption above each screen at 1080 × 1920 using headless
  Chromium (`CHROME`, or Playwright's headless shell).
- The feature graphic is `assets/feature-graphic.html` (1024 × 500), drawn with
  the app's hills scene, plants and icon; render it to
  `assets/feature-graphic.png` with a headless browser.

Play's rules: feature graphic 1024 × 500, JPEG or 24-bit PNG, no transparency;
2 to 8 phone screenshots. No prices, rankings, store badges or "#1" claims in
the artwork.
