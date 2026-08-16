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

The release-signing pipeline is **live**: every release attaches
`authorities.json.sig`, a detached Ed25519 signature over the exact
`authorities.json` bytes, produced by [`sign.sh`](./sign.sh) with the
directory root key. The matching public key is committed at
[`directory-root-pubkey.txt`](./directory-root-pubkey.txt) and pinned
in the clients.

Wire contract (same as the authority-manifest `.sig` in onym-infra):
base64 of the 64-byte raw signature, trailing newline; verifiers trim
whitespace before decoding.

Client posture:

- **Android** pins the root key in the app and **hard-refuses** an
  unsigned or tampered directory (`OkHttpKnownAuthoritiesFetcher`,
  onym-android#219). A release published without its `.sig` — or
  signed with a different key — yields no authorities on Android, and
  therefore no consent.
- **iOS** soft-verifies through `SignedAsset` today (checked when
  present, absence logged); flipping `ContractsTrust` to enforce is
  tracked on the iOS side.

The **private** root key never enters this repository, any CI secret,
or any machine that doesn't need it — it is the root of the moderation
consent trust chain and is held offline by the release manager.
Publishing rights on this repository remain a control worth
restricting (a malicious release still reaches soft-verifying
clients), but pinning means GitHub compromise alone can no longer
substitute an authority on enforcing clients.
