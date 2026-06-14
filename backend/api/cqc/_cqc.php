<?php
// CQC Syndication API — credentials + HTTP helper.
// Get a subscription key from https://api-portal.service.cqc.org.uk (Profile page).
const CQC_BASE = 'https://api.service.cqc.org.uk/public/v1';
const CQC_SUBSCRIPTION_KEY = '44a6a9ba5ac94364ad263399aa231d5b';
const CQC_PARTNER_CODE = 'CAREPACKAGE'; // any concise code identifying your org

/// GET a CQC resource. Returns ['status'=>int, 'data'=>array, 'error'=>?string].
function cqc_get(string $path, array $query = []): array {
    $url = CQC_BASE . $path . ($query ? '?' . http_build_query($query) : '');
    $ch = curl_init($url);
    $headers = ['Accept: application/json', 'User-Agent: CarePackage/1.0'];
    if (CQC_SUBSCRIPTION_KEY !== 'PUT_YOUR_CQC_SUBSCRIPTION_KEY_HERE') {
        $headers[] = 'Ocp-Apim-Subscription-Key: ' . CQC_SUBSCRIPTION_KEY;
    }
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_SSLVERSION     => CURL_SSLVERSION_TLSv1_2,
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT        => 20,
        CURLOPT_HTTPHEADER     => $headers,
    ]);
    $body = curl_exec($ch);
    if ($body === false) {
        $err = curl_error($ch);
        curl_close($ch);
        return ['status' => 0, 'data' => [], 'error' => $err];
    }
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    $data = json_decode($body, true);
    return ['status' => $code, 'data' => is_array($data) ? $data : [], 'error' => null];
}

/// Extract overall rating + date from a location payload.
/// Handles both object format { overall: {rating,reportDate} }
/// and array format [ {keyQuestion:'Overall', rating, reportDate} ].
function cqc_overall_rating(array $l): array {
    $cr = $l['currentRatings'] ?? null;
    if (!$cr) return ['rating' => null, 'date' => null];

    // Object format
    if (isset($cr['overall'])) {
        return [
            'rating' => $cr['overall']['rating'] ?? null,
            'date'   => $cr['overall']['reportDate'] ?? null,
        ];
    }

    // Array format — find the Overall entry
    foreach ((array)$cr as $item) {
        if (!is_array($item)) continue;
        $kq = strtolower($item['keyQuestion'] ?? $item['name'] ?? '');
        if ($kq === 'overall') {
            return [
                'rating' => $item['rating'] ?? null,
                'date'   => $item['reportDate'] ?? $item['reportLinkDate'] ?? null,
            ];
        }
    }

    return ['rating' => null, 'date' => null];
}

/// Pull a flat list of location IDs from a provider payload (schema-tolerant).
function cqc_provider_location_ids(array $p): array {
    $ids = [];
    foreach (($p['locationIds'] ?? []) as $l) {
        if (is_string($l)) $ids[] = $l;
        elseif (is_array($l) && isset($l['locationId'])) $ids[] = $l['locationId'];
    }
    foreach (($p['locations'] ?? []) as $l) {
        if (is_array($l) && isset($l['locationId'])) $ids[] = $l['locationId'];
    }
    return array_values(array_unique($ids));
}
