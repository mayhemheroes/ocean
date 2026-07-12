/* Baked-in ASan/LSan defaults for the /mayhem/pre64 file-input target.
 *
 * ocean's preprocessor is an allocate-and-exit batch tool: preprocess_file()
 * intentionally leaks its per-run internal allocations (token buffers, the
 * identifier hash map) and relies on process exit to reclaim them. Under ASan,
 * LeakSanitizer would therefore abort on EVERY input and mask the real crashes,
 * so we disable ONLY leak detection here. All other ASan checks (heap overflow,
 * use-after-free, NULL/OOB access) and the whole of UBSan stay HALTING.
 */
const char *__asan_default_options(void) { return "detect_leaks=0"; }
