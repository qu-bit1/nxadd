#!/usr/bin/env bash
# nxadd's tests: every scenario runs against throwaway disk images (an APFS, an exFAT and a FAT32 "drive"),
# a fake nxnative games list and a fake NX Play settings domain, so nothing real is touched.
# usage: tests/run.sh [bash to run nxadd with, default: every bash found: /bin/bash 3.2 and the one on PATH]
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
NXADD="$here/nxadd"
shells=("$@")
if [[ ${#shells[@]} -eq 0 ]]; then
  shells=(/bin/bash); other="$(command -v bash)"
  [[ "$(cd -P "$(dirname "$other")" && pwd)/bash" != /bin/bash ]] && shells+=("$other")
fi
T="$(mktemp -d /tmp/nxadd-test.XXXXXX)"; DOMAIN="org.nxadd.test.$$"
pass=0 fail=0

cleanup() {
  for v in /Volumes/NXT_TGames /Volumes/NXT_AP /Volumes/NXT_EX /Volumes/NXT_FAT; do hdiutil detach "$v" -force > /dev/null 2>&1; done
  defaults delete "$DOMAIN" > /dev/null 2>&1; rm -rf "$T"
}
trap cleanup EXIT

check() {   # check <name> <command...>: one assertion
  local n="$1"; shift
  if "$@" > /dev/null 2>&1; then pass=$((pass + 1)); printf '    \033[32m✓\033[0m %s\n' "$n"
  else fail=$((fail + 1)); printf '    \033[31m✗ %s\033[0m\n' "$n"; printf '      output:\n'; sed 's/^/        /' "$T/out" | tail -15; fi
}
has()  { grep -qF -- "$1" "$T/out"; }
code() { [[ "$(cat "$T/rc")" == "$1" ]]; }

# run <config> [answers] -- <nxadd args...>
run() {
  local cfg="$1" answers="$2"; shift 3
  printf '%b' "$answers" | env NO_COLOR=1 NXADD_CONFIG="$T/$cfg" NXADD_VOLUMES="$T/vols" NXADD_ALLOW_IMAGES=1 \
    NXADD_IMAGE_NAME=NXT_TGames NXADD_IMAGE_SIZE=1g NXADD_MARGIN_GB="${MARGIN:-0}" NXADD_NXPLAY_DOMAIN="$DOMAIN" \
    NXADD_NXNATIVE="$T/nxnative" NXADD_NXPLAY_APP="$T/NX Play.app" NXADD_NXPLAY="$T/nxplay" NXADD_VENV="$T/venv" NXADD_INTERACTIVE="${INTER-1}" NX_KEYS="$T/prod.keys" HOME="${THOME:-$HOME}" \
    "$SH" "$NXADD" "$@" > "$T/out" 2>&1
  echo $? > "$T/rc"
}

setup_world() {
  rm -rf "$T"/*; mkdir -p "$T/vols" "$T/dl" "$T/home" "$T/nxnative/dm/games/0100000000010000"
  echo "# Super Mario Odyssey (\`0100000000010000\`)" > "$T/nxnative/dm/games/0100000000010000/README.md"
  touch "$T/prod.keys"
  # a stand-in NX Play: its app folder, its nxnative checkout and Python, and an nxplay that only records its call
  mkdir -p "$T/NX Play.app" "$T/nxnative/.git" "$T/venv/bin"; ln -s "$(command -v python3)" "$T/venv/bin/python3"
  printf '#!/bin/sh\necho "nxplay $*" >> "%s/nxplay.calls"\necho "[stub] built"\n' "$T" > "$T/nxplay"; chmod +x "$T/nxplay"
  for v in /Volumes/NXT_TGames /Volumes/NXT_AP /Volumes/NXT_EX /Volumes/NXT_FAT; do hdiutil detach "$v" -force > /dev/null 2>&1; done
  hdiutil create -size 200m -fs APFS -volname NXT_AP "$T/ap.dmg" > /dev/null 2>&1
  hdiutil create -size 200m -fs ExFAT -volname NXT_EX "$T/ex.dmg" > /dev/null 2>&1
  hdiutil create -size 200m -fs MS-DOS -volname NXT_FAT "$T/fat.dmg" > /dev/null 2>&1
  for d in ap ex fat; do hdiutil attach "$T/$d.dmg" > /dev/null 2>&1; done
  ln -s /Volumes/NXT_AP "$T/vols/a_ap"; ln -s /Volumes/NXT_EX "$T/vols/b_ex"; ln -s /Volumes/NXT_FAT "$T/vols/c_fat"
  mkdir -p "$T/dl/My Dump" "$T/dl/arc" "$T/dl/Keep"
  head -c 200000 /dev/urandom > "$T/dl/My Dump/SMO [0100000000010000][v0].nsp"
  head -c 3000 /dev/urandom > "$T/dl/My Dump/SMO Upd [0100000000010800][v393216].nsp"
  echo x > "$T/dl/My Dump/.DS_Store"
  head -c 100000 /dev/urandom > "$T/dl/arc/Unknown [0100ABCD12340000][v0].nsp"; echo x > "$T/dl/arc/readme.txt"
  echo x > "$T/dl/arc/._Unknown [0100ABCD12340000][v0].nsp"
  (cd "$T/dl/arc" && 7z a -bd ../unknown.7z . > /dev/null)
  head -c 50000 /dev/urandom > "$T/dl/Keep/K [0100000000010000][v0].nsp"; echo notes > "$T/dl/Keep/notes.txt"
  python3 - "$T/dl/Ticket.nsp" <<'EOF'
import struct, sys
names = [b'0100000000010000000000000000000b.tik', b'aaaa.nca']; st = b'\0'.join(names) + b'\0'
ents = b''.join(struct.pack('<QQII', i * 10, 10, st.find(n), 0) for i, n in enumerate(names))
open(sys.argv[1], 'wb').write(b'PFS0' + struct.pack('<III', len(names), len(st), 0) + ents + st + b'X' * 20)
EOF
}

for SH in "${shells[@]}"; do
  printf '\n\033[1m%s\033[0m\n' "$("$SH" --version | head -1)"
  setup_world
  esc="$(printf '%s' "$T/dl/My Dump" | sed 's/ /\\ /g')"

  echo "  first run: APFS drive, drag a folder (escaped spaces), name from nxnative's list"
  run c1 "2\n1\n$esc\n\nn\nn\n" -- ;
  check "exits 0"                       code 0
  check "folder named from the games list" test -f "/Volumes/NXT_AP/NXGames/Super Mario Odyssey/SMO [0100000000010000][v0].nsp"
  check "update copied too"             test -f "/Volumes/NXT_AP/NXGames/Super Mario Odyssey/SMO Upd [0100000000010800][v393216].nsp"
  check "copies are identical"          cmp "$T/dl/My Dump/SMO [0100000000010000][v0].nsp" "/Volumes/NXT_AP/NXGames/Super Mario Odyssey/SMO [0100000000010000][v0].nsp"
  check "no .part left"                 bash -c "! ls '/Volumes/NXT_AP/NXGames/Super Mario Odyssey/' | grep -q part"
  check "config saved"                  grep -q "GAMES_DIR=/Volumes/NXT_AP/NXGames" "$T/c1"
  check "NX Play's folders updated"     bash -c "defaults read $DOMAIN gamesRoots | grep -q NXT_AP"
  check "download kept"                 test -f "$T/dl/My Dump/SMO [0100000000010000][v0].nsp"
  check "checks passed"                 bash -c "grep -q 'NX Play and its setup' $T/out && grep -q 'prod.keys' $T/out"
  check "no build when answered no"     test ! -e "$T/nxplay.calls"

  echo "  same files again"
  run c1 "" -- --yes "Super Mario Odyssey" "$T/dl/My Dump"
  check "nothing copied twice"          has "already here, same file"

  echo "  yes to deleting the download"
  run c1 "\ny\nn\n" -- "$T/dl/My Dump"
  check "download deleted"              test ! -e "$T/dl/My Dump/SMO [0100000000010000][v0].nsp"
  check "emptied folder removed"        test ! -e "$T/dl/My Dump"

  echo "  --delete-download keeps a folder with other files"
  run c1 "" -- --yes --delete-download Keep "$T/dl/Keep"
  check "file deleted, notes kept"      bash -c "test ! -e '$T/dl/Keep/K [0100000000010000][v0].nsp' && test -f '$T/dl/Keep/notes.txt'"

  echo "  exFAT drive: disk image created; archive of an unsupported game; own name"
  run c2 "2\n2\ny\n$T/dl/unknown.7z\nn\nMy Test\nn\nn\n" --
  check "exits 0"                       code 0
  check "image created on the drive"    test -d /Volumes/NXT_EX/NXT_TGames.sparsebundle
  check "game unpacked into the image"  test -f "/Volumes/NXT_TGames/My Test/Unknown [0100ABCD12340000][v0].nsp"
  check "readme and ._ file left out"   bash -c "test \$(ls -A '/Volumes/NXT_TGames/My Test' | wc -l) -eq 1"
  check "unsupported game flagged"      has "isn't in nxnative's games list"
  check "archive kept (default no)"     test -f "$T/dl/unknown.7z"

  echo "  image closed: reopened; title ID read from an NSP's ticket"
  hdiutil detach /Volumes/NXT_TGames > /dev/null 2>&1
  run c2 "" -- --yes "$T/dl/Ticket.nsp"
  check "exits 0"                       code 0
  check "image reopened"                test -d "/Volumes/NXT_TGames/Super Mario Odyssey"
  check "ID read from the ticket"       has "0100000000010000"

  echo "  --setup on exFAT with an image there"
  run c3 "2\n2\ny\n" -- --setup
  check "reuses the image"              grep -q "IMAGE=$T/vols/b_ex/NXT_TGames.sparsebundle\|IMAGE=/Volumes/NXT_EX/NXT_TGames.sparsebundle" "$T/c3"
  run c4 "2\n2\nn\n" -- --setup
  check "declined: plain folder"        grep -q "GAMES_DIR=/Volumes/NXT_EX/NXGames" "$T/c4"

  echo "  FAT32 without an image"
  run c5 "2\n3\nn\n" -- --setup
  check "refused (4 GB limit)"          bash -c "code() { [[ \$(cat $T/rc) == 1 ]]; }; code && grep -q 'FAT32' $T/out"

  echo "  this Mac"
  THOME="$T/home" run c6 "1\n" -- --setup
  check "~/Games chosen"                bash -c "grep -q 'GAMES_DIR=$T/home/Games' $T/c6 && test -d $T/home/Games"

  echo "  --build runs NX Play's build"
  run c1 "" -- --yes --build Built "$T/dl/Ticket.nsp"
  check "exits 0"                       code 0
  check "nxplay --build-only called"    grep -q "nxplay --build-only /Volumes/NXT_AP/NXGames/Built" "$T/nxplay.calls"
  check "says it's ready"               has "Built is ready"
  check "build log kept"                grep -q "stub" /Volumes/NXT_AP/NXGames/Built/nxadd-build.log

  echo "  missing setup: told what to fix, copies anyway, never builds"
  rm -f "$T/prod.keys" "$T/nxplay.calls"; rm -rf "$T/nxnative/.git"
  run c1 "" -- --yes --build NoKeys "$T/dl/Ticket.nsp"
  check "names the missing prod.keys"  has "no prod.keys at $T/prod.keys"
  check "names NX Play's setup"        has "NX Play's setup isn't finished"
  check "says how to fix it"           has "Install Missing"
  check "still copies"                 test -f /Volumes/NXT_AP/NXGames/NoKeys/Ticket.nsp
  check "doesn't build"                test ! -e "$T/nxplay.calls"
  check "says why not"                 has "not building"
  mkdir -p "$T/nxnative/.git"; touch "$T/prod.keys"

  echo "  failures"
  MARGIN=100000 run c1 "" -- --yes X "$T/dl/Ticket.nsp"
  check "not enough space"              has "not enough space"
  INTER= run c9 "" -- --yes X "$T/dl/Ticket.nsp"
  check "not set up, no terminal"       has "isn't set up yet"
  run c1 "" -- --yes X /nope/game.nsp
  check "missing source"                has "not found: /nope/game.nsp"
  run c1 "" -- --dry-run DryRun "$T/dl/Ticket.nsp"
  check "dry run copies nothing"        test ! -e /Volumes/NXT_AP/NXGames/DryRun
  hdiutil detach /Volumes/NXT_TGames > /dev/null 2>&1; hdiutil detach /Volumes/NXT_EX > /dev/null 2>&1
  run c2 "" -- --yes "$T/dl/Ticket.nsp"
  check "drive unplugged"               has "isn't connected"
done

printf '\n\033[1m%d passed, %d failed\033[0m\n' "$pass" "$fail"
(( fail == 0 ))
