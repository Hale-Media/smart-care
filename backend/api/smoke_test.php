<?php
declare(strict_types=1);

/**
 * Smart Care — API smoke test
 * =============================================================================
 * Exercises each endpoint's happy path plus its auth / validation / tenant /
 * role guards against a LIVE server. Read-only by default.
 *
 * USAGE:
 *   php smoke_test.php \
 *       --base=https://smartcareuk.uk/backend/api \
 *       --email=manager@example.com --password=secret \
 *       [--resident=12] [--foreign-resident=999] \
 *       [--carer-email=carer@x.com --carer-password=pw] \
 *       [--write]
 *
 * Or via env: SC_BASE, SC_EMAIL, SC_PASSWORD, SC_RESIDENT, SC_FOREIGN_RESIDENT,
 *             SC_CARER_EMAIL, SC_CARER_PASSWORD
 *
 *   --resident          a resident_id in the login user's home (enables the
 *                       resident-scoped GET checks). Auto-discovered if omitted.
 *   --foreign-resident  a resident_id in ANOTHER home (enables the tenant-
 *                       isolation check; expects 404).
 *   --carer-*           a non-senior account (enables the role-gate check;
 *                       expects 403 on a senior-only write).
 *   --write             run a create→supersede→soft-delete cycle on --resident.
 *                       Creates real (then deleted) care-plan rows. Off by default.
 *
 * Adjust ENDPOINT FILENAMES below to match your actual routes if they differ.
 * =============================================================================
 */

// ---- config ----------------------------------------------------------------

$LOGIN_PATH = 'auth/login.php';

// path => the file under --base. Tweak to match your deployment.
$EP = [
    'residents'      => 'residents/list.php',
    'care_plans'     => 'care_plans.php',
    'risk'           => 'risk_assessments.php',
    'interventions'  => 'care_interventions.php',
    'capacity'       => 'capacity_assessments.php',
    'dols'           => 'dols.php',
    'advance'        => 'advance_decisions.php',
    'lpa'            => 'lasting_powers.php',
    'safeguarding'   => 'safeguarding.php',
    'mar'            => 'mar.php',
    'prn'            => 'prn_followup.php',
    'cd'             => 'cd_register.php',
    'vitals'         => 'vitals/history.php',
    'incidents'      => 'incidents.php',
    'gdpr'           => 'gdpr.php',
];

$args = parseArgs($argv);
$BASE = rtrim($args['base'] ?? getenv('SC_BASE') ?: '', '/');
$EMAIL = $args['email'] ?? getenv('SC_EMAIL') ?: '';
$PASS  = $args['password'] ?? getenv('SC_PASSWORD') ?: '';
$RID   = $args['resident'] ?? getenv('SC_RESIDENT') ?: '';
$FRID  = $args['foreign-resident'] ?? getenv('SC_FOREIGN_RESIDENT') ?: '';
$CEMAIL = $args['carer-email'] ?? getenv('SC_CARER_EMAIL') ?: '';
$CPASS  = $args['carer-password'] ?? getenv('SC_CARER_PASSWORD') ?: '';
$WRITE  = isset($args['write']);

if ($BASE === '' || $EMAIL === '' || $PASS === '') {
    fwrite(STDERR, "Missing --base / --email / --password. See header for usage.\n");
    exit(2);
}

$T = new Tally();
banner("Smart Care API smoke test → $BASE" . ($WRITE ? '  (WRITE MODE)' : '  (read-only)'));

// ---- 0. authentication -----------------------------------------------------

section('Authentication');

$bad = http('POST', url($BASE, $LOGIN_PATH), null, ['email' => $EMAIL, 'password' => 'definitely-wrong-' . bin2hex(random_bytes(3))]);
$T->check('login rejects wrong password', $bad['status'], 401);

$login = http('POST', url($BASE, $LOGIN_PATH), null, ['email' => $EMAIL, 'password' => $PASS]);
$T->check('login accepts valid credentials', $login['status'], 200);
$token = $login['json']['token'] ?? null;
$me    = $login['json']['user'] ?? [];
if (!$token) {
    fwrite(STDERR, "\nCannot continue: login returned no token.\n");
    $T->summary();
    exit($T->failed ? 1 : 0);
}
printf("    logged in as: %s (role=%s, home=%s)\n",
    $me['name'] ?? '?', $me['role'] ?? '?', $me['home_id'] ?? '?');

// ---- 1. auth guards --------------------------------------------------------

section('Auth guards (a protected endpoint)');

$probe = url($BASE, $EP['care_plans']) . '?resident_id=1';
$T->check('missing token → 401', http('GET', $probe, null)['status'], 401);
$T->check('garbage token → 401', http('GET', $probe, 'not.a.jwt')['status'], 401);
$tampered = $token . 'x';
$T->check('tampered token → 401', http('GET', $probe, $tampered)['status'], 401);

// ---- resolve a resident_id for the scoped checks ---------------------------

if ($RID === '') {
    $list = http('GET', url($BASE, $EP['residents']), $token);
    foreach (['residents', 'data', 'items'] as $k) {
        if (!empty($list['json'][$k][0]['id'])) { $RID = (string) $list['json'][$k][0]['id']; break; }
    }
    if ($RID !== '') {
        printf("    auto-discovered resident_id=%s for scoped checks\n", $RID);
    } else {
        note("no --resident and none auto-discovered; skipping resident-scoped GET checks");
    }
}

// ---- 2. happy-path reads ---------------------------------------------------

section('Happy-path GETs');

$T->check('residents list', http('GET', url($BASE, $EP['residents']), $token)['status'], 200);

if ($RID !== '') {
    foreach ([
        'care plan sections' => $EP['care_plans'],
        'risk assessments'   => $EP['risk'],
        'interventions'      => $EP['interventions'],
        'capacity'           => $EP['capacity'],
        'DoLS'               => $EP['dols'],
        'advance decisions'  => $EP['advance'],
        'LPA'                => $EP['lpa'],
        'vitals'             => $EP['vitals'],
        'MAR due'            => $EP['mar'],
        'PRN follow-up'      => $EP['prn'],
    ] as $label => $file) {
        $r = http('GET', url($BASE, $file) . '?resident_id=' . $RID, $token);
        $T->check("GET $label", $r['status'], 200);
    }
    $T->check('GET safeguarding', http('GET', url($BASE, $EP['safeguarding']) . '?resident_id=' . $RID, $token)['status'], 200);
    // DoLS expiry-window compliance query
    $T->check('GET DoLS expiring=30', http('GET', url($BASE, $EP['dols']) . '?expiring=30', $token)['status'], 200);
}

// ---- 3. validation guards (non-destructive) --------------------------------

section('Validation guards (bad input → 422, nothing written)');

$T->check('care_plans GET without resident_id → 422',
    http('GET', url($BASE, $EP['care_plans']), $token)['status'], 422);
$T->check('care_plans POST empty body → 422',
    http('POST', url($BASE, $EP['care_plans']), $token, [])['status'], 422);
$T->check('risk POST invalid type → 422',
    http('POST', url($BASE, $EP['risk']), $token, ['resident_id' => (int) ($RID ?: 1), 'type' => 'not_a_tool', 'risk_level' => 'low'])['status'], 422);
$T->check('safeguarding POST invalid category → 422',
    http('POST', url($BASE, $EP['safeguarding']), $token, ['category' => 'bogus', 'description' => 'x'])['status'], 422);

// ---- 4. tenant isolation ---------------------------------------------------

section('Tenant isolation');

$T->check('non-existent resident → 404',
    http('GET', url($BASE, $EP['care_plans']) . '?resident_id=999999999', $token)['status'], 404);

if ($FRID !== '') {
    $T->check("foreign-home resident ($FRID) → 404",
        http('GET', url($BASE, $EP['care_plans']) . '?resident_id=' . $FRID, $token)['status'], 404);
} else {
    note("no --foreign-resident; skipping cross-home tenant check (the important one)");
}

// ---- 5. role gate ----------------------------------------------------------

section('Role gate (senior-only writes)');

if ($CEMAIL !== '' && $CPASS !== '') {
    $cl = http('POST', url($BASE, $LOGIN_PATH), null, ['email' => $CEMAIL, 'password' => $CPASS]);
    $ctoken = $cl['json']['token'] ?? null;
    if ($ctoken) {
        // a carer trying a senior-only safeguarding review should be 403
        $r = http('PUT', url($BASE, $EP['safeguarding']) . '?id=1&action=review', $ctoken, ['manager_review' => 'x']);
        $T->check('carer attempts senior action → 403', $r['status'], 403, '(or 404 if id 1 absent — check manually)');
    } else {
        note("carer login failed; skipping role-gate check");
    }
} else {
    note("no --carer-email/--carer-password; skipping role-gate check");
}

// ---- 6. write cycle (opt-in) -----------------------------------------------

if ($WRITE && $RID !== '') {
    section('Write cycle on resident ' . $RID . '  (create → supersede → soft-delete)');

    $create = http('POST', url($BASE, $EP['care_plans']), $token, [
        'resident_id'       => (int) $RID,
        'domain'            => 'other',
        'title'             => 'SMOKE TEST — safe to delete',
        'how_to_support_me' => 'Created by smoke_test.php; will be removed.',
    ]);
    $T->check('create care plan section → 201', $create['status'], 201);
    $newId = $create['json']['id'] ?? null;

    if ($newId) {
        $rev = http('PUT', url($BASE, $EP['care_plans']) . '?id=' . $newId, $token, [
            'how_to_support_me' => 'Revised by smoke test (supersede).',
        ]);
        $T->check('supersede on review → 200', $rev['status'], 200);
        $supId = $rev['json']['id'] ?? $newId;

        $hist = http('GET', url($BASE, $EP['care_plans']) . '?resident_id=' . $RID . '&domain=other&history=1', $token);
        $versions = is_array($hist['json']['history'] ?? null) ? count($hist['json']['history']) : 0;
        $T->check('history shows ≥2 versions', $versions >= 2 ? 1 : 0, 1, "(got $versions)");

        $del = http('DELETE', url($BASE, $EP['care_plans']) . '?id=' . $supId, $token);
        $T->check('soft-delete cleanup → 200', $del['status'], 200);
    } else {
        note("create returned no id; skipping the rest of the write cycle (manual cleanup may be needed)");
    }
} elseif ($WRITE) {
    note("--write set but no --resident; skipping write cycle");
}

// ---- summary ---------------------------------------------------------------

$T->summary();
exit($T->failed ? 1 : 0);


// =============================================================================
// helpers
// =============================================================================

function http(string $method, string $url, ?string $token, $body = null): array
{
    $ch = curl_init($url);
    $headers = ['Accept: application/json'];
    if ($token !== null) $headers[] = "Authorization: Bearer $token";
    $opts = [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_TIMEOUT        => 20,
        CURLOPT_SSL_VERIFYPEER => true,
    ];
    if ($body !== null) {
        $headers[] = 'Content-Type: application/json';
        $opts[CURLOPT_POSTFIELDS] = json_encode($body);
    }
    $opts[CURLOPT_HTTPHEADER] = $headers;
    curl_setopt_array($ch, $opts);
    $resp   = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err    = curl_error($ch);
    curl_close($ch);
    if ($err !== '') {
        return ['status' => 0, 'body' => null, 'json' => null, 'error' => $err];
    }
    return ['status' => $status, 'body' => $resp, 'json' => json_decode((string) $resp, true), 'error' => ''];
}

function url(string $base, string $path): string
{
    return $base . '/' . ltrim($path, '/');
}

function parseArgs(array $argv): array
{
    $out = [];
    foreach (array_slice($argv, 1) as $a) {
        if (preg_match('/^--([^=]+)=(.*)$/', $a, $m)) {
            $out[$m[1]] = $m[2];
        } elseif (preg_match('/^--(.+)$/', $a, $m)) {
            $out[$m[1]] = true;
        }
    }
    return $out;
}

function banner(string $s): void { echo "\n=== $s ===\n"; }
function section(string $s): void { echo "\n--- $s\n"; }
function note(string $s): void { echo "    · skip: $s\n"; }

final class Tally
{
    public int $passed = 0;
    public int $failed = 0;

    public function check(string $name, int $got, int $want, string $extra = ''): void
    {
        $ok = $got === $want;
        $ok ? $this->passed++ : $this->failed++;
        printf("  [%s] %-48s want %d  got %d %s\n", $ok ? 'PASS' : 'FAIL', $name, $want, $got, $extra);
    }

    public function summary(): void
    {
        $total = $this->passed + $this->failed;
        printf("\n=== %d/%d passed, %d failed ===\n", $this->passed, $total, $this->failed);
        if ($this->failed === 0) {
            echo "All checks green.\n";
        } else {
            echo "Investigate the FAIL lines above before going near real residents.\n";
        }
    }
}
