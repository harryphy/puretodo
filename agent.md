# Agent Instructions

This project is an iOS to-do app with existing users, iCloud-synced data, and paid unlock entitlements. Treat every code change as potentially user-impacting.

Before making or accepting any code update, check the following:

1. Existing user data must not be lost, overwritten, duplicated, corrupted, or made unreachable.
   - Preserve all existing persistence keys, model identifiers, app group identifiers, iCloud key-value store keys, notification identifiers, and migration paths unless a compatible migration is implemented and verified.
   - Any data model or storage change must include a backward-compatible migration plan and a rollback-safe read path for previously shipped data.
   - Be especially careful around `DataStore`, `TodoItem`, `Category`, iCloud sync, widget shared data, reminders, and delete/move/category logic.

2. All users who have already purchased must keep their ongoing access rights.
   - Do not remove, rename, or invalidate existing product identifiers, entitlement flags, receipt checks, restore flows, or legacy unlock logic without a compatibility bridge.
   - Preserve `isAllFeaturesUnlocked` behavior and any receipt or transaction path that grants access to prior purchasers.
   - Any StoreKit or purchase-related change must verify fresh purchase, restore purchase, offline/previously-unlocked launch, and old-user entitlement scenarios.

These checks are mandatory for every update, including UI-only work. If a change might affect data or purchase rights, stop and document the compatibility strategy before editing.
