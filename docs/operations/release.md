# Release runbook

How one committed revision becomes a signed, notarized DMG with a signed update feed, and what must be true before that. The rules an agent must never break are B8 and B9 in [AGENTS.md](../../AGENTS.md); this page holds the steps and the reasons. Decisions behind it: SV11, SV13 and SV14 in the [SV ledger](../specs/2026-11-07-core-port-and-spacevibe-identity-decisions.md).

Nothing here publishes anything. [`release.sh`](../../scripts/release.sh) stops after writing the artifacts and prints the tag, the push and `gh release create`, which the owner runs by hand.

## Before the first SpaceVibe release

These are one-time steps. Until all three are done, `release.sh` refuses; delete this section when they are.

1. **Create the new update key.** `Resources/Info.plist` still carries the key of the old Sparkle account `dev.spacevibe.reins`, which belongs to the deprecated v0.1.0 and is never used for the new bundle. The owner creates the new pair once, with `.build/artifacts/sparkle/Sparkle/bin/generate_keys --account dev.spacevibe.app`, pastes the printed public key into `SUPublicEDKey` in [Info.plist](../../Resources/Info.plist), and backs the private half up at once with `generate_keys --account dev.spacevibe.app -x <file>` into the password manager. Agents never run `generate_keys`: it writes the Keychain.
2. **Flip the signing account.** Set `SIGNING_ACCOUNT` in [`generate-update-feed.sh`](../../scripts/generate-update-feed.sh) and `SPARKLE_ACCOUNT` in [`test-update.sh`](../../scripts/test-update.sh) to `dev.spacevibe.app`. Then delete the `DEPRECATED_UPDATE_KEY` constant and the check against it in [`check-update-key.sh`](../../scripts/check-update-key.sh).
3. **Raise both version keys.** Info.plist holds `CFBundleShortVersionString` 0.1.0 and `CFBundleVersion` 1, the values the `v0.1.0` tag was cut from. `release.sh` derives the tag from the version and stops at "Tag v0.1.0 already exists" until the version is raised, and it refuses a build number that is not above the last tag's.

## Preconditions for every release

| What | Why the script refuses without it |
| --- | --- |
| The tree is clean (`git status --porcelain` is empty) and the revision to ship is `HEAD` of `main` | The artifact is built from `git archive HEAD` in a temporary folder, so it equals one committed revision. The script checks the tree, not the branch name: being on `main` is the rule of B9, not something the script enforces |
| `SUPublicEDKey` in the archived Info.plist is the new account's key | [`check-update-key.sh`](../../scripts/check-update-key.sh) runs on the archived plist before any build, signing or notarizing step and exits 1 on the deprecated key, a missing key or an empty one |
| `CFBundleShortVersionString` names a tag that does not exist yet, and `CFBundleVersion` is a whole number above the build number of the last `v*` tag | `CFBundleVersion` is the number Sparkle compares; a build number that is not above the last one would never be offered to installed copies |
| The Developer ID identity is in the login keychain (name overridable with `SPACEVIBE_SIGNING_IDENTITY`) | A release is signed with a secure timestamp; ad-hoc signing is for development builds only |
| `SPACEVIBE_NOTARY_PROFILE` names a `notarytool` Keychain profile, created once with `xcrun notarytool store-credentials` (`--notarize` only) | Notarization runs through that profile |
| The Keychain holds the private half of `SUPublicEDKey` under the signing account | [`generate-update-feed.sh`](../../scripts/generate-update-feed.sh) compares the Keychain's public key with Info.plist and writes no appcast when they differ |

## Steps

1. Raise `CFBundleShortVersionString` and `CFBundleVersion` in [Info.plist](../../Resources/Info.plist) and commit.
2. Optional local candidate: `scripts/release.sh --prepare`. It signs with a timestamp but does not notarize and writes no appcast; its `status.txt` says "NOT NOTARIZED". Never publish it.
3. `SPACEVIBE_NOTARY_PROFILE=<profile> scripts/release.sh --notarize`. It runs [`build-app.sh --distribution`](../../scripts/build-app.sh) on the archived revision, notarizes and staples the app, builds and signs the DMG, notarizes and staples the DMG, and writes the signed `appcast.xml`. Anything but "Accepted" from notarization stops the release.
4. The artifacts are in `build/distribution/<tag>-<short revision>/`: the DMG, `SHA256SUMS`, `appcast.xml`, the two notarization reports, `revision.txt` and `status.txt`. The script refuses to overwrite that folder; remove it to package the same revision again.
5. Publish by hand, in the order the script prints: tag and push, then `gh release create <tag> <dmg> <appcast.xml>`, then download the DMG from the release page on another Mac, open it and launch the app once before announcing.

## The update feed and the repository

Shipped copies read the feed at `https://github.com/mxrsv/spacevibe/releases/latest/download/appcast.xml`. `GITHUB_REPO` in [`release.sh`](../../scripts/release.sh) is the one constant behind that URL, and it is a working value until the owner settles the repository name (open item D-1 of the SV ledger, gate GH1 of the [go-core plan](../plans/2026-11-07-go-core-and-spacevibe-identity.md)).

- Every GitHub release carries the DMG plus an asset named exactly `appcast.xml`.
- The repository must stay public under the name baked into shipped copies, or installed copies stop updating.
- `SPACEVIBE_UPDATE_FEED_URL` and `SPACEVIBE_DOWNLOAD_PREFIX` override the feed URL and the download prefix for a test feed.
- v0.1.0 copies (bundle id `dev.spacevibe.reins`) are not updated to the new app (SV11); that release stays, marked deprecated (SV14).

## The update signing key

The private half of `SUPublicEDKey` lives in the owner's login Keychain under the Sparkle account `dev.spacevibe.app`.

- **Never regenerate the key once a release has shipped.** Installed copies verify every update against the public key they were built with and would refuse every later update.
- **Moving to another machine:** export with `generate_keys --account dev.spacevibe.app -x <file>` and import with `-f <file>`.
- **No build with the deprecated key may ship.** That is the reason `check-update-key.sh` runs first.
- `Sparkle` is linked by the `SpaceVibe` target only, and [`build-app.sh`](../../scripts/build-app.sh) signs Sparkle's helpers inside out before the app.

## Testing the update path

[`scripts/test-update.sh`](../../scripts/test-update.sh) runs the whole path through a feed on 127.0.0.1: an update with a wrong signature is refused, one with the right signature installs. It needs the Developer ID identity and no running SpaceVibe.
