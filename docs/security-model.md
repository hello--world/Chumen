# Chumen Security Model

This document is the source of truth for Chumen's local protection model. It records the product
intent, the storage layout, and the boundaries future code must keep clear.

## Goals

- Keep proxy subscriptions, nodes, generated runtime config, controller secrets, and related local
  settings out of ordinary plaintext files.
- Prevent casual scanning, accidental folder sharing, simple backup leakage, and "熟人随手打开看看"
  from exposing proxy details.
- Keep the default app experience normal: Chumen should reopen and run without asking for a PIN
  unless the user explicitly enables app lock.
- Use one config encryption model based on mihomo's built-in age support instead of maintaining a
  separate Chumen-only encrypted file format.
- Make every security-impacting action visible through logs as well as user notifications.

## Non-Goals

- This is not a root/admin boundary.
- This is not a malware boundary when malware already runs as the same macOS user.
- This is not a high-assurance password manager design.
- Keychain is optional storage for the age private key, not the default trust anchor for Chumen's
  config protection model.

## Core Semantics

PIN has two independent meanings in Chumen:

1. PIN can protect the age private key used to decrypt local config.
2. PIN can optionally lock the application at launch.

Default behavior:

- Config files are encrypted by default.
- PIN protection for the age private key is enabled by default during first-run setup.
- App lock is off by default.
- When app lock is off, Chumen may auto-unlock the PIN-protected age private key with a local
  app-managed wrapping key so the app behaves like a normal utility.
- When app lock is on, the auto-unlock wrapping key is removed and startup must ask for the PIN.

The product rule is: PIN protection must not imply app lock. App lock is a separate opt-in switch.

## Storage Files

Default app data lives under:

```text
~/Library/Application Support/io.github.chumen.native-macos
```

Important protected files:

- `settings.json`: runtime settings. Stored with age protection when config protection is enabled.
- `profiles.json`: profile/subscription index. Stored with age protection when enabled.
- `profiles/*.yaml`: imported subscription/profile YAML. Stored with age protection when enabled.
- `chumen-runtime.yaml`: generated mihomo runtime config. Stored as age-protected data; it must not
  be left as fixed-path plaintext.
- `pin-vault.json`: PIN vault metadata and encrypted age identity payload. It must be readable
  before encrypted settings can be opened.
- `pin-auto-unlock.key`: local random wrapping key for the default no-app-lock startup path. Delete
  it whenever app lock is enabled.
- `age-identity.json`: plain local age identity, used only when the user disables PIN protection.
- `logs/sidecar.log`: application and mihomo process log output. Security/runtime notifications
  should also be written here with enough context to diagnose failures, without printing secrets.
- `ipc/*.sock` and `ipc/*.pid`: local runtime IPC and process state.

Optional Keychain entries:

- `io.github.chumen.native-macos.pin-vault` / `age-key-vault`: optional PIN vault storage.
- `io.github.chumen.native-macos.config-protection` / `storage-master-key.age-identity`: legacy or
  optional age identity storage.
- `io.github.chumen.native-macos.ai` / `llm-api-key`: AI API key storage, separate from config
  protection.

## PIN Vault Rules

- The PIN vault uses a random per-vault salt for PIN key derivation. Do not replace this with a
  fixed salt.
- The default auto-unlock path uses a random local wrapping key, not a hardcoded secret and not a
  fixed salt.
- Enabling app lock must remove the auto-unlock copy and wrapping key.
- Disabling app lock may recreate the auto-unlock copy only while the age private key is already
  unlocked.
- Older vaults without an auto-unlock copy may require one manual PIN entry; after successful unlock,
  Chumen should backfill auto-unlock if app lock is still off.
- The generated first-run PIN is visible by default because Chumen created it for the user. A hide
  toggle is still useful, but the first-run flow must not show two identical PIN fields unless the
  user switches into a custom password/confirmation flow.

## Runtime Config Rules

- Chumen is the orchestrator for mihomo commands and config generation.
- mihomo should receive only the runtime config path and environment needed for the current run.
- Any plaintext runtime material that cannot be avoided must be written only to a random temporary
  directory owned by the current session and cleaned by a dedicated cleanup path.
- The fixed Application Support runtime config path may exist, but it must contain protected data
  when config protection is enabled.
- Startup validation failures should log the command context and sanitized stderr/stdout. Do not put
  Go stack traces or secret material directly into user-facing notifications.

## AI And Search Rules

- Without a configured model endpoint/key, the assistant behaves as local search.
- Local Ollama should be the fastest setup path and should not require an API key.
- Remote OpenAI-compatible providers may require a saved key, but the key must not be shown in UI,
  logs, command output, or notifications.
- AI-generated changes are proposals only. They must be represented as temporary pending items with
  a git-like diff and require explicit user review before applying.
- AI must not directly mutate profiles, settings, rules, proxy/TUN state, system proxy state, or
  runtime reload without an explicit apply action from the user.

## Logging And Notifications

- Every user-visible security, core-start, config-decrypt, config-encrypt, import, and runtime
  failure notification should also be recorded in `logs/sidecar.log`.
- Logs should include stable labels, affected file paths when useful, and sanitized error summaries.
- Logs must not include API keys, age private keys, PINs, controller secrets, subscription URLs with
  credentials, or decrypted profile content.

## UI Contract

The first-run security flow must communicate these points immediately:

- What is protected: config files and the age private key.
- Where the age private key is saved: local file by default, Keychain optional.
- What the generated PIN is when PIN protection is enabled.
- Whether app lock is enabled.
- What happens when continuing without PIN: config files remain encrypted, but the age private key is
  stored directly in the selected location and local protection is weaker.

Do not present app lock as the default consequence of enabling PIN. Do not force a startup unlock
screen unless app lock is enabled or an older vault cannot auto-unlock and needs one migration unlock.
