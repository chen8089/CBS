import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getBatchSummary from '@salesforce/apex/BatchUploadDashboardController.getBatchSummary';
import getBatches from '@salesforce/apex/BatchUploadDashboardController.getBatches';

const FILTER = {
    ALL: 'ALL',
    DRAFT: 'DRAFT',
    SUBMITTED: 'SUBMITTED',
    APPROVED: 'APPROVED',
    SENT_BACK: 'SENT_BACK',
    FAILED: 'FAILED'
};

const SORT_FIELD_MAP = {
    batchId: 'Name',
    batchName: 'Batch_Name__c',
    clientAccount: 'Client_Account__r.Name',
    totalRecords: 'Total_Records__c',
    validatedRecords: 'Validated_Records__c',
    failedValidationRecords: 'Failed_Validation_Records__c',
    pendingUploadStatus: 'Pending_Upload_Status__c',
    consentLinksGenerated: 'Consent_Links_Generated__c',
    consentEmailsSent: 'Consent_Emails_Sent__c',
    consentStatusSummary: 'Consent_Status_Summary__c',
    approvalStatus: 'Approval_Status__c',
    emailLinkStatus: 'Email_Link_Status__c',
    reminderReviewPeriod: 'Reminder_Review_Period__c',
    createdDate: 'CreatedDate'
};

const DEFAULT_SORT_FIELD = 'CreatedDate';
const DEFAULT_SORT_DIRECTION = 'desc';
const DATE_TYPE_CREATED = 'CreatedDate';

export default class BatchUploadDashboard extends NavigationMixin(LightningElement) {
    @api uploadPageName = 'import-data-subjects';
    @api title = 'Consent Batches';
    @api subtitle = 'Manage';

    @track summary = {
        all: 0,
        draft: 0,
        submitted: 0,
        approved: 0,
        sentBack: 0,
        failed: 0
    };
    @track batches = [];
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

    statusOptions = [
        { label: 'All', value: FILTER.ALL },
        { label: 'Draft', value: FILTER.DRAFT },
        { label: 'Submitted', value: FILTER.SUBMITTED },
        { label: 'Approved', value: FILTER.APPROVED },
        { label: 'Sent Back', value: FILTER.SENT_BACK },
        { label: 'Failed', value: FILTER.FAILED }
    ];

    dateTypeOptions = [{ label: 'Created Date', value: DATE_TYPE_CREATED }];

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
        { label: '#', fieldName: 'rowNumber', type: 'number', hideDefaultActions: true, sortable: false },
        { label: 'Batch ID', fieldName: 'batchId', hideDefaultActions: true, sortable: true },
        { label: 'Batch Name', fieldName: 'batchName', hideDefaultActions: true, sortable: true },
        { label: 'Client / Account', fieldName: 'clientAccount', hideDefaultActions: true, sortable: true },
        { label: 'Total Records', fieldName: 'totalRecords', type: 'number', hideDefaultActions: true, sortable: true },
        { label: 'Validated Records', fieldName: 'validatedRecords', type: 'number', hideDefaultActions: true, sortable: true },
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

    get cards() {
        return [
            { key: FILTER.ALL, label: 'All', value: this.summary.all || 0 },
            { key: FILTER.DRAFT, label: 'Draft', value: this.summary.draft || 0 },
            { key: FILTER.SUBMITTED, label: 'Submitted', value: this.summary.submitted || 0 },
            { key: FILTER.APPROVED, label: 'Approved', value: this.summary.approved || 0 },
            { key: FILTER.SENT_BACK, label: 'Sent Back', value: this.summary.sentBack || 0 },
            { key: FILTER.FAILED, label: 'Failed', value: this.summary.failed || 0 }
        ].map((card) => ({
            ...card,
            selected: this.selectedFilter === card.key,
            className: this.selectedFilter === card.key ? 'bud-card bud-card_selected' : 'bud-card'
        }));
    }

    get selectedCardLabel() {
        const card = this.cards.find((item) => item.key === this.selectedFilter);
        return card ? card.label : 'All';
    }

    get tableSubtitle() {
        const count = this.batches.length;
        return `${count} items · Sorted By Created Date · Filtered By ${this.selectedCardLabel}`;
    }

    get showEmpty() {
        return !this.loading && this.batches.length === 0;
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
        return (
            f.ownership === 'MY' ||
            f.status !== FILTER.ALL ||
            (f.dateType && f.startDate && f.endDate)
        );
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
        Promise.all([this.loadSummary(), this.loadBatches()])
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadSummary() {
        return getBatchSummary().then((summary) => {
            this.summary = {
                all: summary?.all || 0,
                draft: summary?.draft || 0,
                submitted: summary?.submitted || 0,
                approved: summary?.approved || 0,
                sentBack: summary?.sentBack || 0,
                failed: summary?.failed || 0
            };
        });
    }

    loadBatches() {
        return getBatches({
            statusFilter: this.selectedFilter,
            searchKey: this.searchKey,
            sortBy: this.sortByApi,
            sortDirection: this.sortDirection,
            filters: this.cloneFilters(this.filterValues)
        }).then((rows) => {
            this.batches = rows || [];
        });
    }

    handleCardClick(event) {
        const key = event.currentTarget?.dataset?.filter;
        if (!key || key === this.selectedFilter) {
            return;
        }
        this.selectedFilter = key;
        this.filterValues = { ...this.filterValues, status: key };
        this.draftFilterValues = { ...this.draftFilterValues, status: key };
        this.loading = true;
        this.loadBatches()
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
            this.loadBatches()
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
        this.loadBatches()
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
            this.showToast('Unable to open record', 'Record Id is missing.', 'error');
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Batch__c',
                actionName: 'view'
            }
        });
    }

    openUploadModal() {
        const modal = this.template.querySelector('c-batch-excel-upload-modal');
        if (modal) {
            modal.open();
        }
    }

    handleUploadSuccess() {
        this.loadDashboard();
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
        this.selectedFilter = nextFilters.status || FILTER.ALL;
        this.isFilterOpen = false;
        this.loading = true;
        this.loadBatches()
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
        this.loadBatches()
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