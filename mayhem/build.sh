#!/usr/bin/env bash
#
# mayhem/build.sh — build ocean's fuzz target + the functional test oracle.
#
# ocean is a small WIP C compiler. The historically fuzzed component is its C PREPROCESSOR
# (`pre64` = parse.c + lex.c + pre.c built with -DSTANDALONE — the target NAME kept from the
# archived original Mayhemfile so run history isn't orphaned). We build:
#   1. /mayhem/pre64      the standalone preprocessor CLI (reads a source file from argv), built
#                         WITH ASan+UBSan (halting) + SanitizerCoverage + DWARF-3 — the fuzz target.
#                         Mayhem drives it file-input (`cmd: /mayhem/pre64 @@`): every input is a
#                         fresh short-lived process, so the preprocessor's frequent NULL-token
#                         crashes (a real upstream bug, e.g. lex.c:537 on a zero-token input) are
#                         caught per-process as defects instead of killing an in-process fuzzer and
#                         stalling corpus replay. An in-process libFuzzer harness over the same
#                         preprocess_file() path was tried and ran healthy-but-slow (~1 exec/s under
#                         Mayhem: replaying the accumulated corpus in-process restarts on every
#                         crash), so file-input is both faster and the historically-healthy shape.
#   2. /mayhem/bin/pre64  the same standalone preprocessor built with the project's NORMAL flags
#                         (clean, no sanitizer) — the behavioral oracle that mayhem/test.sh RUNS.
#
# NOTE: the upstream *compiler* target (ocean64) does NOT build at the current upstream tip
# (0fa0312 "wip": x64.c references struct compiler_s.cg which no longer exists), so upstream's
# tests/run.sh (which needs ocean64) cannot run additively. The oracle instead exercises the
# preprocessor — the code path that is actually fuzzed — with known-answer expansions.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC MAYHEM_JOBS

# Justified sanitizer relaxation (kept OUT of $SANITIZER_FLAGS so ASan + the rest of UBSan are still
# in force): upstream stores 16-byte-aligned `struct token` values in its own linked_list at
# misaligned addresses, so -fsanitize=alignment aborts on essentially EVERY input (it fires even on
# a valid seed at lex.c:537). Misaligned loads are harmless on x86-64, and leaving the check on would
# mask all real findings, so we disable ONLY the alignment sub-check. detect_leaks=0 is applied
# separately and narrowly via a baked-in __asan_default_options() (mayhem/asan_opts.c): ocean's
# preprocessor is an allocate-and-exit batch tool that leaks its per-run internal allocations by
# design, so LeakSanitizer would otherwise abort on every input.
UBSAN_RELAX="-fno-sanitize=alignment"

# SanitizerCoverage without a libFuzzer main (the target keeps ocean's own -DSTANDALONE main); gives
# Mayhem edge coverage on the file-input target.
COV="-fsanitize=fuzzer-no-link"

cd "$SRC"

# Preprocessor sources (the fuzzed code path). pre.c's -DSTANDALONE main() reads a source file from
# argv and calls preprocess_file(); it also pulls in the rhd HEAP_STRING/LINKED_LIST/HASH_MAP IMPLs.
PRE_SRCS=(parse.c lex.c pre.c)

# The rhd "#include "rhd/*.h"" dependency lives in a git SUBMODULE. Real CI checks it out
# (submodules: recursive), but a fresh clone without submodule contents (and the air-gapped rebuild)
# would find rhd/ empty. We ship a vendored copy of the header-only submodule under mayhem/vendor/rhd
# and put it LAST on the include path: if the submodule IS populated, its identical headers win
# (relative "rhd/..." resolves in-tree first); if it is NOT, the build still succeeds offline.
INC="-I$SRC -I$SRC/mayhem/vendor"

# 1) the fuzz target — ocean's standalone preprocessor CLI, instrumented (ASan/UBSan halting +
#    SanitizerCoverage) and carrying DWARF<4. -O0: at -O1+ clang folds the preprocessor's undefined
#    behaviour into spurious segfaults; the upstream Makefile likewise builds unoptimised.
$CC $SANITIZER_FLAGS $UBSAN_RELAX $COV $DEBUG_FLAGS -O0 -w -DSTANDALONE \
    $INC \
    "${PRE_SRCS[@]}" mayhem/asan_opts.c \
    -o /mayhem/pre64

# 2) the upstream preprocessor CLI, built with the project's NORMAL flags (clean, no sanitizer) —
#    this is what mayhem/test.sh runs as the behavioral oracle (matches upstream `make pre`).
mkdir -p /mayhem/bin
$CC -O0 -w -DSTANDALONE $INC "${PRE_SRCS[@]}" -o /mayhem/bin/pre64

echo "build.sh: built /mayhem/pre64 (fuzz target) and /mayhem/bin/pre64 oracle"
