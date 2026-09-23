# UI/UX Modifications

## 1. Sync & Authentication Interface
*   **Settings Integration:** Add a "Cloud Sync" section to the existing Settings menu.
*   **Design Language:** Strictly inherit existing theming (Classic, Minimal, Express). Do not introduce new UI libraries.
*   **Views:**
    *   `Sync Login/Register`: Minimalist form (Email, Password).
    *   `Sync Status`: Simple text element indicating "Last synced: [Time]" or "Offline".

## 2. Unobtrusive Status Indicators
*   Add a subtle sync status icon (Cloud with a checkmark, spinner, or slash) to the top AppBar or within the Settings overview.
*   Do not block user interactions during sync operations (no full-screen loading spinners).

## 3. Error Handling
*   Auth failures: Standard snackbar notification.
*   Sync failures: Silent fail (stays in local queue, retries on next network availability).