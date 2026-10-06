#!/usr/bin/env bash
# Installs the abstract CLI.
#
#   curl -fsSL https://abstract.inc/install.sh | bash
#
# abstract.inc forwards that request to this file. It is published, with the binaries
# and their checksums, in each release of https://github.com/abstractpbc/abstract-cli.
#
# Environment:
#   ABSTRACT_INSTALL_DIR    where the binary goes (default: ~/.local/bin)
#   ABSTRACT_VERSION        the release to install, for example 0.1.0 (default: latest)
#   ABSTRACT_DOWNLOAD_BASE  a mirror of one release's files, in place of GitHub
set -euo pipefail

REPO="abstractpbc/abstract-cli"

fail() {
	printf 'abstract install: %s\n' "$1" >&2
	exit 1
}

# The release file for this machine, for example "linux-arm64" or "linux-x64-musl".
platform() {
	local os arch libc=""
	case "$(uname -s)" in
		Darwin) os=darwin ;;
		Linux) os=linux ;;
		*) fail "this installer supports macOS and Linux, not $(uname -s)" ;;
	esac
	case "$(uname -m)" in
		arm64 | aarch64) arch=arm64 ;;
		x86_64 | amd64) arch=x64 ;;
		*) fail "no build for the processor $(uname -m)" ;;
	esac
	# A shell under Rosetta reports x86_64 on Apple silicon. The key is absent on Intel.
	if [ "$os" = darwin ] && [ "$arch" = x64 ] &&
		[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then
		arch=arm64
	fi
	# musl systems such as Alpine cannot run the glibc build.
	if [ "$os" = linux ] && ls /lib/ld-musl-* >/dev/null 2>&1; then
		libc="-musl"
	fi
	printf '%s-%s%s' "$os" "$arch" "$libc"
}

sha256_of() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | awk '{print $1}'
	else
		fail "sha256sum or shasum is needed to verify the download"
	fi
}

# The directory of one release's files. "latest" is resolved to its tag once, so the
# binary and its checksum always come from the same release.
release_base() {
	if [ -n "${ABSTRACT_DOWNLOAD_BASE:-}" ]; then
		printf '%s' "${ABSTRACT_DOWNLOAD_BASE%/}"
		return
	fi
	local tag
	if [ -n "${ABSTRACT_VERSION:-}" ]; then
		tag="v${ABSTRACT_VERSION#v}"
	else
		local resolved
		resolved="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")" ||
			fail "could not reach https://github.com/$REPO/releases/latest"
		tag="${resolved##*/}"
		case "$tag" in
			v[0-9]*) ;;
			*) fail "https://github.com/$REPO has no release yet" ;;
		esac
	fi
	printf 'https://github.com/%s/releases/download/%s' "$REPO" "$tag"
}

main() {
	command -v curl >/dev/null 2>&1 || fail "curl is needed"
	local target base file dir tmp staged expected actual version
	target="$(platform)"
	base="$(release_base)"
	file="abstract-$target"
	dir="${ABSTRACT_INSTALL_DIR:-$HOME/.local/bin}"
	# The download is proven here, beside its destination, before it replaces anything.
	# A temporary directory can be mounted noexec; the install directory cannot.
	staged="$dir/.abstract-install.$$"

	tmp="$(mktemp -d)"
	# shellcheck disable=SC2064  # expand now: both are local and gone when the trap runs
	trap "rm -rf -- '$tmp' '$staged'" EXIT

	printf 'Downloading %s/%s\n' "$base" "$file"
	curl -fsSL "$base/$file" -o "$tmp/abstract" || fail "could not download $base/$file"
	curl -fsSL "$base/checksums.txt" -o "$tmp/checksums.txt" ||
		fail "could not download $base/checksums.txt"

	expected="$(awk -v name="$file" '$2 == name {print $1}' "$tmp/checksums.txt")"
	[ -n "$expected" ] || fail "checksums.txt does not list $file"
	actual="$(sha256_of "$tmp/abstract")"
	[ "$expected" = "$actual" ] ||
		fail "checksum mismatch for $file: expected $expected, got $actual"

	mkdir -p "$dir"
	install -m 755 "$tmp/abstract" "$staged"
	if ! version="$("$staged" --version 2> /dev/null)"; then
		case "$target" in
			*-musl) fail "$file does not run here. On Alpine it needs two packages: apk add libstdc++ libgcc" ;;
			*) fail "$file does not run on this machine" ;;
		esac
	fi
	mv -f -- "$staged" "$dir/abstract"

	printf '\nabstract %s is installed at %s\n' "$version" "$dir/abstract"
	case ":$PATH:" in
		*":$dir:"*) printf 'Next: abstract login\n' ;;
		*)
			printf '%s is not on your PATH. Add it, then sign in:\n\n' "$dir"
			# shellcheck disable=SC2016  # printed for the user to run; must not expand here
			printf '  export PATH="%s:$PATH"\n  abstract login\n' "$dir"
			;;
	esac
}

main "$@"
