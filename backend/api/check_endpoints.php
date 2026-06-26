<?php
declare(strict_types=1);

/**
 * Smart Care — endpoint static check
 * =============================================================================
 * Catches the two failure modes that bit mar.php / prn_followup.php:
 *   1. An endpoint redeclaring a function that config.php already defines
 *      (e.g. respond()) — a guaranteed fatal the moment it loads config.
 *   2. A require '…/config.php' whose relative depth doesn't actually resolve
 *      to the real config from that file's directory.
 * Also flags now-redundant explicit require of lib/ classes (the autoloader
 * handles those) as INFO.
 *
 * USAGE:
 *   php check_endpoints.php [--dir=backend/api] [--config=backend/api/config.php]
 *
 * Defaults: --dir = current directory, --config = <dir>/config.php
 * Exit code: 0 if clean, 1 if any FAIL.
 * =============================================================================
 */

$args   = parseArgs($argv);
$dir     = rtrim($args['dir'] ?? getcwd(), '/');
$configP = $args['config'] ?? ($dir . '/config.php');

if (!is_dir($dir))      { fwrite(STDERR, "Not a directory: $dir\n"); exit(2); }
if (!is_file($configP)) { fwrite(STDERR, "config.php not found: $configP\n"); exit(2); }

$configReal = realpath($configP);
$configFns  = declaredFunctions(file_get_contents($configP));
printf("config.php defines: %s\n", implode(', ', $configFns));
printf("scanning: %s\n\n", $dir);

$fails = 0;
$warns = 0;
$files = phpFiles($dir);

foreach ($files as $file) {
    $real = realpath($file);
    if ($real === $configReal) continue;                // skip config itself
    if (preg_match('#/lib/#', str_replace('\\', '/', $file))) continue; // skip lib classes

    $code  = file_get_contents($file);
    $rel   = ltrim(str_replace($dir, '', $file), '/\\');
    $lines = [];

    // --- 1. redeclared config helpers -------------------------------------
    $declared = declaredFunctions($code);
    $clash = array_values(array_intersect($declared, $configFns));
    if ($clash) {
        $fails++;
        $lines[] = ['FAIL', 'redeclares config helper(s): ' . implode(', ', $clash)
                            . '  → fatal on load; delete the local copy'];
    }

    // --- 2. config require path resolves correctly ------------------------
    $requires = configRequires($code);
    if (!$requires) {
        $warns++;
        $lines[] = ['WARN', 'no "require __DIR__ . \'…/config.php\'" found — does it load config?'];
    } else {
        foreach ($requires as $relPath) {
            $target = realpath(dirname($file) . $relPath);
            if ($target === false) {
                $fails++;
                $lines[] = ['FAIL', "config require '$relPath' does not resolve from this file's directory"];
            } elseif ($target !== $configReal) {
                $fails++;
                $lines[] = ['FAIL', "config require '$relPath' resolves to the WRONG file: $target"];
            }
        }
    }

    // --- 3. redundant explicit lib require (info only) --------------------
    if (preg_match_all('/(?:require|require_once|include|include_once)[^;\n]*lib\/[A-Za-z0-9_]+\.php/', $code, $m)) {
        foreach ($m[0] as $hit) {
            $lines[] = ['INFO', 'explicit lib require is now redundant (autoloader handles it): ' . trim($hit)];
        }
    }

    if (!$lines) {
        printf("  [ OK ] %s\n", $rel);
    } else {
        printf("  ----- %s\n", $rel);
        foreach ($lines as [$tag, $msg]) {
            printf("    [%-4s] %s\n", $tag, $msg);
        }
    }
}

printf("\n=== %d file(s) scanned · %d FAIL · %d WARN ===\n", count($files), $fails, $warns);
echo $fails === 0
    ? "No fatal collisions or broken config paths.\n"
    : "Fix the FAIL lines before deploying — each is a 500 in waiting.\n";
exit($fails ? 1 : 0);


// =============================================================================
// helpers
// =============================================================================

/** Top-level (and method) named functions declared in a chunk of PHP. */
function declaredFunctions(string $code): array
{
    $tokens = token_get_all($code);
    $fns = [];
    $n = count($tokens);
    for ($i = 0; $i < $n; $i++) {
        if (is_array($tokens[$i]) && $tokens[$i][0] === T_FUNCTION) {
            $j = $i + 1;
            // skip whitespace and a by-reference '&'
            while ($j < $n && ((is_array($tokens[$j]) && $tokens[$j][0] === T_WHITESPACE) || $tokens[$j] === '&')) {
                $j++;
            }
            if ($j < $n && is_array($tokens[$j]) && $tokens[$j][0] === T_STRING) {
                $fns[] = $tokens[$j][1];   // named function (anonymous → '(' here, skipped)
            }
        }
    }
    return array_values(array_unique($fns));
}

/** Relative paths from any `require __DIR__ . '…config.php'` lines. */
function configRequires(string $code): array
{
    preg_match_all(
        '/(?:require|require_once|include|include_once)\s+__DIR__\s*\.\s*[\'"]([^\'"]*config\.php)[\'"]/',
        $code,
        $m
    );
    return $m[1] ?? [];
}

/** Recursive list of .php files under a directory. */
function phpFiles(string $dir): array
{
    $out = [];
    $it = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS)
    );
    foreach ($it as $f) {
        if ($f->isFile() && strtolower($f->getExtension()) === 'php') {
            $out[] = $f->getPathname();
        }
    }
    sort($out);
    return $out;
}

function parseArgs(array $argv): array
{
    $out = [];
    foreach (array_slice($argv, 1) as $a) {
        if (preg_match('/^--([^=]+)=(.*)$/', $a, $m)) $out[$m[1]] = $m[2];
        elseif (preg_match('/^--(.+)$/', $a, $m))     $out[$m[1]] = true;
    }
    return $out;
}
