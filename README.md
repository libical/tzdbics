# IANA Time Zone Database to iCalendar Translation Database

This repo tracks releases of the [IANA Time Zone Database](https://www.iana.org/time-zones) together with the corresponding translations to the iCalendar format (as defined in RFC 5545).

The translation is performed using [libical's VZIC utility](https://github.com/libical/vzic).

## Updating to a new release of the Time Zone Database

The intended usage is as follows:
* Upon a new release of the IANA Time Zone Database update `settings.config`. Update `VZIC_RELEASE_NAME` to match the name of the new release (e.g. `2022a`).
* Commit and push the change to GitHub.

This will trigger a GitHub Workflow that does the following
* Download the specified version of the IANA Time Zone DB.
* Checkout, build and run vzic
* Merge the newly generated zoneinfo with the previous version, in order to keep TZIDs of unchanged time zones.
* Commit and push the updated tzdata and zoneinfo back to the repo on GitHub.

## Creating a release

To create a new release:

* Bump and push `VZIC_RELEASE_NAME` as outlined above.
* Create a tag named `release_$VZIC_RELEASE_NAME` on the commit created by GitHub Actions.
* Create a GitHub release with the same name on the new tag.
  * Add the build artifacts from the automatic build (should be `tzdata$VZIC_RELEASE_NAME.tar.gz` and `zoneinfo-$VZIC_RELEASE_NAME.tar.gz`).
