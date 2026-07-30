# Required External Configuration

No production resources or secrets have been created or changed yet. This is the input checklist
for the deployment phase.

## GitHub

1. Re-authenticate the local CLI with `gh auth login -h github.com`.
2. The shared automation repository is
   `LlamaMagic/plugin-release-automation`. It is public and contains no secrets, allowing callers
   under both the `DomesticWarlord` and `LlamaMagic` owners to pin and use the same workflow.
3. Create a `production` environment in each plugin repository.
4. Restrict that environment to version tags and add an approval gate if the GitHub plan supports
   required reviewers for these private repositories.
5. Store deployment credentials as environment secrets, not in workflow files or chat.

GitHub documentation:

- <https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments>
- <https://docs.github.com/en/actions/concepts/security/secrets>

## Cloudflare R2

Information needed from the user:

- Cloudflare account ID.
- Desired bucket name.
- Desired public hostname, for example `downloads.example.com`.
- Desired object prefix, for example `plugins`.
- Confirmation that R2 is purchased/enabled in the account.
- Permission to create a bucket and bind the public hostname.

Secrets to create directly in each GitHub `production` environment:

- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

Non-secret environment variables:

- `R2_ENDPOINT` — normally `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`
- `R2_BUCKET`
- `R2_PUBLIC_BASE_URL`
- `R2_OBJECT_PREFIX`

Create an R2 account API token with **Object Read & Write**, scoped only to the release bucket.
Cloudflare shows the secret access key only once. A custom domain is preferred over the development
`r2.dev` hostname so cache and domain controls are available.

Cloudflare documentation:

- <https://developers.cloudflare.com/r2/api/tokens/>
- <https://developers.cloudflare.com/r2/get-started/s3/>
- <https://developers.cloudflare.com/r2/buckets/public-buckets/>

## Tencent COS

Information needed from the user:

- COS bucket name including its APPID suffix.
- COS region.
- Public base URL or custom acceleration-domain URL used by CN clients.
- Desired object prefix.
- Whether a temporary-credential provider already exists.

Preferred authentication is short-lived, least-privilege temporary credentials. If that is not
available for the first rollout, use a dedicated CAM sub-user whose policy can only upload, read,
and stat objects under the release prefix.

Secrets for a permanent-key fallback:

- `TENCENT_SECRET_ID`
- `TENCENT_SECRET_KEY`

Additional secret when temporary credentials are used:

- `TENCENT_SESSION_TOKEN`

Non-secret environment variables:

- `TENCENT_COS_BUCKET`
- `TENCENT_COS_REGION`
- `TENCENT_COS_PUBLIC_BASE_URL`
- `TENCENT_COS_OBJECT_PREFIX`

Use Tencent's official COSCLI `cp` command for the two intended files. Do not use a destructive
`sync --delete`.

Tencent documentation:

- <https://cloud.tencent.com/document/product/436/63144>
- <https://intl.cloud.tencent.com/document/product/436/43250>
- <https://intl.cloud.tencent.com/document/product/436/43256>

## Admin webhook

The webhook credential posted in the original conversation is compromised and must be rotated
before automation uses it. Do not reuse it.

Information needed from Kayla:

- Rotated webhook key, entered directly as the `UPDATE_WEBHOOK_KEY` GitHub environment secret.
- An HTTPS webhook endpoint. The current sample uses plain HTTP and must not carry the secret.
- Confirmation of the exact `product` values expected for all eight stable products.
- Confirmation of the success status code and whether calls are idempotent.
- A non-production/test product or dry-run endpoint if one is available.

The webhook remains the final step. It runs only after both clouds contain byte-identical artifacts
and both public URLs have passed verification. `PandaFarmerWPF` remains hard-disabled.

## .NET Reactor

Discovery on 2026-07-29:

- The legacy post-build path does not currently contain `dotNET_Reactor.Console.exe`.
- No Eziriz/Reactor installation was found in the standard Program Files locations or uninstall
  registry entries.
- Every scoped plugin `.nrproj` contains an embedded Reactor master key. These keys must never be
  copied into the public automation repository, workflow logs, artifacts, or handoff files.
- The user will rotate the project keys. The committed `.nrproj` files should contain an empty
  `<MasterKey />` element rather than a private value.
- Eziriz explicitly supports GitHub runners through its official install and run actions.
- Panda Auth already uses the same runner-license pattern successfully.

Information needed from the user:

- The GitHub runner license, entered directly as `REACTOR_LICENSE_BASE64` in a protected GitHub
  environment or organization secret.
- The exact Reactor version to pin, if Cat's runner license requires one.

The release job must:

1. Decode `REACTOR_LICENSE_BASE64` to `${{ runner.temp }}/license.v3lic`.
2. Install Reactor with `eziriz/dotnet-reactor-install-action@v1.0.0`, passing that file path.
3. Run `eziriz/dotnet-reactor-run-action@v1.0.0`.
4. Pass `additional_arguments: -licensed` so the job fails rather than emitting demo-mode output.
5. Package only the action's obfuscated output.

The first tagged pilot should stop after producing and validating an obfuscated Actions artifact.
Cloud uploads and the webhook should remain disabled until that boundary is verified.
