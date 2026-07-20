const ISO_DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

export function excelDateToISODate(value) {
    if (value === null || value === undefined || value === '') {
        return null;
    }

    if (value instanceof Date && !Number.isNaN(value.getTime())) {
        return toIsoDate(value);
    }

    if (typeof value === 'number' && Number.isFinite(value)) {
        const excelEpoch = new Date(Date.UTC(1899, 11, 30));
        const converted = new Date(excelEpoch.getTime() + value * 86400000);
        if (!Number.isNaN(converted.getTime())) {
            return toIsoDateUtc(converted);
        }
        return null;
    }

    const s = String(value).trim();
    if (!s) {
        return null;
    }

    if (ISO_DATE_REGEX.test(s) && isValidIsoParts(s)) {
        return s;
    }

    const slashParts = s.split('/');
    if (slashParts.length === 3) {
        const a = Number(slashParts[0]);
        const b = Number(slashParts[1]);
        const y = Number(slashParts[2]);
        if (Number.isFinite(a) && Number.isFinite(b) && Number.isFinite(y)) {
            let day;
            let month;
            if (a > 12 && b <= 12) {
                day = a;
                month = b;
            } else if (b > 12 && a <= 12) {
                day = b;
                month = a;
            } else {
                day = a;
                month = b;
            }
            const iso = formatIso(y, month, day);
            return isValidIsoParts(iso) ? iso : null;
        }
    }

    const parsed = new Date(s);
    if (!Number.isNaN(parsed.getTime())) {
        return toIsoDate(parsed);
    }

    return null;
}

function toIsoDate(dt) {
    return formatIso(dt.getFullYear(), dt.getMonth() + 1, dt.getDate());
}

function toIsoDateUtc(dt) {
    return formatIso(dt.getUTCFullYear(), dt.getUTCMonth() + 1, dt.getUTCDate());
}

function formatIso(year, month, day) {
    const y = String(year).padStart(4, '0');
    const m = String(month).padStart(2, '0');
    const d = String(day).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function isValidIsoParts(iso) {
    const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!m) {
        return false;
    }
    const y = Number(m[1]);
    const mo = Number(m[2]);
    const d = Number(m[3]);
    const dt = new Date(y, mo - 1, d);
    return dt.getFullYear() === y && dt.getMonth() === mo - 1 && dt.getDate() === d;
}