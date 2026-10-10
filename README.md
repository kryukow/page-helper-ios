# Page Helper for iPhone - prototype

Safari translation using a user's own ChatGPT plan. Replaces original text by default; restores the original without reloading. No server or running PC is used during translation. Compilation is verified; on-device sign-in and translation still require testing.

## Build

The manual GitHub Actions workflow runs on standard `macos-15`. It generates the Xcode project and packages an **unsigned** IPA, including the Safari extension. It needs no certificate, password, provision profile, ChatGPT token or Actions secret. It does not publish a release or upload to Apple. Standard public-repository runners are free under GitHub's current policy; storage and account restrictions still apply. Builds run on source changes to main or by manual dispatch.

Source code can be public. `scripts/check_public.py` checks the source package before building. No files from the PC translator are included. Do not copy connection.json, session.dpapi, certificates, profiles, account data or a local session into this repository. The check is a supplement to manual review, not a guarantee against all kinds of secrets.

## Sign and install

Use the owner's personal certificate and Feather or GBox. Both the application and `SafariExtension.appex` must be signed, including entitlements. Required identifiers:

- App: `com.kryukov.plustranslate`
- Safari extension: `com.kryukov.plustranslate.safari`
- Shared App Group: `group.com.kryukov.plustranslate`
- Shared Keychain Group: `group.com.kryukov.plustranslate` (provided by the registered App Group)

The App Group must belong to your Apple Developer team and be present in both provisioning profiles. The signer must preserve this group and allow the same shared keychain group in both targets. Renaming bundle identifiers or stripping entitlements may break access to the session. Compatibility with Feather/GBox has **not** been confirmed. Do not publish the certificate, private key or provisioning profiles.


Sources: https://developers.openai.com/siwc/token-sharing-open-source/sign-in and https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension.
