/** Shared date-range presets for dashboard filter popovers (browser-local calendar dates). */

export const DATE_RANGE_OPTIONS = [
    { label: 'Today', value: 'TODAY' },
    { label: 'Yesterday', value: 'YESTERDAY' },
    { label: 'This Week', value: 'THIS_WEEK' },
    { label: 'Last Week', value: 'LAST_WEEK' },
    { label: 'This Month', value: 'THIS_MONTH' },
    { label: 'Last Month', value: 'LAST_MONTH' },
    { label: 'This Quarter', value: 'THIS_QUARTER' },
    { label: 'Last Quarter', value: 'LAST_QUARTER' },
    { label: 'This Year', value: 'THIS_YEAR' },
    { label: 'Last Year', value: 'LAST_YEAR' },
    { label: 'Custom', value: 'CUSTOM' }
];

function pad2(n) {
    return String(n).padStart(2, '0');
}

export function formatDateToIso(d) {
    if (!d || !(d instanceof Date) || Number.isNaN(d.getTime())) {
        return null;
    }
    return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function cloneDate(d) {
    const x = new Date(d.getTime());
    x.setHours(0, 0, 0, 0);
    return x;
}

function startOfIsoWeek(d) {
    const x = cloneDate(d);
    const wd = x.getDay();
    const offset = wd === 0 ? -6 : 1 - wd;
    x.setDate(x.getDate() + offset);
    return x;
}

function endOfIsoWeek(d) {
    const s = startOfIsoWeek(d);
    const e = new Date(s.getTime());
    e.setDate(e.getDate() + 6);
    return e;
}

function startOfMonth(d) {
    return new Date(d.getFullYear(), d.getMonth(), 1);
}

function endOfMonth(d) {
    return new Date(d.getFullYear(), d.getMonth() + 1, 0);
}

function startOfQuarter(d) {
    const q = Math.floor(d.getMonth() / 3);
    return new Date(d.getFullYear(), q * 3, 1);
}

function endOfQuarter(d) {
    const q = Math.floor(d.getMonth() / 3);
    return new Date(d.getFullYear(), q * 3 + 3, 0);
}

/**
 * @param {string} rangeKey one of DATE_RANGE_OPTIONS value or CUSTOM
 * @returns {{ startDate: string|null, endDate: string|null }}
 */
export function calculateDateRange(rangeKey) {
    if (!rangeKey || rangeKey === 'CUSTOM') {
        return { startDate: null, endDate: null };
    }
    const today = cloneDate(new Date());
    let start;
    let end;

    switch (rangeKey) {
        case 'TODAY':
            start = cloneDate(today);
            end = cloneDate(today);
            break;
        case 'YESTERDAY': {
            const y = cloneDate(today);
            y.setDate(y.getDate() - 1);
            start = y;
            end = cloneDate(y);
            break;
        }
        case 'THIS_WEEK':
            start = startOfIsoWeek(today);
            end = endOfIsoWeek(today);
            break;
        case 'LAST_WEEK': {
            const lw = cloneDate(startOfIsoWeek(today));
            lw.setDate(lw.getDate() - 7);
            start = lw;
            end = endOfIsoWeek(lw);
            break;
        }
        case 'THIS_MONTH':
            start = startOfMonth(today);
            end = endOfMonth(today);
            break;
        case 'LAST_MONTH': {
            const lm = new Date(today.getFullYear(), today.getMonth() - 1, 1);
            start = startOfMonth(lm);
            end = endOfMonth(lm);
            break;
        }
        case 'THIS_QUARTER':
            start = cloneDate(startOfQuarter(today));
            end = cloneDate(endOfQuarter(today));
            break;
        case 'LAST_QUARTER': {
            const curQ = Math.floor(today.getMonth() / 3);
            let y = today.getFullYear();
            let q = curQ - 1;
            if (q < 0) {
                q = 3;
                y -= 1;
            }
            const fake = new Date(y, q * 3, 15);
            start = cloneDate(startOfQuarter(fake));
            end = cloneDate(endOfQuarter(fake));
            break;
        }
        case 'THIS_YEAR':
            start = new Date(today.getFullYear(), 0, 1);
            start.setHours(0, 0, 0, 0);
            end = new Date(today.getFullYear(), 11, 31);
            end.setHours(0, 0, 0, 0);
            break;
        case 'LAST_YEAR': {
            const y = today.getFullYear() - 1;
            start = new Date(y, 0, 1);
            start.setHours(0, 0, 0, 0);
            end = new Date(y, 11, 31);
            end.setHours(0, 0, 0, 0);
            break;
        }
        default:
            return { startDate: null, endDate: null };
    }

    return {
        startDate: formatDateToIso(start),
        endDate: formatDateToIso(end)
    };
}