# All Fits

A wardrobe and outfit planner built with Flutter. Add clothes, build outfits,
plan them on a calendar, track what you wear, and see simple wardrobe
statistics. Everything is stored on the device. No account or backend is needed.

## Running

```bash
flutter pub get
flutter run
flutter test
flutter analyze
```

The first launch seeds a small sample wardrobe. To turn this off, set
`AppConfig.seedSampleDataOnFirstLaunch` to `false`. You can also remove the
sample data from **Profile → Settings → Remove sample data**. Every sample
record id starts with `sample-`, and all sample data lives in
`lib/data/sample/`.

Sample items show the photos in `assets/sample/`, one per item and no two the
same (checked by `test/data/sample_photos_test.dart`). They come from Unsplash
under the Unsplash License; the photographers are credited in
`assets/sample/CREDITS.txt` and in the app under
**Settings → Licenses & photo credits**.

## Accounts

The app opens on **Log in**, with **Create an account** linked from it.
Log out is under **Profile** and **Settings → Account**.

- **Local only:** accounts live on the device. They keep several people's
  wardrobes apart on one phone; they are not a cloud login.
- **Passwords:** stored only as salted PBKDF2-HMAC-SHA256 hashes
  (50,000 iterations, computed on a background isolate).
- **Per-user data:** each account's wardrobe, outfits, calendar and settings
  are stored under its own key prefix (`user.<id>.`).
- **Existing data:** data created before accounts existed is moved to the
  first account registered on the device.
- **Going online later:** implement `AuthRepository` (for example with
  Firebase Auth) and swap it in `AppDependencies`. The UI doesn't change.

## Free and Premium

Accounts start on **Free**. **Profile → All Fits Premium** (or **Settings →
Plan**) compares the plans and upgrades or cancels.

- **Free:** up to 30 clothing items (archived ones count); everything else
  except the AI Stylist.
- **Premium:** unlimited items and the AI Stylist.
- **Checkout is simulated:** upgrading asks for confirmation and takes no
  payment. The plan is stored with the account's settings. To sell it for
  real, replace `SettingsController.startPremium` with Google Play Billing.
- The limit and price live in `AppConfig.freeWardrobeLimit` and
  `AppConfig.premiumMonthlyPrice`.

## Weather picks

Home has a **Dress for the weather** section. Set your city once and it
shows today's temperature and rain chance, a styling tip, and up to three
saved outfits that suit the day (scored by the seasons on the outfit and its
clothes, and whether it has outerwear). Weather comes from
[Open-Meteo](https://open-meteo.com), which is free and needs no API key;
only the city's coordinates are sent.

## Server (Supabase)

Accounts, wardrobe, outfits, planner and settings are stored
on [Supabase](https://supabase.com) when it is configured, and on the device
when it is not (tests always run on device).

1. Create a free project at supabase.com.
2. **SQL Editor:** paste [`supabase/schema.sql`](supabase/schema.sql) and run
   it. This creates the tables, row-level security and the `wardrobe-images`
   photo bucket. It is safe to run again, which you need to do on an
   existing project when a table is added (for example `collections`).
3. **Authentication → Sign In / Providers → Email:** turn off *Confirm email*
   so new accounts can sign in straight away (with it on, the app asks the user
   to confirm by email first).
4. **Project Settings → API Keys:** copy the project URL and the publishable
   key (the legacy `anon` key works too) into `assets/env.json`:

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

### Google login

With Supabase configured, **Log in** also shows **Continue with Google**. Like
Facebook below, it opens Google in the browser and comes back through
`com.example.allfits://login-callback`. Without Supabase the button is hidden.

1. In [Google Cloud Console](https://console.cloud.google.com/) pick or create
   a project. Under **APIs & Services → OAuth consent screen** set it up as
   *External* and add your Gmail accounts as **Test users** while it is in
   *Testing*.
2. Under **APIs & Services → Credentials → Create credentials → OAuth client
   ID** choose **Web application** (not Android: Supabase does the exchange).
   Under **Authorized redirect URIs** add
   `https://<project-ref>.supabase.co/auth/v1/callback`.
3. Copy **Client ID** and **Client secret** into Supabase **Authentication →
   Sign In / Providers → Google** and enable it.
4. In Supabase **Authentication → URL Configuration → Redirect URLs** add
   `com.example.allfits://login-callback` (already there if Facebook is set
   up).

Signing in with Google and with Facebook under the same email gives one
account, as long as both emails are verified.

### Facebook login

With Supabase configured, **Log in** also shows **Continue with Facebook**.
It opens Facebook in the browser and returns to the app through the deep link
`com.example.allfits://login-callback`. Without Supabase the button is hidden.

1. At [developers.facebook.com](https://developers.facebook.com/apps) create
   an app (use case *Authenticate and request data from users with Facebook
   Login*). Under **Facebook Login → Settings → Valid OAuth Redirect URIs**
   add `https://<project-ref>.supabase.co/auth/v1/callback`. Under
   **Use cases → Permissions** make sure `email` is added.
2. Copy **App ID** and **App Secret** (App settings → Basic) into Supabase
   **Authentication → Sign In / Providers → Facebook** and enable it.
3. In Supabase **Authentication → URL Configuration → Redirect URLs** add
   `com.example.allfits://login-callback`.
4. While the Facebook app is in *Development* mode, only its admins,
   developers and testers (App roles) can log in.

Data saved on the device before the switch is not uploaded. Free projects
pause after a week without use; resume them from the dashboard.

## AI stylist

**Outfits → ✨** opens the AI Stylist (Premium). It suggests three outfits built from
your own wardrobe, which you can save or open in the outfit builder.

Copy `assets/env.example.json` to `assets/env.json` (ignored by git), paste
your key into it, and restart the app. No run arguments are needed, so it
works from Android Studio, VS Code and `flutter run` alike. Without the file
the stylist screen explains how to set it up.

```json
{
  "OPENAI_API_KEY": "your-key",
  "AI_BASE_URL": "https://generativelanguage.googleapis.com/v1beta/openai",
  "AI_MODEL": "gemini-flash-lite-latest"
}
```

- **Provider:** any OpenAI-compatible chat completions API. The example
  above is Google Gemini. Leave out `AI_BASE_URL` and `AI_MODEL` to use
  OpenAI with `gpt-4o`.
- **Muse Spark first (optional):** add `MUSE_API_KEY` from
  [dev.meta.ai](https://dev.meta.ai) (and optionally `MUSE_MODEL`, default
  `muse-spark-1.3`). Chat then goes to Meta's Muse Spark first and switches
  to the Gemini settings above whenever Muse is out of credits (402) or
  quota (429). Try-on pictures always use Gemini.
- **What is sent:** item names, brands, categories, colors, seasons and wear counts,
  plus the occasion and note you type. Photos are never sent.
- **API key:** the file is bundled into the app, so use it for development
  and demos only. Put a backend proxy in front before publishing.
- **Credit:** the request pattern (chat completions with a strict JSON
  schema) follows `ClothingCategorization.ts` in
  [zebangeth/ai-closet](https://github.com/zebangeth/ai-closet) (MIT).

## Architecture

```
lib/
├── main.dart                 Bootstraps AppDependencies and runs the app
├── app/                      App root, per-user session, routes, DI root, startup, theme
├── core/                     Constants, utils, errors, extensions, shared widgets
├── data/
│   ├── models/               ClothingItem, Outfit, OutfitCalendarEntry, WardrobeStats, enums
│   ├── local/                Key-value storage, JSON collection store, image storage, image picker
│   ├── remote/               AI stylist, weather and Supabase backend
│   ├── repositories/         Repository interfaces + local implementations
│   └── sample/               Optional demo data
├── features/
│   ├── auth/                 Login, register, AuthController, logout flow
│   ├── home/ wardrobe/ outfits/ planner/ insights/ profile/ settings/ stylist/
│   │                         premium/ weather/
│   └── shared/               ClosetActions (cross-entity logic) and ClosetFlows (UI flows)
└── navigation/               Bottom-navigation shell
```

- **State:** `provider` with one `ChangeNotifier` controller per domain
  (`WardrobeController`, `OutfitController`, `PlannerController`,
  `SettingsController`). Operations that touch several domains live in
  `ClosetActions`, for example marking an outfit worn (calendar, outfit and
  item wear counts) or deleting an item (removing it from outfits).
- **Persistence:** repositories write JSON through `LocalStorageService`,
  backed by `shared_preferences`. Malformed records are skipped, and a
  corrupt payload is backed up before anything overwrites it.
- **Images:** `ImageStorageService` copies picked photos into app storage and
  returns a *relative* reference, so paths survive restarts. `image_picker`
  downscales photos to 1600 px at 85 % quality.
- **Extension points:** swap the implementations in `AppDependencies` to add
  cloud sync, Firebase/Supabase or remote image storage. Wrap
  `ImagePickerService` to add AI clothing detection.

## Android build note

`android/gradle.properties` sets `kotlin.incremental=false`. On Windows, the
pub cache and the project can be on different drives, and Kotlin's
incremental cache then fails to compile plugin sources.
