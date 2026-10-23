#!/bin/sh

set -eu

REPO="${REPO:-MrM11235dev/workspace-create}"
# -----------------------------------------------------------------------------
BRANCH="${BRANCH:-main}"
HOST="${HOST:-github}"
BINS="${BINS:-workspace-create aes_crypt custom_dbt_run linting_dbt_models}"

if [ -z "${BASE_URL:-}" ]; then
	case "$REPO" in
		OWNER/*)
			printf 'install: REPO is still set to the placeholder "%s".\n' "$REPO" >&2
			printf '         Edit install.sh, or run: REPO=you/workspace-create sh install.sh\n' >&2
			exit 1
			;;
	esac

	case "$HOST" in
		github) BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH" ;;
		gitlab) BASE_URL="https://gitlab.com/$REPO/-/raw/$BRANCH" ;;
		*) printf 'install: unknown HOST "%s" (expected github or gitlab)\n' "$HOST" >&2; exit 1 ;;
	esac
fi
BASE_URL="${BASE_URL%/}"

[ -n "${HOME:-}" ] || { printf 'install: HOME is not set\n' >&2; exit 1; }
target_dir="$HOME/.local/bin"

mkdir -p "$target_dir"

for bin_name in $BINS; do
	src_url="$BASE_URL/bin/$bin_name"

	# Stage inside the target directory so the final move is an atomic rename on
	# the same filesystem, and so nothing is written outside the home directory.
	tmp=$(mktemp "$target_dir/.$bin_name.XXXXXX")
	trap 'rm -f "$tmp"' EXIT INT TERM

	printf 'Downloading %s...\n' "$src_url"
	if ! curl -fsSL "$src_url" -o "$tmp"; then
		printf 'install: download of %s failed (check REPO/BRANCH and that the repo is public)\n' "$bin_name" >&2
		exit 1
	fi

	# Make sure we fetched a script and not an HTML error page.
	if ! head -n 1 "$tmp" | grep -q '^#!'; then
		printf 'install: downloaded %s is not a script — aborting\n' "$bin_name" >&2
		exit 1
	fi

	chmod 755 "$tmp"
	mv "$tmp" "$target_dir/$bin_name"
	trap - EXIT INT TERM

	printf 'Installed %s to %s\n' "$bin_name" "$target_dir/$bin_name"
done

case ":$PATH:" in
	*":$target_dir:"*) ;;
	*)
		printf '\n%s is not on your PATH. Add it with:\n\n' "$target_dir"
		printf '  echo '\''export PATH="%s:$PATH"'\'' >> ~/.zshrc && exec zsh\n\n' "$target_dir"
		;;
esac

for bin_name in $BINS; do
	"$target_dir/$bin_name" --version
done
