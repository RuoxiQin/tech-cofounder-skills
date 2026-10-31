# Custom domains

Use this workflow to serve a tc app's Cloud Run service on a domain the user
already owns, such as `www.example.com`. It needs the released platform worker
with per-app deployer support; no new CLI command is required.

## 1. Ask the user to authorize the app's deployer

Google maps a domain only for an identity that owns it in Google Search Console.
tc applies each app's Terraform as that app's deployer service account:

```text
tc-deployer@<gcp_project>.iam.gserviceaccount.com
```

Read `<gcp_project>` from `resources.gcp_project` in `tc apps get <APP_ID> --json`.
Give the user the exact email and these steps:

1. Open [Google Search Console](https://search.google.com/search-console) with
   the account that owns the domain. A **Domain property** for the registered
   domain (for example `example.com`) covers `www` and other subdomains. If none
   exists, add one and complete its DNS TXT verification first.
2. Select the property and open **Settings → Users and permissions → Add user**.
3. Enter the deployer email and choose permission **Owner**. Full and Restricted
   users are not enough.
4. Keep the deployer as an owner permanently. Google checks ownership whenever
   tc creates or replaces the mapping.

Wait for the user to confirm before deploying the mapping. The agent cannot check
this grant in advance; an ownership error from the deploy means the step is
missing or used the wrong email, property, or permission.

## 2. Add the mapping to Terraform

Add one mapping per hostname. The platform requires the deployment region, the
app project as the namespace, and the app's Cloud Run service as the route;
`force_override` is not supported.

```hcl
resource "google_cloud_run_domain_mapping" "www" {
  location = var.tc_region
  name     = "www.example.com"
  metadata {
    namespace = var.tc_project_id
  }
  spec {
    route_name = google_cloud_run_v2_service.app.name
  }
}
```

A Cloud Run domain mapping cannot redirect between hostnames. To serve both
`example.com` and `www.example.com`, map both, or use the registrar's forwarding
for one of them.

When the app uses Firebase, update the same commit:

- Add the hostname to `authorized_domains` in `google_identity_platform_config`.
- Add it to the reCAPTCHA Enterprise key's allowed domains when App Check uses one.

Run `tc validate`, push, and deploy as usual. The deploy succeeds while the
certificate is still pending.

## 3. Give the user the DNS records

Read the records with the operator credential from Journey 4:

```bash
gcloud beta run domain-mappings describe --domain www.example.com \
  --region <REGION> --format 'yaml(status.resourceRecords)'
```

Tell the user to add each record exactly at the domain's DNS host. A subdomain
usually gets a `CNAME` to `ghs.googlehosted.com.`; an apex domain gets `A` and
`AAAA` records. They may need to remove a conflicting existing record for that
name. Keep the Search Console verification TXT record.

Google issues the certificate after DNS resolves, usually within an hour and
occasionally up to a day. Check progress with the same `describe` command, without
`--format`; the mapping is serving when its `Ready` condition is `True`. Then
test the app at `https://<hostname>/health` and, for Firebase apps, sign in on the
new hostname.
