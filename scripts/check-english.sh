#!/usr/bin/env bash
# Refuses Vietnamese text on stdin (AGENTS.md, B11): commit messages, pull request titles and bodies are
# English. It looks for the letters only Vietnamese uses (ă, đ, ơ, ư, ĩ, ũ and the tone-marked vowels of
# U+1EA0..U+1EF9), so an accented name such as "Café" or "Zoë" passes. Prints each offending line and
# exits 1; exits 0 otherwise.
#
#   scripts/check-english.sh [--skip-comments] < text
#
# --skip-comments ignores lines that start with "#", as git does with a commit message file.
set -u

skip=0
[[ "${1:-}" == "--skip-comments" ]] && skip=1

SKIP="${skip}" perl -CSD -ne '
  next if $ENV{SKIP} && /^#/;
  if (/[\x{0102}\x{0103}\x{0110}\x{0111}\x{0128}\x{0129}\x{0168}\x{0169}\x{01A0}\x{01A1}\x{01AF}\x{01B0}\x{1EA0}-\x{1EF9}]/) {
    print STDERR "  $.: $_";
    $bad = 1;
  }
  END { exit($bad ? 1 : 0) }
'
