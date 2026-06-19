<?php
declare(strict_types=1);

/**
 * AuditedRepository — Smart Care
 *
 * One write path for every clinical change. Gives you, for free:
 *   - a real before/after audit trail (writes to your audit_log table)
 *   - the supersede/versioning pattern for clinical records
 *   - transaction safety (audit is written in the SAME transaction)
 *   - table + column allow-listing (table/column names can't be bound as
 *     PDO params, so they are validated to stop injection via identifiers)
 *
 * Hand-rolled PDO, no Composer. PHP 8.3 / MySQL 5.7.
 *
 * Construct it per-request from your JWT context:
 *   $repo = new AuditedRepository($pdo, $jwt['staff_id'], $jwt['home_id'], $_SERVER['REMOTE_ADDR'] ?? null);
 */
final class AuditedRepository
{
    /** Tables this repository may write to. */
    private const ALLOWED_TABLES = [
        'care_plan_sections', 'risk_assessments', 'care_interventions',
        'residents', 'medications', 'mar_entries', 'cd_register', 'vitals',
        'incidents', 'care_rounds', 'care_calls', 'handover_notes', 'alerts',
        'capacity_assessments', 'dols_authorisations', 'advance_decisions',
        'lasting_powers', 'safeguarding_concerns',
    ];

    /** Tables that support the versioned supersede pattern. */
    private const VERSIONED_TABLES = ['care_plan_sections', 'risk_assessments', 'capacity_assessments'];

    public function __construct(
        private PDO $pdo,
        private int $actorId,         // staff.id from the JWT
        private ?int $homeId = null,  // current home from the JWT
        private ?string $ip = null,
    ) {}

    // ---- public write API --------------------------------------------

    /** Insert a row, audit it as 'create', return new id. */
    public function insert(string $table, array $data, string $entity): int
    {
        $this->assertTable($table);
        return $this->tx(function () use ($table, $data, $entity): int {
            $id = $this->rawInsert($table, $data);
            $this->audit('create', $entity, $id, null, $this->rawFetch($table, $id));
            return $id;
        });
    }

    /** Update a row in place, audit before+after. Use for non-clinical
     *  or administrative fields. For clinical CONTENT use supersede(). */
    public function update(string $table, int $id, array $data, string $entity): void
    {
        $this->assertTable($table);
        $this->tx(function () use ($table, $id, $data, $entity): void {
            $before = $this->rawFetch($table, $id);
            if (in_array('updated_at', $this->columnsOf($table), true)) {
                $data['updated_at'] = $this->now();
                $data['updated_by'] = $this->actorId;
            }
            $this->rawUpdate($table, $id, $data);
            $this->audit('update', $entity, $id, $before, $this->rawFetch($table, $id));
        });
    }

    /** Soft-delete (never hard-delete clinical data). */
    public function softDelete(string $table, int $id, string $entity): void
    {
        $this->assertTable($table);
        $this->tx(function () use ($table, $id, $entity): void {
            $before = $this->rawFetch($table, $id);
            $this->rawUpdate($table, $id, [
                'deleted_at' => $this->now(),
                'deleted_by' => $this->actorId,
            ]);
            $this->audit('soft_delete', $entity, $id, $before, $this->rawFetch($table, $id));
        });
    }

    /**
     * Supersede: close the current version and insert a new one pointing
     * back to it. Clinical content is NEVER overwritten in place.
     *
     * @param array $closeOldWith extra columns to set on the old row when
     *        closing it. For care_plan_sections pass
     *        ['effective_to' => $repo->nowPublic()] to stamp the end date.
     * @return int the id of the new active version
     */
    public function supersede(
        string $table,
        string $entity,
        int $oldId,
        array $newData,
        array $closeOldWith = []
    ): int {
        $this->assertTable($table);
        if (!in_array($table, self::VERSIONED_TABLES, true)) {
            throw new InvalidArgumentException("$table is not a versioned table");
        }
        return $this->tx(function () use ($table, $entity, $oldId, $newData, $closeOldWith): int {
            $old = $this->rawFetch($table, $oldId);
            if ($old === null || ($old['status'] ?? null) !== 'active') {
                throw new RuntimeException("Cannot supersede non-active row $oldId in $table");
            }

            // 1) close the current version
            $this->rawUpdate($table, $oldId, array_merge(['status' => 'superseded'], $closeOldWith));
            $this->audit('supersede', $entity, $oldId, $old, $this->rawFetch($table, $oldId));

            // 2) insert the new version, linked back
            $newData['version_no']    = (int)($old['version_no'] ?? 1) + 1;
            $newData['supersedes_id'] = $oldId;
            $newData['status']        = 'active';
            if (in_array('created_by', $this->columnsOf($table), true)) {
                $newData['created_by'] ??= $this->actorId;   // care_plan_sections has it; risk_assessments uses assessed_by
            }
            $newId = $this->rawInsert($table, $newData);
            $this->audit('create', $entity, $newId, null, $this->rawFetch($table, $newId));

            return $newId;
        });
    }

    /** Exposed so callers can stamp matching timestamps (e.g. effective_to). */
    public function nowPublic(): string { return $this->now(); }

    // ---- internals ----------------------------------------------------

    private function audit(string $action, string $entity, int $entityId, ?array $before, ?array $after): void
    {
        $sql = 'INSERT INTO `audit_log`
                  (`staff_id`, `home_id`, `action`, `entity`, `entity_id`,
                   `ip_address`, `before_json`, `after_json`, `created_at`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';
        $this->pdo->prepare($sql)->execute([
            $this->actorId,
            $this->homeId,
            $action,
            $entity,
            $entityId,
            $this->ip,
            $before === null ? null : json_encode($before, JSON_UNESCAPED_UNICODE),
            $after  === null ? null : json_encode($after,  JSON_UNESCAPED_UNICODE),
            $this->now(),
        ]);
    }

    private function rawInsert(string $table, array $data): int
    {
        $cols = array_keys($data);
        $this->assertColumns($cols);
        $sql = sprintf(
            'INSERT INTO `%s` (%s) VALUES (%s)',
            $table,
            implode(', ', array_map(static fn($c) => "`$c`", $cols)),
            implode(', ', array_fill(0, count($cols), '?'))
        );
        $this->pdo->prepare($sql)->execute(array_values($data));
        return (int)$this->pdo->lastInsertId();
    }

    private function rawUpdate(string $table, int $id, array $data): void
    {
        $cols = array_keys($data);
        $this->assertColumns($cols);
        $set = implode(', ', array_map(static fn($c) => "`$c` = ?", $cols));
        $sql = sprintf('UPDATE `%s` SET %s WHERE `id` = ?', $table, $set);
        $this->pdo->prepare($sql)->execute([...array_values($data), $id]);
    }

    private function rawFetch(string $table, int $id): ?array
    {
        $stmt = $this->pdo->prepare(sprintf('SELECT * FROM `%s` WHERE `id` = ?', $table));
        $stmt->execute([$id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row === false ? null : $row;
    }

    /** @var array<string, string[]> cache of column names per table */
    private array $colCache = [];

    private function columnsOf(string $table): array
    {
        if (!isset($this->colCache[$table])) {
            $stmt = $this->pdo->query(sprintf('SELECT * FROM `%s` LIMIT 0', $table));
            $cols = [];
            for ($i = 0, $n = $stmt->columnCount(); $i < $n; $i++) {
                $cols[] = $stmt->getColumnMeta($i)['name'];
            }
            $this->colCache[$table] = $cols;
        }
        return $this->colCache[$table];
    }

    private function tx(callable $fn): mixed
    {
        $owns = !$this->pdo->inTransaction();
        if ($owns) {
            $this->pdo->beginTransaction();
        }
        try {
            $result = $fn();
            if ($owns) {
                $this->pdo->commit();
            }
            return $result;
        } catch (Throwable $e) {
            if ($owns && $this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }

    private function assertTable(string $table): void
    {
        if (!in_array($table, self::ALLOWED_TABLES, true)) {
            throw new InvalidArgumentException("Table not permitted: $table");
        }
    }

    private function assertColumns(array $cols): void
    {
        foreach ($cols as $c) {
            if (!is_string($c) || preg_match('/^[a-zA-Z_][a-zA-Z0-9_]*$/', $c) !== 1) {
                throw new InvalidArgumentException('Illegal column name: ' . var_export($c, true));
            }
        }
    }

    private function now(): string
    {
        return (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d H:i:s');
    }
}


/* =====================================================================
 * USAGE EXAMPLES  (delete before deploy)
 * ===================================================================== */

/*
$repo = new AuditedRepository($pdo, $jwt['staff_id'], $jwt['home_id'], $_SERVER['REMOTE_ADDR'] ?? null);

// 1) Create a care plan section
$sectionId = $repo->insert('care_plan_sections', [
    'home_id'            => $jwt['home_id'],
    'resident_id'        => 1,
    'domain'             => 'skin',
    'title'              => 'Skin integrity',
    'what_matters_to_me' => 'I do not like being disturbed at night.',
    'how_to_support_me'  => 'Reposition 2-hourly during the day, check pressure areas.',
    'review_due'         => '2026-09-01',
    'created_by'         => $jwt['staff_id'],
], 'care_plan_section');

// 2) Review changes it -> supersede (old kept, new version active)
$newSectionId = $repo->supersede(
    'care_plan_sections',
    'care_plan_section',
    $sectionId,
    [
        'home_id'           => $jwt['home_id'],
        'resident_id'       => 1,
        'domain'            => 'skin',
        'title'             => 'Skin integrity',
        'how_to_support_me' => 'Reposition 4-hourly; skin now intact, risk reduced.',
        'review_due'        => '2026-12-01',
    ],
    ['effective_to' => $repo->nowPublic()]   // stamp the old row's end date
);

// 3) Record a Waterlow risk assessment
$raId = $repo->insert('risk_assessments', [
    'home_id'     => $jwt['home_id'],
    'resident_id' => 1,
    'type'        => 'waterlow',
    'total_score' => 14,
    'risk_level'  => 'high',
    'detail'      => json_encode(['build'=>2,'continence'=>1,'skin_type'=>3,'mobility'=>2]),
    'assessed_by' => $jwt['staff_id'],
    'review_due'  => '2026-07-15',
], 'risk_assessment');

// 4) Re-assessment -> supersede (no effective_to column on this table)
$repo->supersede('risk_assessments', 'risk_assessment', $raId, [
    'home_id'     => $jwt['home_id'],
    'resident_id' => 1,
    'type'        => 'waterlow',
    'total_score' => 9,
    'risk_level'  => 'medium',
    'assessed_by' => $jwt['staff_id'],
    'review_due'  => '2026-08-15',
]);

// 5) Soft delete
$repo->softDelete('care_plan_sections', $newSectionId, 'care_plan_section');
*/
