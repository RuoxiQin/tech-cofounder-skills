# Static site (privacy, support, account deletion pages)

Use this workflow when an app needs public web pages, most often the URLs that app
stores require:

- **App Store Connect:** a Privacy Policy URL and a Support URL for every app.
- **Google Play Console:** a privacy policy URL, and for apps where users create
  accounts, a web page where they can request account and data deletion.

Write these pages yourself as plain static files. tc only hosts them; it does not
generate or check their content. Write the privacy policy from what the app actually
collects and which services receive it (for example Firebase Auth, Firestore, Gemini),
and ask the user to review it before submitting the app. It is not legal advice.

This needs the released platform worker and CLI v0.1.17 or later. For an app created
before that release, run `tc apps create <TC_APP_ID> --fix --json` once to enable the
Firebase Hosting API on its project.

## 1. Add the pages

Put ready-to-serve files in a folder at the repository root, such as `static_site/`:

```text
static_site/
  index.html      # required
  privacy.html    # served at /privacy
  support.html    # served at /support
  delete-account.html
  style.css
```

- `index.html` is required. Other names are up to you; `/privacy` serves
  `privacy.html` (clean URLs).
- Only regular files: no symlinks or submodules. At most 1000 files and 50 MiB.
- tc runs no build step and accepts no Hosting config (`firebase.json`, redirects,
  headers). Commit the final HTML, CSS, and images.
- The folder cannot be the repository root, and everything in it is public. Keep
  source, credentials, and drafts out of it.

## 2. Declare it in the manifest

Add `static_site` to `tech_cofounder_configs.json`; `terraform` and `web_app` stay
required:

```json
"static_site": { "directory": "static_site" }
```

## 3. Declare the site and release in Terraform

The site is the default Firebase Hosting site of the app's project, served at
`https://<gcp_project>.web.app`. Add to the Terraform directory, next to the
`google_firebase_project` resource (see the Firebase section):

```hcl
variable "tc_static_site_version_name" { type = string }

resource "google_firebase_hosting_site" "default" {
  provider = google-beta
  project  = google_firebase_project.app.project
  site_id  = var.tc_project_id
}

resource "google_firebase_hosting_release" "default" {
  provider     = google-beta
  site_id      = google_firebase_hosting_site.default.site_id
  version_name = var.tc_static_site_version_name
}
```

Policy allows one site and one release. `site_id` must be the project ID, and the
release must use `var.tc_static_site_version_name` on the default live channel. Do
not set `channel_id` or a `type` other than `DEPLOY`. Declare the variable only when
the manifest has `static_site`: tc passes it only then, and Terraform rejects an
undeclared value.

## 4. Validate and deploy

Use the usual commands. `tc validate` plans with a placeholder version. On
`tc deploy`, tc reads the folder at the exact pushed commit, uploads it as a new
Hosting version, and the same Terraform apply releases it. A missing `index.html` or
a symlink fails the deploy before the container build starts.

When the deploy succeeds, `tc deploys get` shows `static_site_url`. Check each page
there, then give the user the exact URLs to enter in App Store Connect or Play Console,
for example `https://<gcp_project>.web.app/privacy`. The URLs stay the same across
deploys, so the user enters them once.
