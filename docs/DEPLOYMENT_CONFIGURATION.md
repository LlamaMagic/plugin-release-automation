# Deployment configuration

Each plugin repository uses two protected GitHub environments: `staging` and `production`.
Environment names are selected inside the reusable workflow and cannot be supplied as arbitrary
caller input.

## Secrets

Configure these secrets in both environments:

```text
REACTOR_LICENSE_BASE64
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
TENCENT_SECRET_ID
TENCENT_SECRET_KEY
```

Configure this secret only in `production` for webhook-enabled products:

```text
UPDATE_WEBHOOK_KEY
```

## Variables

Staging:

```text
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_BUCKET=<staging-bucket>
R2_PUBLIC_BASE_URL=https://<staging-download-host>
R2_OBJECT_PREFIX=plugins
TENCENT_COS_BUCKET=<bucket-with-appid>
TENCENT_COS_REGION=<region>
TENCENT_PUBLIC_BASE_URL=https://<bucket>.cos.<region>.myqcloud.com
UPDATE_PRODUCT_NAME=<exact-admin-product-id>
CALL_ADMIN_WEBHOOK=false
```

Production uses the production R2 bucket and hostname. Stable products set
`CALL_ADMIN_WEBHOOK=true`; Panda Farmer WPF must set it to `false`.

## Object layout

Immutable objects:

```text
plugins/<ProductId>/<staging|stable>/<version>/<ProductId>-<version>.zip
plugins/<ProductId>/<staging|stable>/<version>/<ProductId>-<version>.zip.sha256
```

Production also updates:

```text
plugins/<ProductId>/<ProductId>.zip
plugins/<ProductId>/<ProductId>.zip.sha256
plugins/<ProductId>/Version.txt
```

Tencent production additionally retains the existing compatibility aliases:

```text
<ProductId>/<ProductId>.zip
<ProductId>/<ProductId>.zip.sha256
<ProductId>/Version.txt
```

Staging never writes those legacy Tencent aliases.

## Required caller behavior

Caller workflows should offer manual `validate`, `staging`, and `production` dispatches. A tag push
may call `production-with-webhook`. The reusable workflow independently checks that either
production stage runs from a `v`-prefixed tag and that its numeric version matches the tag.

All external actions in the shared release workflow are pinned to full commit SHAs.
