# Test Mode demo shell

A small iPad app that plays the native side of Test Mode for a walkthrough. It loads the Test Mode web files from its own bundle and reproduces the self-lock flow: the **Confirm App Self-Lock** alert, the "now locked" banner, and the "no longer locked" banner.

The lock is a simulation. The alert and banners look like the real ones, but nothing actually locks the iPad.

This repo has **no Test Mode web files or icons**. The app on its own shows a message asking for them.

## Make the demo IPA

1. Download the shell IPA from the latest release.
2. Run the merge script with your own Test Mode IPA:

   ```
   python3 tools/make_demo_ipa.py TestMode.ipa TestModeDemo.ipa TestModeDemo-full.ipa
   ```

3. Sign and install `TestModeDemo-full.ipa` with Feather, Sideloadly or AltStore.

Bundle id: `com.testmodedemo.app`, so it installs next to the real Test Mode.

## How it builds

Every push to `main` builds an unsigned IPA on GitHub Actions and publishes it as a release. The same IPA is also saved on the `ci-ipa` branch.
