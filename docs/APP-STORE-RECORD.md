# The App Store Connect record

What was declared, and why. Written when external TestFlight made Beta App
Review necessary, which is what turned these from fields into decisions.

Internal TestFlight needed none of it. External testing needs an age rating, a
privacy policy URL and export compliance, and two of those are short.

None of them is what actually held the release up. That is recorded first,
below, because it is the part that cost the most time and the part no error
message anywhere describes.

## What actually blocked external testing, which was none of the above

The declarations below were all in place and none of them was the problem. The
build was ineligible for external testing before any of them were read, and
nothing in App Store Connect said so.

**The Xcode Cloud workflow's Archive action had Distribution Preparation set to
TestFlight (Internal Testing Only).** That choice is baked into the archive at
build time, not applied afterwards. Builds made that way install normally for
internal groups, which is why everything looked healthy for weeks, and App Store
Connect excludes them from external testing and from App Store submission
without ever saying which builds it dropped or why. The external build picker
reads "No builds available" and stops there.

Build 22 had export compliance answered, a validated binary and clean metadata.
It was ineligible for that one reason. A build cannot be converted after the
fact, because the mode is fixed when the archive is made, so the fix was
switching Distribution Preparation to App Store Connect and letting the next
build run. That produced build 23, which appeared in the picker immediately.

### The diagnostic lesson

**If a processed build with no warnings will not appear somewhere, check how it
was archived before checking what is missing from the listing.**

Every error message pointed at metadata. None of them was about the cause. The
absence of a message is what should have been suspicious: a build rejected for
missing information says what is missing, and this one said nothing at all,
because from App Store Connect's point of view there was no build to talk
about. Time went into filling fields that were already correct.

### The distribution split, as it stands

Internal is automatic, through the post-action on the workflow. **External is
manual, deliberately, until one build has been through Beta App Review
cleanly.** Adding an external post-action now would send builds to review
automatically while the review path itself is still unproven, and a rejection
arriving on its own is a worse first result than a submission someone chose to
make. Once a build has cleared review, the post-action is worth adding and this
paragraph is worth deleting.

#### How each one actually reaches a phone

Internal needs nothing chosen. A push to `main` starts an Xcode Cloud build and
the workflow's TestFlight Internal post-action distributes what it produces.
Both testers get it with no further step, so the only decision involved is
whether to push.

External needs a person. A specific build is picked in App Store Connect and
added to the external group, and it can only be picked once it has cleared Beta
App Review. None of that happens as a side effect of building.

### What starts a TestFlight build, and what does not

**Bumping `CURRENT_PROJECT_VERSION` starts nothing. Pushing does.**

Stated flatly because it was got wrong on 2026-08-29, during the streak
transfer work: the version bump was described as the slow half of the release
beginning. It was not. It is a no-op for anything Xcode Cloud builds, and the
correction is the reason this section exists.

`ci_scripts/ci_post_clone.sh` rewrites that line on every Cloud build to
`CI_BUILD_NUMBER + 100`, then asserts the value landed in the generated project
and fails the build if it did not. Whatever integer is committed is overwritten
before anything compiles, which is why the delivered build numbers are in the
hundreds and the repo says 4.

The committed literal governs exactly one thing: a local `xcodebuild archive`,
where its job is to avoid reusing a number App Store Connect has permanently
reserved. Keeping it accurate is still worth doing. It is worth knowing that it
buys nothing beyond that.

A local archive cannot be uploaded in any case. `Apple Development` is the only
signing identity on this machine, so a local archive is development-signed and
App Store Connect will not accept it. Distribution runs through Xcode Cloud,
which carries its own signing, and that is the only path a build reaches
TestFlight by.

## Age rating: 9+

Apple replaced the old tiers in 2025. 12+ and 17+ are gone, replaced by 13+,
16+ and 18+, and every app had to answer a reworked question set by
31 January 2026 or have submissions blocked. The questionnaire is now content
questions answered Infrequent / Frequent / Not Present, plus capability
questions answered Present / Not Present.

| Question | Answer |
|---|---|
| Cartoon or Fantasy Violence | Not Present |
| Realistic Violence | Not Present |
| Prolonged Graphic or Sadistic Realistic Violence | Not Present |
| Guns or Other Weapons | Not Present |
| Mature or Suggestive Themes | Not Present |
| Sexual Content or Nudity | Not Present |
| Graphic Sexual Content and Nudity | Not Present |
| **Profanity or Crude Humor** | **Infrequent** |
| Horror/Fear Themes | Not Present |
| Alcohol, Tobacco, or Drug Use or References | Not Present |
| Medical or Treatment Information | Not Present |
| Health or Wellness Topics | Not Present |
| Gambling, Simulated Gambling, Contests, Loot Boxes | Not Present |
| Parental Controls, Age Assurance | Not Present |
| Unrestricted Web Access | Not Present |
| User-Generated Content | Not Present |
| Social Media, Messaging and Chat, Advertising | Not Present |

One Infrequent answer, and it is what makes this 9+ rather than 4+.

### Profanity: why Infrequent, which is the whole rating

Nothing profane is ever displayed unprompted. The found list renders only what
the player found, the summary shows counts, and the day's set is never
revealed. So there is a case for Not Present.

The case against it is stronger, and it decides the rating. **The player can
form a profane word, the app accepts it, prints it in the found list, awards
points for it, and on some days counts it toward completion.** 4+ means "no
objectionable material", and that claim is false in an app carrying a
427,290-word validation set. Under-declaring is the direction that gets a
build pulled; over-declaring costs a tier and Kids Category eligibility, which
this app was never going to use.

Measured rather than assumed, on the lists this app actually ships:

- 14 of 15 common vulgarities are in `Data/enable.txt` plus
  `Data/scowl95-additions.txt`, so they are playable.
- 3 of those 15 are in `Data/common-pool.txt`, so on some days a profane word
  is part of the scored set and counts toward "X of Y words".

**The slur denylist is not the mitigation for this, and was never meant to
be.** `scripts/lib/denylist.ts` in the web repo says so directly: general
vulgarity is "left alone: this game is culling slurs, not profanity". The
denylist itself is complete and verified, 2,888 deny rows from
`vendor/lexicon/dictionary-patch.tsv`, of which zero survive in either shipped
list. Two different questions, and only the slur one is answered by the data.

### The two arguable answers

Both rest on the same reading: **Apple's content questions ask what an app
depicts, and a dictionary definition is not a depiction.** Recorded here
because the reading is defensible rather than obvious, and someone should be
able to find the reasoning if it is ever questioned.

**Alcohol, Tobacco, or Drug Use or References: answered Not Present.** This is
the closest call on the form, because the category says "or References" and
the app does display references. `Data/etymology.tsv` is shown on the reveal
card without being asked for, and among its 799 rows `drinking` and `hangover`
carry definitions mentioning alcohol, while `medicine`, `pharmacy` and
`antidote` mention drugs in the pharmaceutical sense. Read literally,
"References" is satisfied. Read as intended, the category is about use and
depiction, and defining a word is neither. If a reviewer disagrees, this is
the answer they will disagree with, and Infrequent would move the rating to 9+
where it already sits, so the exposure is a correction rather than a problem.

**Violence: answered Not Present.** `murderer` is a source word, and its
reveal card reads "A person who commits murder." Same reasoning and a clearer
case: the app depicts nothing, it defines a word. No violence is shown,
described in action, or performed by anyone.

### User-generated content: answered Not Present

The player's typed words are shown back to that player alone. There is no
server, no account, and no path by which one person's words reach another. The
share sheet exports a spoiler-free result block through the OS at the player's
request, which is a share action rather than user-generated content in the
sense the question means.

## Export compliance: already declared in the source

`project.yml` sets `ITSAppUsesNonExemptEncryption: false` in the Info.plist,
so App Store Connect stops asking per build. The answer is honest rather than
convenient: `Package.swift` has no third-party dependencies, and there is no
`URLSession`, networking or analytics API anywhere in `App/` or
`Sources/PeachEngine/`.

## Privacy policy: <https://peachofaword.com/privacy>

Hosted on the game's own domain rather than a portfolio site, because that is
where someone looks for it, and it covers both surfaces.

**The two surfaces do not have the same story, and the page says so.** This
app makes no network calls at all and stores progress in local `UserDefaults`,
so it collects nothing and transmits nothing. The website runs Vercel Web
Analytics, which is cookieless and aggregate, but it is not nothing. A page
claiming "no analytics" across both would have been false about the web.

The matching App Privacy declaration for this app is **Data Not Collected**.
