#!/usr/bin/env bash
set -euo pipefail

FORCE="$([[ "${1:-}" == "--force" ]] && echo "1" || echo "0")"

# Check that current branch is main
if [ "$(git branch --show-current)" != "main" ]; then
	echo "You must be on the main branch to push a new version"
	exit 1
fi

# Get the last tag matching vX.Y.Z in the repo
last_tag=$(git tag | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)
last_tag=${last_tag#v}
if [ -z "$last_tag" ]; then
	echo "No version tags found, using 0.0.0"
	last_tag="0.0.0"
fi

# Extract the patch. minor and major versions from the last tag
patch_part=$(echo "$last_tag" | cut -d. -f3)
minor_part=$(echo "$last_tag" | cut -d. -f2)
major_part=$(echo "$last_tag" | cut -d. -f1)

if [[ "$FORCE" == "0" ]]; then
	# Ask which version to bump
	echo >&2 "Current version: $last_tag"
	echo >&2 "Which part of the version should be bumped?"
	echo >&2 "0. None (re-tag the current version)"
	echo >&2 "1. Patch (${major_part}.${minor_part}.$((${patch_part}+1)))"
	echo >&2 "2. Minor (${major_part}.$((${minor_part}+1)).0)"
	echo >&2 "3. Major ($((${major_part}+1)).0.0)"
	read -p "Enter the choice: " -n 1 -r
	echo >&2

	# Bump the version
	case $REPLY in
	0)
		;;
	1)
		patch_part=$((patch_part + 1))
		;;
	2)
		minor_part=$((minor_part + 1))
		patch_part=0
		;;
	3)
		major_part=$((major_part + 1))
		minor_part=0
		patch_part=0
		;;
	*)
		echo >&2 "Invalid choice"
		exit 1
		;;
	esac
fi

patch_version="${major_part}.${minor_part}.${patch_part}"
minor_version="${major_part}.${minor_part}"
major_version="${major_part}"

# Check if the patch version already exists, and if it does,
# error out unless --force has been passed
if git tag | grep -q "v$patch_version" && [[ "$FORCE" == "0" ]]; then
	echo "Version $patch_version already exists. Use --force to overwrite"
	exit 1
fi

# Ask for confirmation
echo >&2 "This will push v$patch_version to github, and retag v$minor_version and v$major_version."
read -p "Continue? [y/N] " -n 1 -r
echo >&2
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo >&2 "Aborted"
	exit 1
fi

# Push the changes to the main branch
git push

# Create the new tag, using -f if --force was passed, and push it to github

# shellcheck disable=SC2046
git tag "v$patch_version" $([[ "$FORCE" == "1" ]] && echo "-f")

# shellcheck disable=SC2046
git push origin "v$patch_version" $([[ "$FORCE" == "1" ]] && echo "-f")

# Now handle the tags for the minor and major versions
git tag "v$minor_version" -f
git tag "v$major_version" -f
git push origin "v$minor_version" -f
git push origin "v$major_version" -f

# Finally, create a release on github
gh release create "v$patch_version" --generate-notes --verify-tag
