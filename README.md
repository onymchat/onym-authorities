# onym-authorities

The directory of moderation authorities the Onym interface designates.
One file, [`authorities.json`](./authorities.json), read by the iOS
client at launch.

## How it is consumed

`KnownAuthoritiesFetcher` in `OnymModeration` fetches:

```
https://github.com/onymchat/onym-authorities/releases/latest/download/authorities.json
```

**That is a release asset, not a path in this tree.** Editing the file
on `main` changes nothing that any user sees. A change reaches clients
only when it is attached to a new release — which is deliberate: this
file decides which parties may judge Onym users, and it should move on
a reviewed, dated, revertible artifact rather than on a push.

## What publishing a release does

The consent gate blocks only when this directory yields entries. While
no release exists, the app runs unmoderated. **The first release is
therefore the moment moderation turns on for every user on a build that
reads this** — it is a product change, not a registration step.

## Why the key is in here

Each entry carries `operatorPublicKeyBase64`, the authority's Ed25519
operator key, base64 of the raw 32 bytes — the same key its manifest
names as `operator`.

It is duplicated here on purpose. The client verifies an authority's
verdicts against this key, not against the one it reads from the
manifest URL, so an attacker who can serve a substituted manifest
cannot also substitute the key it is checked against. That property
only holds if the value here was obtained **out of band** from the
manifest URL listed beside it — from the operator directly, or from
the running service's `/health`, not by fetching the manifest.

Note that this is base64 of the raw bytes, while the rest of the system
writes keys as `onym:key:<hex>`. Converting:

```bash
python3 -c "import base64,sys; print(base64.b64encode(bytes.fromhex(sys.argv[1])).decode())" <hex>
```

## Entry shape

```json
{
  "authorities": [
    {
      "componentId": "onym:component:<id>",
      "name": "Shown in the picker",
      "manifestURL": "https://<host>/manifest.json",
      "apiBaseURL": "https://<host>",
      "operatorPublicKeyBase64": "<base64 of 32 raw bytes>"
    }
  ]
}
```

`apiBaseURL` is optional for compatibility with entries published
before the operation surface existed; those resolve the API beside
`manifestURL`. New entries should set it explicitly.

## Adding an authority

1. Get the operator key from the operator, out of band.
2. Fetch their manifest yourself and confirm its `operator` matches,
   and that its `componentId` matches the `componentId` you are listing.
3. Read their published terms — the documents its class `definition`
   URLs point at are what users will be consenting to.
4. Add the entry, open a PR, and cut a release once it is reviewed.

## Integrity

The fetcher accepts an optional detached `.sig` alongside the asset and
is **soft-verifying** today: the release-signing pipeline is not live,
so a signature is checked when present and its absence is not fatal.
Until that changes, the only thing protecting this directory is who can
publish releases on this repository. Restrict that accordingly, and
treat it as the control it is.
