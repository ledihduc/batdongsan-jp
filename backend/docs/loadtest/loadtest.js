/**
 * ancu365 Load Test — k6 script
 *
 * Usage:
 *   # Against staging:
 *   k6 run --env TARGET_HOST=https://staging.ancu365.vn docs/loadtest/loadtest.js
 *
 *   # Against production (via Makefile):
 *   make loadtest
 *
 *   # Custom VUs / duration:
 *   k6 run --vus 100 --duration 10m --env TARGET_HOST=https://ancu365.vn docs/loadtest/loadtest.js
 *
 * Install k6:
 *   brew install k6         (macOS)
 *   sudo apt install k6     (Debian/Ubuntu)
 *   https://k6.io/docs/getting-started/installation/
 *
 * Thresholds (pass criteria):
 *   - HTTP 95th-percentile response time < 2000ms
 *   - HTTP error rate (non-2xx + timeouts) < 1%
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// ── Custom metrics ────────────────────────────────────────────────────────────
const errorRate = new Rate('http_errors');
const parcelDuration = new Trend('parcel_query_duration', true);
const searchDuration = new Trend('search_duration', true);
const districtDuration = new Trend('district_duration', true);

// ── Configuration ─────────────────────────────────────────────────────────────
const TARGET_HOST = __ENV.TARGET_HOST || 'https://ancu365.vn';

// HCMC bounding box for random coordinate generation
// SW: 10.6135, 106.4912  NE: 10.8958, 106.8304
const HCMC_LAT_MIN = 10.6135;
const HCMC_LAT_MAX = 10.8958;
const HCMC_LNG_MIN = 106.4912;
const HCMC_LNG_MAX = 106.8304;

// Sample search queries (realistic HCMC address fragments)
const SEARCH_QUERIES = [
    'Lê Lợi',
    'Nguyễn Huệ',
    'Đinh Tiên Hoàng',
    'Phạm Ngũ Lão',
    'Trần Hưng Đạo',
    'Võ Văn Tần',
    'Hai Bà Trưng',
    'Cách Mạng Tháng 8',
    'Ngô Quyền',
    'Lý Tự Trọng',
];

// ── k6 options ────────────────────────────────────────────────────────────────
export const options = {
    vus: 50,
    duration: '5m',

    thresholds: {
        // 95th percentile of ALL requests must be < 2000ms
        'http_req_duration': ['p(95)<2000'],

        // Error rate (non-2xx or timeouts) must be < 1%
        'http_errors': ['rate<0.01'],

        // Per-endpoint thresholds
        'parcel_query_duration': ['p(95)<2500'],  // parcels geo-query allowed slightly more
        'search_duration':       ['p(95)<1500'],
        'district_duration':     ['p(95)<500'],
    },

    // Ramp up gradually to avoid cold-start noise
    stages: [
        { duration: '30s', target: 10 },   // ramp up to 10 VUs
        { duration: '30s', target: 50 },   // ramp up to 50 VUs
        { duration: '3m',  target: 50 },   // hold 50 VUs for 3 min
        { duration: '30s', target: 20 },   // ramp down
        { duration: '30s', target: 0 },    // complete
    ],
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function randomFloat(min, max) {
    return Math.random() * (max - min) + min;
}

function randomElement(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function randomHcmcCoords() {
    return {
        lat: randomFloat(HCMC_LAT_MIN, HCMC_LAT_MAX).toFixed(6),
        lng: randomFloat(HCMC_LNG_MIN, HCMC_LNG_MAX).toFixed(6),
    };
}

// ── Request implementations ───────────────────────────────────────────────────

/**
 * 70% of traffic — parcel lookup by GPS coordinate
 * This is the primary user flow: tap map → get planning zone
 */
function requestParcels() {
    const { lat, lng } = randomHcmcCoords();
    const url = `${TARGET_HOST}/api/planning/parcels?lat=${lat}&lng=${lng}`;

    const res = http.get(url, {
        tags: { endpoint: 'parcels' },
        timeout: '5s',
    });

    const ok = check(res, {
        'parcels: status 2xx': (r) => r.status >= 200 && r.status < 300,
        'parcels: response not empty': (r) => r.body && r.body.length > 2,
    });

    errorRate.add(!ok);
    parcelDuration.add(res.timings.duration);
    return res;
}

/**
 * 20% of traffic — address search
 * Secondary flow: user types an address in search box
 */
function requestSearch() {
    const query = encodeURIComponent(randomElement(SEARCH_QUERIES));
    const url = `${TARGET_HOST}/api/planning/search?q=${query}`;

    const res = http.get(url, {
        tags: { endpoint: 'search' },
        timeout: '5s',
    });

    const ok = check(res, {
        'search: status 2xx': (r) => r.status >= 200 && r.status < 300,
    });

    errorRate.add(!ok);
    searchDuration.add(res.timings.duration);
    return res;
}

/**
 * 10% of traffic — district list
 * Lightweight: mobile app fetches this on startup for filter dropdown
 */
function requestDistricts() {
    const url = `${TARGET_HOST}/api/planning/districts`;

    const res = http.get(url, {
        tags: { endpoint: 'districts' },
        timeout: '5s',
    });

    const ok = check(res, {
        'districts: status 2xx': (r) => r.status >= 200 && r.status < 300,
        'districts: returns array': (r) => {
            try {
                const body = JSON.parse(r.body);
                return Array.isArray(body) && body.length > 0;
            } catch {
                return false;
            }
        },
    });

    errorRate.add(!ok);
    districtDuration.add(res.timings.duration);
    return res;
}

// ── Main VU loop ──────────────────────────────────────────────────────────────
export default function () {
    // Traffic distribution: 70% parcels / 20% search / 10% districts
    const roll = Math.random();

    if (roll < 0.70) {
        requestParcels();
    } else if (roll < 0.90) {
        requestSearch();
    } else {
        requestDistricts();
    }

    // Think time: 0.5–2s between requests (realistic mobile pacing)
    sleep(0.5 + Math.random() * 1.5);
}

// ── Setup / teardown (optional) ───────────────────────────────────────────────
export function setup() {
    console.log(`Load test target: ${TARGET_HOST}`);
    console.log('Config: 50 VUs × 5 min');
    console.log('Traffic: 70% parcels, 20% search, 10% districts');
    console.log('Thresholds: p95 < 2000ms, error rate < 1%');

    // Warm-up: verify target is reachable before load test
    const healthRes = http.get(`${TARGET_HOST}/api/health`, { timeout: '10s' });
    if (healthRes.status !== 200) {
        throw new Error(`Target unreachable: ${TARGET_HOST}/api/health returned ${healthRes.status}`);
    }
    console.log(`Health check OK: ${healthRes.status}`);
}
