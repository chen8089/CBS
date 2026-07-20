import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReportSummary from '@salesforce/apex/CaseOfflineProcessingDashboardController.getReportSummary';
import getReports from '@salesforce/apex/CaseOfflineProcessingDashboardController.getReports';
import { calculateDateRange, DATE_RANGE_OPTIONS } from 'c/dashboardFilterCommon';

const FILTER = {
    ALL: 'ALL',
    UPDATED_CONSENT: 'UPDATED_CONSENT',
    NO_VALID_CONSENT: 'NO_VALID_CONSENT'
};

const CARD_CONFIG = [
    { label: 'All', value: FILTER.ALL, countField: 'all' },
    { label: 'Updated Consent', value: FILTER.UPDATED_CONSENT, countField: 'updatedConsent' },
    { label: 'No Valid Consent', value: FILTER.NO_VALID_CONSENT, countField: 'noValidConsent' }
];

const SORT_FIELD_MAP = {
    email: 'Email__c',
    batchId: 'Batch_ID__c',
    consentStatus: 'Consent_Status__c',
    updatedDate: 'Updated_Date__c'
};

const DEFAULT_SORT_FIELD = 'Updated_Date__c';
const DEFAULT_SORT_DIRECTION = 'desc';

const DATE_TYPE_UPDATED = 'Updated_Date__c';
const DATE_TYPE_CREATED = 'CreatedDate';
const DATE_TYPE_LAST_MODIFIED = 'LastModifiedDate';

export default class CaseOfflineProcessingDashboard extends NavigationMixin(LightningElement) {
    /** @deprecated No longer used; Upload Report opens modal. Kept for Experience Builder compatibility. */
    @api uploadPageName = 'import-reports';
    @api title = 'Reports';
    @api subtitle = 'Manage';

    @track summary = {
        all: 0,
        updatedConsent: 0,
        noValidConsent: 0
    };
    @track reports = [];
    @track loading = true;
    @track searchInput = '';
    searchKey = '';
    searchDebounce;

    selectedFilter = FILTER.ALL;
    sortByApi = DEFAULT_SORT_FIELD;
    sortedBy = 'updatedDate';
    sortDirection = DEFAULT_SORT_DIRECTION;

    @track isFilterOpen = false;
    @track filterValues = this.defaultFilters();
    @track draftFilterValues = this.defaultFilters();
    isUploadModalOpen = false;

    dateRangeOptions = DATE_RANGE_OPTIONS;

    ownershipOptions = [
        { label: 'All Records', value: 'ALL' },
        { label: 'My Records', value: 'MY' }
    ];

    statusOptions = [
        { label: 'All', value: FILTER.ALL },
        { label: 'Updated Consent', value: FILTER.UPDATED_CONSENT },
        { label: 'No Valid Consent', value: FILTER.NO_VALID_CONSENT }
    ];

    dateTypeOptions = [
        { label: 'Updated Date', value: DATE_TYPE_UPDATED },
        { label: 'Created Date', value: DATE_TYPE_CREATED },
        { label: 'Last Modified Date', value: DATE_TYPE_LAST_MODIFIED }
    ];

    columns = [
        { label: '#', fieldName: 'rowNumber', type: 'number', hideDefaultActions: true, sortable: false },
        { label: 'Email', fieldName: 'email', type: 'email', hideDefaultActions: true, sortable: true },
        { label: 'Batch ID', fieldName: 'batchId', type: 'text', hideDefaultActions: true, sortable: true },
        { label: 'Consent Status', fieldName: 'consentStatus', type: 'text', hideDefaultActions: true, sortable: true },
        {
            label: 'Updated Date',
            fieldName: 'updatedDate',
            type: 'date',
            hideDefaultActions: true,
            sortable: true,
            typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' }
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [{ label: 'View Record', name: 'view_record' }],
                menuAlignment: 'right'
            }
        }
    ];

    connectedCallback() {
        this.loadDashboard();
    }

    get metricCards() {
        return CARD_CONFIG.map((card) => ({
            key: card.value,
            label: card.label,
            value: this.summary[card.countField] || 0,
            selected: this.selectedFilter === card.value,
            cardClass:
                this.selectedFilter === card.value
                    ? 'ds-metric-card ds-metric-card_selected'
                    : 'ds-metric-card'
        }));
    }

    get selectedCardLabel() {
        const card = CARD_CONFIG.find((c) => c.value === this.selectedFilter);
        return card ? card.label : 'All';
    }

    get tableSubtitle() {
        const count = this.reports.length;
        return `${count} items · Sorted By Updated Date · Filtered By ${this.selectedCardLabel}`;
    }

    get showEmpty() {
        return !this.loading && this.reports.length === 0;
    }

    get filterTriggerWrapClass() {
        return this.isFilterOpen || this.hasActiveFilters
            ? 'filter-trigger-wrap filter-trigger-wrap_active'
            : 'filter-trigger-wrap';
    }

    get dateInputsDisabled() {
        return this.draftFilterValues.dateRange !== 'CUSTOM';
    }

    get hasActiveFilters() {
        const f = this.filterValues;
        return f.ownership === 'MY' || f.status !== FILTER.ALL || (f.dateType && f.startDate && f.endDate);
    }

    defaultFilters() {
        return {
            ownership: 'ALL',
            status: FILTER.ALL,
            dateType: '',
            dateRange: '',
            startDate: null,
            endDate: null
        };
    }

    cloneFilters(src = {}) {
        return {
            ownership: src.ownership || 'ALL',
            status: src.status || FILTER.ALL,
            dateType: src.dateType || '',
            dateRange: src.dateRange || '',
            startDate: src.startDate || null,
            endDate: src.endDate || null
        };
    }

    loadDashboard() {
        this.loading = true;
        Promise.all([this.loadSummary(), this.loadReports()])
            .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
            .finally(() => {
                this.loading = false;
            });
    }

    loadSummary() {
        return getReportSummary().then((summary) => {
            this.summary = {
                all: summary?.all || 0,
                updatedConsent: summary?.updatedConsent || 0,
                noValidConsent: summary?.noValidConsent || 0
            };
        });
    }

    loadReports() {
        return getReports({
            statusFilter: this.selectedFilter,
            searchKey: this.searchKey,
            sortBy: this.sortByApi,
            sortDirection: this.sortDirection,
            filters: this.cloneFilters(this.filterValues)
        }).then((rows) => {
            this.reports = rows || [];
        });
    }

    handleCardClick(event) {
        const key = event.currentTarget?.dataset?.filter;
        if (!key || key === this.selectedFilter) {
            return;
        }
        this.selectedFilter = key;
        this.filterValues = { ...this.filterValues, status: key };
        if (this.isFilterOpen) {
            this.draftFilterValues = { ...this.draftFilterValues, status: key };
        }
        this.loading = true;
        this.loadReports()
            .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
            .finally(() => {
                this.loading = false;
            });
    }

    handleSearchChange(event) {
        const value = event.target.value || '';
        this.searchInput = value;
        window.clearTimeout(this.searchDebounce);
        this.searchDebounce = window.setTimeout(() => {
            this.searchKey = value;
            this.loading = true;
            this.loadReports()
                .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
                .finally(() => {
                    this.loading = false;
                });
        }, 300);
    }

    handleRefresh() {
        this.loadDashboard();
    }

    handleSort(event) {
        const fieldName = event.detail.fieldName;
        const dir = event.detail.sortDirection;
        this.sortedBy = fieldName;
        this.sortDirection = dir;
        this.sortByApi = SORT_FIELD_MAP[fieldName] || DEFAULT_SORT_FIELD;
        this.loading = true;
        this.loadReports()
            .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
            .finally(() => {
                this.loading = false;
            });
    }

    handleRowAction(event) {
        if (event.detail.action.name === 'view_record') {
            this.navigateToRecord(event.detail.row.id);
        }
    }

    handleUploadReport() {
        this.isUploadModalOpen = true;
    }

    handleUploadModalClose() {
        this.isUploadModalOpen = false;
    }

    handleUploadModalSuccess(event) {
        const partial = event?.detail?.partial === true;
        if (!partial) {
            this.isUploadModalOpen = false;
        }
        this.handleRefresh();
    }

    navigateToRecord(recordId) {
        if (!recordId) {
            this.showToast('Unable to open record', 'Record Id is missing.', 'error');
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Reports__c',
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
            patch = { ...patch, ...calculateDateRange(dateRange) };
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
        this.selectedFilter = nextFilters.status || FILTER.ALL;
        this.isFilterOpen = false;
        this.loading = true;
        this.loadReports()
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
        this.loadReports()
            .catch((error) => this.showToast('Error', this.reduceError(error), 'error'))
            .finally(() => {
                this.loading = false;
            });
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

    stopPopoverPropagation(event) {
        event.stopPropagation();
    }
}