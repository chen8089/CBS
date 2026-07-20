import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConsentSummary from '@salesforce/apex/ConsentStatusDashboardController.getConsentSummary';
import getConsents from '@salesforce/apex/ConsentStatusDashboardController.getConsents';
import { calculateDateRange, DATE_RANGE_OPTIONS } from 'c/dashboardFilterCommon';

const FILTER = {
    ALL: 'ALL',
    ACTIVE: 'ACTIVE',
    PENDING: 'PENDING',
    DECLINED: 'DECLINED',
    WITHDRAWN: 'WITHDRAWN',
    REVOKED: 'REVOKED',
    EXPIRED: 'EXPIRED'
};

const SORT_FIELD_MAP = {
    rowNumber: 'LastModifiedDate',
    fullName: 'Data_Subject__r.Full_Name__c',
    email: 'Data_Subject__r.Email',
    idType: 'Data_Subject__r.ID_Type__c',
    idNumber: 'Data_Subject__r.ID_Number__c',
    dateOfBirth: 'Data_Subject__r.Date_of_Birth__c',
    employmentStatus: 'Data_Subject__r.Employment_Status__c',
    consentStatus: 'Consent_Status__c',
    actionType: 'Action_Type__c',
    submittedAt: 'Submitted_At__c',
    revokedAt: 'Revoked_At__c',
    consentExpiryDate: 'Consent_Expiry_Date__c',
    matchStatus: 'Match_Status__c',
    retentionUntil: 'Retention_Until__c'
};

const DEFAULT_SORT_FIELD = 'Submitted_At__c';
const DEFAULT_SORT_DIR = 'desc';

const DT_ATTRS = {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
};

const RECORD_OBJECT_API_NAME = 'Consent__c';

export default class ConsentStatusDashboard extends NavigationMixin(LightningElement) {
    @track summary;
    @track tableRows = [];
    @track loading = true;
    @track searchInput = '';
    searchKey = '';

    selectedFilter = FILTER.ALL;
    sortByApi = DEFAULT_SORT_FIELD;
    sortDirection = DEFAULT_SORT_DIR;
    sortedBy = 'submittedAt';
    searchDebounce;

    @track isFilterOpen = false;
    @track filterValues;
    @track draftFilterValues;

    dateRangeOptions = DATE_RANGE_OPTIONS;

    ownershipOptions = [
        { label: 'All Records', value: 'ALL' },
        { label: 'My Records', value: 'MY' }
    ];

    statusFilterOptions = [
        { label: 'All', value: FILTER.ALL },
        { label: 'Active', value: FILTER.ACTIVE },
        { label: 'Pending', value: FILTER.PENDING },
        { label: 'Declined', value: FILTER.DECLINED },
        { label: 'Withdrawn', value: FILTER.WITHDRAWN },
        { label: 'Revoked', value: FILTER.REVOKED },
        { label: 'Expired', value: FILTER.EXPIRED }
    ];

    dateTypeOptions = [
        { label: 'Created Date', value: 'CreatedDate' },
        { label: 'Last Modified Date', value: 'LastModifiedDate' },
        { label: 'Submitted At', value: 'Submitted_At__c' },
        { label: 'Revoked At', value: 'Revoked_At__c' },
        { label: 'Consent Expiry Date', value: 'Consent_Expiry_Date__c' },
        { label: 'Retention Until', value: 'Retention_Until__c' }
    ];

    columns = [
        {
            label: '#',
            fieldName: 'rowNumber',
            type: 'number',
            hideDefaultActions: true,
            cellAttributes: { alignment: 'left' },
            sortable: false
        },
        {
            label: 'Full Name',
            fieldName: 'fullName',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Email',
            fieldName: 'email',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'ID Type',
            fieldName: 'idType',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'ID Number',
            fieldName: 'idNumber',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Date of Birth',
            fieldName: 'dateOfBirth',
            type: 'date',
            typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' },
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Employment Status',
            fieldName: 'employmentStatus',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Consent Status',
            fieldName: 'consentStatus',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Action Type',
            fieldName: 'actionType',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Submitted At',
            fieldName: 'submittedAt',
            type: 'date',
            typeAttributes: DT_ATTRS,
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Revoked At',
            fieldName: 'revokedAt',
            type: 'date',
            typeAttributes: DT_ATTRS,
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Consent Expiry Date',
            fieldName: 'consentExpiryDate',
            type: 'date',
            typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' },
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Match Status',
            fieldName: 'matchStatus',
            hideDefaultActions: true,
            sortable: true
        },
        {
            label: 'Retention Until',
            fieldName: 'retentionUntil',
            type: 'date',
            typeAttributes: DT_ATTRS,
            hideDefaultActions: true,
            sortable: true
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
        this.filterValues = this.defaultFilterValues();
        this.draftFilterValues = this.defaultFilterValues();
        this.loadDashboard();
    }

    defaultFilterValues() {
        return {
            ownership: 'ALL',
            recordType: 'ALL',
            status: FILTER.ALL,
            dateType: '',
            dateRange: '',
            startDate: null,
            endDate: null
        };
    }

    cloneFilters(src) {
        return {
            ownership: src.ownership || 'ALL',
            recordType: src.recordType || 'ALL',
            status: src.status || FILTER.ALL,
            dateType: src.dateType || '',
            dateRange: src.dateRange || '',
            startDate: src.startDate ?? null,
            endDate: src.endDate ?? null
        };
    }

    buildFiltersForApex() {
        const f = this.filterValues;
        return {
            ownership: f.ownership || 'ALL',
            recordType: f.recordType || 'ALL',
            status: f.status || FILTER.ALL,
            dateType: f.dateType || null,
            dateRange: f.dateRange || null,
            startDate: f.startDate || null,
            endDate: f.endDate || null
        };
    }

    get recordTypePicklistOptions() {
        const base = [{ label: 'All', value: 'ALL' }];
        const list = this.summary?.consentRecordTypeOptions;
        if (!list || !list.length) {
            return base;
        }
        return [...base, ...list.map((o) => ({ label: o.label, value: o.value }))];
    }

    get hideRecordTypeRow() {
        return !this.summary?.showRecordTypeFilter;
    }

    get hasActiveFilters() {
        const f = this.filterValues;
        if (!f) {
            return false;
        }
        if (f.ownership === 'MY') {
            return true;
        }
        if (this.summary?.showRecordTypeFilter && f.recordType && f.recordType !== 'ALL') {
            return true;
        }
        if (f.status && f.status !== FILTER.ALL) {
            return true;
        }
        if (f.dateType && f.startDate && f.endDate) {
            return true;
        }
        return false;
    }

    get filterTriggerWrapClass() {
        return this.isFilterOpen || this.hasActiveFilters
            ? 'filter-trigger-wrap filter-trigger-wrap_active'
            : 'filter-trigger-wrap';
    }

    get dateInputsDisabled() {
        return this.draftFilterValues.dateRange !== 'CUSTOM';
    }

    get metricCards() {
        const s = this.summary || {};
        const rows = [
            { key: FILTER.ALL, label: 'Total Consents', value: s.totalConsents ?? 0 },
            { key: FILTER.ACTIVE, label: 'Active', value: s.active ?? 0 },
            { key: FILTER.PENDING, label: 'Pending', value: s.pending ?? 0 },
            { key: FILTER.DECLINED, label: 'Declined', value: s.declined ?? 0 },
            { key: FILTER.WITHDRAWN, label: 'Withdrawn', value: s.withdrawn ?? 0 },
            { key: FILTER.REVOKED, label: 'Revoked', value: s.revoked ?? 0 },
            { key: FILTER.EXPIRED, label: 'Expired', value: s.expired ?? 0 }
        ];
        return rows.map((row) => ({
            ...row,
            selected: this.selectedFilter === row.key,
            cardClass:
                this.selectedFilter === row.key
                    ? 'ds-metric-card ds-metric-card_selected'
                    : 'ds-metric-card'
        }));
    }

    get selectedCardLabel() {
        const card = this.metricCards.find((c) => c.key === this.selectedFilter);
        return card ? card.label : 'Total Consents';
    }

    get tableSubtitle() {
        const count = this.tableRows ? this.tableRows.length : 0;
        return `${count} items · Filtered by ${this.selectedCardLabel}`;
    }

    get showEmpty() {
        return !this.loading && (!this.tableRows || this.tableRows.length === 0);
    }

    toggleFilter() {
        this.isFilterOpen = !this.isFilterOpen;
        if (this.isFilterOpen) {
            this.draftFilterValues = this.cloneFilters(this.filterValues);
        }
    }

    handleFilterFieldChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        this.draftFilterValues = { ...this.draftFilterValues, [field]: value };
    }

    handleDateRangeChange(event) {
        const v = event.detail.value;
        let patch = { dateRange: v };
        if (v === 'CUSTOM') {
            patch.startDate = this.draftFilterValues.startDate;
            patch.endDate = this.draftFilterValues.endDate;
        } else if (v) {
            const r = calculateDateRange(v);
            patch.startDate = r.startDate;
            patch.endDate = r.endDate;
        } else {
            patch.startDate = null;
            patch.endDate = null;
        }
        this.draftFilterValues = { ...this.draftFilterValues, ...patch };
    }

    handleStartDateChange(event) {
        const v = event.detail.value;
        this.draftFilterValues = { ...this.draftFilterValues, startDate: v || null };
    }

    handleEndDateChange(event) {
        const v = event.detail.value;
        this.draftFilterValues = { ...this.draftFilterValues, endDate: v || null };
    }

    applyFilters() {
        this.filterValues = this.cloneFilters(this.draftFilterValues);
        this.isFilterOpen = false;
        this.loadTable();
    }

    clearFilters() {
        this.selectedFilter = FILTER.ALL;
        const cleared = this.defaultFilterValues();
        this.filterValues = this.cloneFilters(cleared);
        this.draftFilterValues = this.cloneFilters(cleared);
        this.isFilterOpen = false;
        this.loadTable();
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
        this.loadTable();
    }

    handleSearchChange(event) {
        const value = event.target.value || '';
        this.searchInput = value;
        window.clearTimeout(this.searchDebounce);
        this.searchDebounce = window.setTimeout(() => {
            this.searchKey = value;
            this.loadTable();
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
        this.loadTable();
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'view_record') {
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
                objectApiName: RECORD_OBJECT_API_NAME,
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    loadDashboard() {
        this.loading = true;
        Promise.all([getConsentSummary(), this.fetchConsentRows()])
            .then(([sum, rows]) => {
                this.summary = sum;
                this.tableRows = rows;
            })
            .catch((e) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading consent dashboard',
                        message: this.reduceError(e),
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadTable() {
        this.loading = true;
        this.fetchConsentRows()
            .then((rows) => {
                this.tableRows = rows;
            })
            .catch((e) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading consents',
                        message: this.reduceError(e),
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            })
            .finally(() => {
                this.loading = false;
            });
    }

    fetchConsentRows() {
        return getConsents({
            statusFilter: this.selectedFilter,
            searchKey: this.searchKey,
            sortBy: this.sortByApi,
            sortDirection: this.sortDirection,
            filters: this.buildFiltersForApex()
        });
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (typeof error?.message === 'string') {
            return error.message;
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        return 'Unknown error';
    }

    stopPopoverPropagation(event) {
        event.stopPropagation();
    }
}