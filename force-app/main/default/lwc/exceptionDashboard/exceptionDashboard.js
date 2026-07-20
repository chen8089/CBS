import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExceptionSummary from '@salesforce/apex/ExceptionDashboardController.getExceptionSummary';
import getExceptions from '@salesforce/apex/ExceptionDashboardController.getExceptions';

const FILTER = {
    ALL: 'ALL',
    CONSENT_UPLOAD: 'CONSENT_UPLOAD',
    DEPARTURE_UPLOAD: 'DEPARTURE_UPLOAD',
    REPORT_UPLOAD: 'REPORT_UPLOAD'
};

const CARD_CONFIG = [
    { key: FILTER.ALL, label: 'All', countField: 'all' },
    { key: FILTER.CONSENT_UPLOAD, label: 'Consent Upload', countField: 'consentUpload' },
    { key: FILTER.DEPARTURE_UPLOAD, label: 'Departure Upload', countField: 'departureUpload' },
    { key: FILTER.REPORT_UPLOAD, label: 'Report Upload', countField: 'reportUpload' }
];

const SORT_FIELD_MAP = {
    exceptionFieldName: 'Exception_Field_Name__c',
    fieldValue: 'Field_Value__c',
    exceptionMessage: 'Exception_Message__c',
    source: 'Source__c',
    createdDate: 'CreatedDate',
    lastModifiedDate: 'LastModifiedDate'
};

const DEFAULT_SORT_FIELD = 'CreatedDate';
const DEFAULT_SORT_DIRECTION = 'desc';

const DATE_TYPE_CREATED = 'CreatedDate';
const DATE_TYPE_LAST_MODIFIED = 'LastModifiedDate';

export default class ExceptionDashboard extends NavigationMixin(LightningElement) {
    @api title = 'Exceptions';
    @api tableTitle = 'Exceptions';
    @api subtitle = 'Manage';

    @track summary = {
        all: 0,
        consentUpload: 0,
        departureUpload: 0,
        reportUpload: 0
    };
    @track exceptions = [];
    @track loading = true;
    @track searchInput = '';
    searchKey = '';
    searchDebounce;

    selectedFilter = FILTER.ALL;
    sortByApi = DEFAULT_SORT_FIELD;
    sortedBy = 'createdDate';
    sortDirection = DEFAULT_SORT_DIRECTION;

    @track isFilterOpen = false;
    @track filterValues = this.defaultFilters();
    @track draftFilterValues = this.defaultFilters();

    ownershipOptions = [
        { label: 'All Records', value: 'ALL' },
        { label: 'My Records', value: 'MY' }
    ];

    sourceOptions = [
        { label: 'All', value: FILTER.ALL },
        { label: 'Consent Upload', value: FILTER.CONSENT_UPLOAD },
        { label: 'Departure Upload', value: FILTER.DEPARTURE_UPLOAD },
        { label: 'Report Upload', value: FILTER.REPORT_UPLOAD }
    ];

    dateTypeOptions = [
        { label: 'Created Date', value: DATE_TYPE_CREATED },
        { label: 'Last Modified Date', value: DATE_TYPE_LAST_MODIFIED }
    ];

    dateRangeOptions = [
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

    columns = [
        {
            label: '#',
            fieldName: 'rowNumber',
            type: 'number',
            hideDefaultActions: true,
            sortable: false
        },
        {
            label: 'Exception Field Name',
            fieldName: 'exceptionFieldName',
            type: 'text',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Field Value',
            fieldName: 'fieldValue',
            type: 'text',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Exception Message',
            fieldName: 'exceptionMessage',
            type: 'text',
            wrapText: true,
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Source',
            fieldName: 'source',
            type: 'text',
            hideDefaultActions: true,
            sortable: true
        },
        {
            type: 'action',
            fixedWidth: 80,
            typeAttributes: {
                rowActions: [{ label: 'View Record', name: 'view_record' }],
                menuAlignment: 'right'
            }
        }
    ];

    connectedCallback() {
        this.loadDashboard();
    }

    get cards() {
        return CARD_CONFIG.map((card) => ({
            key: card.key,
            label: card.label,
            value: this.summary[card.countField] || 0,
            selected: this.selectedFilter === card.key,
            className: this.selectedFilter === card.key ? 'exd-card exd-card_selected' : 'exd-card'
        }));
    }

    get selectedCardLabel() {
        const card = this.cards.find((item) => item.key === this.selectedFilter);
        return card ? card.label : 'All';
    }

    get tableSubtitle() {
        const count = this.exceptions.length;
        return `${count} items · Sorted By Created Date · Filtered By ${this.selectedCardLabel}`;
    }

    get showEmpty() {
        return !this.loading && this.exceptions.length === 0;
    }

    get filterTriggerClass() {
        return this.hasActiveFilters || this.isFilterOpen
            ? 'filter-trigger-wrap filter-trigger-wrap_active'
            : 'filter-trigger-wrap';
    }

    get dateInputsDisabled() {
        return this.draftFilterValues.dateRange !== 'CUSTOM';
    }

    get hasActiveFilters() {
        const f = this.filterValues;
        return f.ownership === 'MY' || f.source !== FILTER.ALL || (f.dateType && f.startDate && f.endDate);
    }

    defaultFilters() {
        return {
            ownership: 'ALL',
            source: FILTER.ALL,
            dateType: '',
            dateRange: '',
            startDate: null,
            endDate: null
        };
    }

    cloneFilters(src = {}) {
        return {
            ownership: src.ownership || 'ALL',
            source: src.source || FILTER.ALL,
            dateType: src.dateType || '',
            dateRange: src.dateRange || '',
            startDate: src.startDate || null,
            endDate: src.endDate || null
        };
    }

    loadDashboard() {
        this.loading = true;
        Promise.all([this.loadSummary(), this.loadExceptions()])
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadSummary() {
        return getExceptionSummary().then((summary) => {
            this.summary = {
                all: summary?.all || 0,
                consentUpload: summary?.consentUpload || 0,
                departureUpload: summary?.departureUpload || 0,
                reportUpload: summary?.reportUpload || 0
            };
        });
    }

    loadExceptions() {
        return getExceptions({
            statusFilter: this.selectedFilter,
            searchKey: this.searchKey,
            sortBy: this.sortByApi,
            sortDirection: this.sortDirection,
            filters: this.cloneFilters(this.filterValues)
        }).then((rows) => {
            this.exceptions = rows || [];
        });
    }

    handleCardClick(event) {
        const key = event.currentTarget?.dataset?.filter;
        if (!key || key === this.selectedFilter) {
            return;
        }
        this.selectedFilter = key;
        this.filterValues = { ...this.filterValues, source: key };
        this.draftFilterValues = { ...this.draftFilterValues, source: key };
        this.loading = true;
        this.loadExceptions()
            .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
            .finally(() => {
                this.loading = false;
            });
    }

    handleSearchChange(event) {
        this.searchInput = event.target.value || '';
        window.clearTimeout(this.searchDebounce);
        this.searchDebounce = window.setTimeout(() => {
            this.searchKey = this.searchInput.trim();
            this.loading = true;
            this.loadExceptions()
                .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
                .finally(() => {
                    this.loading = false;
                });
        }, 300);
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortByApi = SORT_FIELD_MAP[this.sortedBy] || DEFAULT_SORT_FIELD;
        this.loading = true;
        this.loadExceptions()
            .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
            .finally(() => {
                this.loading = false;
            });
    }

    handleRefresh() {
        this.loadDashboard();
    }

    handleRowAction(event) {
        const actionName = event.detail?.action?.name;
        const row = event.detail?.row;
        if (actionName === 'view_record' && row?.id) {
            this.navigateToRecord(row.id);
        }
    }

    navigateToRecord(recordId) {
        if (!recordId) {
            this.showToast('Unable to open record', "We couldn't open this record. Please refresh and try again.", 'error');
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Exception__c',
                actionName: 'view'
            }
        });
    }

    toggleFilter() {
        this.isFilterOpen = !this.isFilterOpen;
        if (this.isFilterOpen) {
            this.draftFilterValues = this.cloneFilters(this.filterValues);
        }
    }

    handleFilterChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        this.draftFilterValues = { ...this.draftFilterValues, [field]: value };
    }

    handleDateRangeChange(event) {
        const dateRange = event.detail.value;
        let patch = { dateRange };
        if (dateRange === 'CUSTOM') {
            patch.startDate = this.draftFilterValues.startDate;
            patch.endDate = this.draftFilterValues.endDate;
        } else if (dateRange) {
            patch = { ...patch, ...this.calculateDateRange(dateRange) };
        } else {
            patch.startDate = null;
            patch.endDate = null;
        }
        this.draftFilterValues = { ...this.draftFilterValues, ...patch };
    }

    handleStartDateChange(event) {
        this.draftFilterValues = { ...this.draftFilterValues, startDate: event.detail.value || null };
    }

    handleEndDateChange(event) {
        this.draftFilterValues = { ...this.draftFilterValues, endDate: event.detail.value || null };
    }

    applyFilters() {
        const nextFilters = this.cloneFilters(this.draftFilterValues);
        this.filterValues = nextFilters;
        this.selectedFilter = nextFilters.source || FILTER.ALL;
        this.isFilterOpen = false;
        this.loading = true;
        this.loadExceptions()
            .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
            .finally(() => {
                this.loading = false;
            });
    }

    clearFilters() {
        const cleared = this.defaultFilters();
        this.selectedFilter = FILTER.ALL;
        this.filterValues = this.cloneFilters(cleared);
        this.draftFilterValues = this.cloneFilters(cleared);
        this.isFilterOpen = false;
        this.loading = true;
        this.loadExceptions()
            .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
            .finally(() => {
                this.loading = false;
            });
    }

    calculateDateRange(dateRange) {
        const today = new Date();
        const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        const toIso = (dt) =>
            `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`;

        const startOfWeek = (dt) => {
            const date = new Date(dt);
            const day = date.getDay();
            const diff = day === 0 ? -6 : 1 - day;
            date.setDate(date.getDate() + diff);
            return new Date(date.getFullYear(), date.getMonth(), date.getDate());
        };

        const endOfWeek = (dt) => {
            const start = startOfWeek(dt);
            const end = new Date(start);
            end.setDate(start.getDate() + 6);
            return end;
        };

        let startDate;
        let endDate;
        switch (dateRange) {
            case 'TODAY':
                startDate = new Date(startOfToday);
                endDate = new Date(startOfToday);
                break;
            case 'YESTERDAY':
                startDate = new Date(startOfToday);
                startDate.setDate(startDate.getDate() - 1);
                endDate = new Date(startDate);
                break;
            case 'THIS_WEEK':
                startDate = startOfWeek(startOfToday);
                endDate = endOfWeek(startOfToday);
                break;
            case 'LAST_WEEK':
                startDate = startOfWeek(startOfToday);
                startDate.setDate(startDate.getDate() - 7);
                endDate = endOfWeek(startDate);
                break;
            case 'THIS_MONTH':
                startDate = new Date(startOfToday.getFullYear(), startOfToday.getMonth(), 1);
                endDate = new Date(startOfToday.getFullYear(), startOfToday.getMonth() + 1, 0);
                break;
            case 'LAST_MONTH':
                startDate = new Date(startOfToday.getFullYear(), startOfToday.getMonth() - 1, 1);
                endDate = new Date(startOfToday.getFullYear(), startOfToday.getMonth(), 0);
                break;
            case 'THIS_QUARTER': {
                const quarter = Math.floor(startOfToday.getMonth() / 3);
                startDate = new Date(startOfToday.getFullYear(), quarter * 3, 1);
                endDate = new Date(startOfToday.getFullYear(), quarter * 3 + 3, 0);
                break;
            }
            case 'LAST_QUARTER': {
                const currentQuarter = Math.floor(startOfToday.getMonth() / 3);
                const quarter = currentQuarter === 0 ? 3 : currentQuarter - 1;
                const year = currentQuarter === 0 ? startOfToday.getFullYear() - 1 : startOfToday.getFullYear();
                startDate = new Date(year, quarter * 3, 1);
                endDate = new Date(year, quarter * 3 + 3, 0);
                break;
            }
            case 'THIS_YEAR':
                startDate = new Date(startOfToday.getFullYear(), 0, 1);
                endDate = new Date(startOfToday.getFullYear(), 11, 31);
                break;
            case 'LAST_YEAR':
                startDate = new Date(startOfToday.getFullYear() - 1, 0, 1);
                endDate = new Date(startOfToday.getFullYear() - 1, 11, 31);
                break;
            default:
                return { startDate: null, endDate: null };
        }
        return { startDate: toIso(startDate), endDate: toIso(endDate) };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        if (typeof error?.message === 'string') {
            return error.message;
        }
        return 'Unknown error';
    }
}