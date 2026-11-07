# Analytics with Google Analytics 4

Every tech-cofounder app gets its own GA4 property, owned by the platform. Nobody
registers a Google Analytics account. You add the tag and the events; the user reads
the reports on the web or in the Google Analytics phone app.

This needs the released platform worker and CLI v0.1.19 or later. For an app created
before that release, run `tc apps create <TC_APP_ID> --fix --json` once to create its
property.

## 1. Find the Measurement ID

```bash
tc apps get <TC_APP_ID> --json
```

Read `analytics.measurement_id` (it looks like `G-XXXXXXXXXX`). If `analytics` is
null, run `tc apps create <TC_APP_ID> --fix --json` and check again.

The Measurement ID is public: every visitor's browser sees it. Copy it into source
once; it does not change and needs no secret, environment variable, or Terraform.

## 2. Add the tag (Next.js)

Create `web_app/src/app/analytics.ts`:

```ts
export const GOOGLE_ANALYTICS_MEASUREMENT_ID = "G-XXXXXXXXXX";

type AnalyticsParameterValue = string | number | boolean;

declare global {
  interface Window {
    dataLayer?: unknown[];
  }
}

// The parameter list only types the call; the body pushes `arguments`.
// eslint-disable-next-line @typescript-eslint/no-unused-vars
function pushToGoogleTag(..._commandArguments: unknown[]) {
  window.dataLayer ??= [];
  // gtag.js only reads the arguments object itself; an array copy is ignored.
  // eslint-disable-next-line prefer-rest-params
  window.dataLayer.push(arguments);
}

export function track(eventName: string, parameters: Record<string, AnalyticsParameterValue> = {}) {
  pushToGoogleTag("event", eventName, parameters);
}
```

Load the tag once in the root layout with the built-in `next/script`:

```tsx
import Script from "next/script";
import { GOOGLE_ANALYTICS_MEASUREMENT_ID } from "./analytics";

// Inside <body>, after {children}:
<Script src={`https://www.googletagmanager.com/gtag/js?id=${GOOGLE_ANALYTICS_MEASUREMENT_ID}`} />
<Script id="google-analytics-config">
  {`window.dataLayer = window.dataLayer || [];
function gtag() { dataLayer.push(arguments); }
gtag("js", new Date());
gtag("config", "${GOOGLE_ANALYTICS_MEASUREMENT_ID}");`}
</Script>
```

This records page views, scrolls, and outbound clicks with no further code.

## 3. Record product events

Call `track()` from client code after the action succeeds:

```ts
track("recipe_saved", { source: "editor" });
```

- Name events `object_action` in snake_case, at most 40 characters: `signup_completed`,
  `checkout_started`. Keep a small, fixed set; GA reports work best with few names.
- Do not reuse GA's automatic names (`page_view`, `scroll`, `click`, `session_start`,
  `first_visit`, `user_engagement`).
- At most 25 parameters per event; names at most 40 characters, values at most 100.
- **Never send personal data:** no emails, names, phone numbers, addresses, or user IDs.
  Use categories and counts instead.
- Custom parameters only appear in reports after the user registers them as custom
  dimensions; event counts appear without that.

## 4. Let the user see their analytics

Ask the user which Google account they want to use (any Gmail or Google Workspace
address), then grant it Viewer:

```bash
tc apps analytics-viewers add <TC_APP_ID> <google-email> --json
tc apps analytics-viewers list <TC_APP_ID> --json
tc apps analytics-viewers remove <TC_APP_ID> <google-email> --json
```

Tell the user to open https://analytics.google.com, or install the **Google Analytics**
app on iOS or Android, and sign in with that account. They see only this app.

- The **Realtime** report shows activity from the last 30 minutes within a minute or two.
- Standard reports take 24–48 hours to fill in. An empty report the same day is normal.

Viewer is the only role tc grants. Do not ask for other roles, and do not create a
separate Google Analytics account for the app.

## 5. Verify

After deploying, open the app in a browser and confirm requests to
`https://www.google-analytics.com/g/collect` whose `en` parameter is `page_view`, and
your event name after you trigger it. You cannot sign in to the user's reports;
ask them to check the Realtime report.

## 6. Privacy

Google Analytics collects usage data with a browser cookie. Update the app's privacy
policy to say so and name Google Analytics as a service provider (see
[Static site](static-site.md)), and ask the user to review it. If the app serves
visitors in the EU, UK, or Switzerland, tell the user a cookie consent banner is
expected there; tc does not provide one.
