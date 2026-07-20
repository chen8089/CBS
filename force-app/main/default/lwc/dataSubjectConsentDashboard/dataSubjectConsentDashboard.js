import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConsentSummary from '@salesforce/apex/DataSubjectConsentDashboardController.getConsentSummary';
import getDataSubjects from '@salesforce/apex/DataSubjectConsentDashboardController.getDataSubjects';
import { calculateDateRange, DATE_RANGE_OPTIONS } from 'c/dashboardFilterCommon';

const SORT_FIELD_MAP = {
    fullName: 'Full_Name__c',
    email: 'Email',
    idType: 'ID_Type__c',
    idNumber: 'ID_Number__c',
    dateOfBirth: 'Date_of_Birth__c',
    employmentStatus: 'Employment_Status__c',
    lifecycleStage: 'Data_Subject_Lifecycle_Stage__c',
    authenticationType: 'Authentication_Type__c',
    consentType: 'Consent_Type__c',
    lastMatchStatus: 'Last_Match_Status__c',
    report: 'Report__c',
    createdDate: 'CreatedDate',
    lastActivityDate: 'Last_Activity_Date__c'
};

const VIEW_RECORD_ACTION_COLUMN = {
    type: 'action',
    typeAttributes: {
        rowActions: [{ label: 'View Record', name: 'view_record' }],
        menuAlignment: 'right'
    }
};

const DATE_COL_ATTRS = { year: 'numeric', month: '2-digit', day: '2-digit' };
const DATETIME_COL_ATTRS = {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
};

function textCol(label, fieldName, opts = {}) {
    return {
        label,
        fieldName,
        type: 'text',
        hideDefaultActions: true,
        sortable: opts.sortable !== false,
        ...(opts.wrapText ? { wrapText: true } : {})
    };
}

function dateCol(label, fieldName, isDateTime = false) {
    return {
        label,
        fieldName,
        type: 'date',
        hideDefaultActions: true,
        sortable: true,
        typeAttributes: isDateTime ? DATETIME_COL_ATTRS : DATE_COL_ATTRS
    };
}

const TABLE_COLUMNS = [
    {
        label: '#',
        fieldName: 'rowNumber',
        type: 'number',
        hideDefaultActions: true,
        cellAttributes: { alignment: 'left' },
        sortable: false
    },
    textCol('Full Name', 'fullName'),
    textCol('Email', 'email'),
    textCol('ID Type', 'idType'),
    textCol('ID Number', 'idNumber'),
    textCol('Employment Status', 'employmentStatus'),
    textCol('Lifecycle Stage', 'lifecycleStage'),
    dateCol('Created Date', 'createdDate'),
    dateCol('Last Activity Date', 'lastActivityDate'),
    VIEW_RECORD_ACTION_COLUMN
];

const CARD_OPTIONS = [
    { label: 'All', value: 'ALL', countField: 'all', filterType: 'ALL', fieldValue: null },
    {
        label: 'Singpass',
        value: 'AUTH_SINGPASS',
        countField: 'singpass',
        filterType: 'AUTHENTICATION_TYPE',
        fieldValue: 'Singpass'
    },
    {
        label: 'Non-Singpass',
        value: 'AUTH_NON_SINGPASS',
        countField: 'nonSingpass',
        filterType: 'AUTHENTICATION_TYPE',
        fieldValue: 'Non-Singpass'
    },
    {
        label: 'Upload',
        value: 'STAGE_INTAKE',
        countField: 'intake',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Upload'
    },
    {
        label: 'Consent Request',
        value: 'STAGE_CONSENT_REQUEST',
        countField: 'consentRequest',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Consent Request'
    },
    {
        label: 'Active Consent',
        value: 'STAGE_ACTIVE_CONSENT',
        countField: 'activeConsent',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Active Consent'
    },
    {
        label: 'Declined',
        value: 'STAGE_CONSENT_DECLINED',
        countField: 'declined',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Consent Declined'
    },
    {
        label: 'Processing',
        value: 'STAGE_CONSENT_EXCEPTION',
        countField: 'exceptionCount',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Processing'
    },
    {
        label: 'Withdrawn',
        value: 'STAGE_CONSENT_WITHDRAWN',
        countField: 'withdrawn',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Consent Withdrawn'
    },
    {
        label: 'Report Request',
        value: 'STAGE_REPORT_REQUEST',
        countField: 'reportRequest',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Report Request'
    },
    {
        label: 'Report Fulfilment',
        value: 'STAGE_REPORT_FULFILMENT',
        countField: 'reportFulfilment',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Report Fulfilment'
    },
    {
        label: 'Consumed',
        value: 'STAGE_EXPIRED_CONSUMED',
        countField: 'expiredConsumed',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Consumed'
    },
    {
        label: 'Departure',
        value: 'DEPARTURE',
        countField: 'departureCount',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Departure'
    },
    {
        label: 'Expired',
        value: 'STAGE_CONSENT_EXPIRED',
        countField: 'expired',
        filterType: 'LIFECYCLE_STAGE',
        fieldValue: 'Consent Expired'
    }
];

const LIFECYCLE_STAGE_FILTER_OPTIONS = [
    { label: 'All', value: 'ALL' },
    { label: 'Upload', value: 'Upload' },
    { label: 'Consent Request', value: 'Consent Request' },
    { label: 'Awaiting Action', value: 'Awaiting Data Subject Action' },
    { label: 'Active Consent', value: 'Active Consent' },
    { label: 'Declined', value: 'Consent Declined' },
    { label: 'Processing', value: 'Processing' },
    { label: 'Withdrawn', value: 'Consent Withdrawn' },
    { label: 'Expired', value: 'Consent Expired' },
    { label: 'Departure', value: 'Departure' },
    { label: 'Report Request', value: 'Report Request' },
    { label: 'Report Fulfilment', value: 'Report Fulfilment' },
    { label: 'Consumed', value: 'Consumed' }
];

const DEFAULT_SORT_FIELD = 'Full_Name__c';
const DEFAULT_SORT_DIR = 'asc';
const RECORD_OBJECT_API_NAME = 'Contact';

export default class DataSubjectConsentDashboard extends NavigationMixin(LightningElement) {
    cardOptions = CARD_OPTIONS;

    @track summary;
    @track tableRows = [];
    @track loading = true;
    @track searchInput = '';
    searchKey = '';

    selectedCardValue = 'ALL';
    sortByApi = DEFAULT_SORT_FIELD;
    sortDirection = DEFAULT_SORT_DIR;
    sortedBy = 'fullName';
    searchDebounce;

    @track isFilterOpen = false;
    @track isConsentUploadModalOpen = false;
    @track filterValues;
    @track draftFilterValues;

    dateRangeOptions = DATE_RANGE_OPTIONS;

    ownershipOptions = [
        { label: 'All Records', value: 'ALL' },
        { label: 'My Records', value: 'MY' }
    ];

    authenticationTypeFilterOptions = [
        { label: 'All', value: 'ALL' },
        { label: 'Singpass', value: 'Singpass' },
        { label: 'Non-Singpass', value: 'Non-Singpass' }
    ];

    consentTypeFilterOptions = [
        { label: 'All', value: 'ALL' },
        { label: 'Per-Report Consent', value: 'Per-Report Consent' },
        { label: 'Term-Based Consent', value: 'Term-Based Consent' }
    ];

    dateTypeOptions = [
        { label: 'Created Date', value: 'CreatedDate' },
        { label: 'Last Modified Date', value: 'LastModifiedDate' },
        { label: 'Latest Submission Date', value: 'Latest_Submission_Datetime__c' },
        { label: 'Consent Expiry Date', value: 'Current_Consent_Expiry_Date__c' }
    ];

    connectedCallback() {
        if (
            this.selectedCardValue === 'STAGE_AWAITING_ACTION' ||
            this.selectedCardValue === 'CONSENT_TYPE_PER_REPORT'
        ) {
            this.selectedCardValue = 'ALL';
        }
        this.filterValues = this.defaultFilterValues();
        this.draftFilterValues = this.defaultFilterValues();
        this.loadDashboard();
    }

    defaultFilterValues() {
        return {
            ownership: 'ALL',
            lifecycleStage: 'ALL',
            authenticationType: 'ALL',
            consentType: 'ALL',
            dateType: '',
            dateRange: '',
            startDate: null,
            endDate: null
        };
    }

    cloneFilters(src) {
        return {
            ownership: src.ownership || 'ALL',
            lifecycleStage: src.lifecycleStage || 'ALL',
            authenticationType: src.authenticationType || 'ALL',
            consentType: src.consentType || 'ALL',
            dateType: src.dateType || '',
            dateRange: src.dateRange || '',
            startDate: src.startDate ?? null,
            endDate: src.endDate ?? null
        };
    }

    get lifecycleStageFilterOptions() {
        return LIFECYCLE_STAGE_FILTER_OPTIONS;
    }

    get columns() {
        return TABLE_COLUMNS;
    }

    buildFiltersForApex() {
        const f = this.filterValues;
        return {
            ownership: f.ownership || 'ALL',
            status: f.lifecycleStage || 'ALL',
            authenticationType: f.authenticationType || 'ALL',
            consentType: f.consentType || 'ALL',
            dateType: f.dateType || null,
            dateRange: f.dateRange || null,
            startDate: f.startDate || null,
            endDate: f.endDate || null
        };
    }

    get hasActiveFilters() {
        const f = this.filterValues;
        if (!f) {
            return false;
        }
        if (f.ownership === 'MY') {
            return true;
        }
        if (f.lifecycleStage && f.lifecycleStage !== 'ALL') {
            return true;
        }
        if (f.authenticationType && f.authenticationType !== 'ALL') {
            return true;
        }
        if (f.consentType && f.consentType !== 'ALL') {
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

    get stageCards() {
        return this.cardOptions.map((card) => {
            const count = this.summary ? this.summary[card.countField] || 0 : 0;
            const isSelected = this.selectedCardValue === card.value;

            return {
                ...card,
                count,
                isSelected,
                className: isSelected ? 'stage-card selected' : 'stage-card'
            };
        });
    }

    get selectedCardLabel() {
        const card = this.cardOptions.find((item) => item.value === this.selectedCardValue);
        return card ? card.label : 'All';
    }

    get tableSubtitle() {
        const count = this.tableRows ? this.tableRows.length : 0;
        return `${count} items · Filtered by ${this.selectedCardLabel}`;
    }

    get showEmpty() {
        return !this.loading && (!this.tableRows || this.tableRows.length === 0);
    }

    get datatableWrapper() {
        return [{ id: this.selectedCardValue }];
    }

    toggleFilter() {
        this.isFilterOpen = !this.isFilterOpen;
        if (this.isFilterOpen) {
            this.draftFilterValues = this.cloneFilters(this.filterValues);
        }
    }

    closeFilter() {
        this.isFilterOpen = false;
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
        const nextFilters = this.cloneFilters(this.draftFilterValues);
        this.filterValues = nextFilters;
        this.isFilterOpen = false;
        this.syncCardFromAppliedFilters(nextFilters);
        this.syncSortForCurrentColumns();
        this.loadDataSubjects();
    }

    syncCardFromAppliedFilters(filters) {
        if (filters.lifecycleStage && filters.lifecycleStage !== 'ALL') {
            const stageCard = this.cardOptions.find(
                (card) => card.filterType === 'LIFECYCLE_STAGE' && card.fieldValue === filters.lifecycleStage
            );
            this.selectedCardValue = stageCard ? stageCard.value : 'ALL';
            return;
        }
        if (filters.authenticationType && filters.authenticationType !== 'ALL') {
            const authCard = this.cardOptions.find(
                (card) =>
                    card.filterType === 'AUTHENTICATION_TYPE' && card.fieldValue === filters.authenticationType
            );
            this.selectedCardValue = authCard ? authCard.value : 'ALL';
            return;
        }
        if (filters.consentType && filters.consentType !== 'ALL') {
            const consentCard = this.cardOptions.find(
                (card) => card.filterType === 'CONSENT_TYPE' && card.fieldValue === filters.consentType
            );
            this.selectedCardValue = consentCard ? consentCard.value : 'ALL';
            return;
        }
        this.selectedCardValue = 'ALL';
    }

    clearFilters() {
        const cleared = this.defaultFilterValues();
        this.filterValues = this.cloneFilters(cleared);
        this.draftFilterValues = this.cloneFilters(cleared);
        this.isFilterOpen = false;
        this.selectedCardValue = 'ALL';
        this.syncSortForCurrentColumns();
        this.loadDataSubjects();
    }

    handleStageCardClick(event) {
        const selectedValue = event.currentTarget?.dataset?.value;
        if (!selectedValue || selectedValue === this.selectedCardValue) {
            return;
        }

        this.selectedCardValue = selectedValue;

        if (this.filterValues) {
            this.filterValues = {
                ...this.filterValues,
                lifecycleStage: 'ALL',
                authenticationType: 'ALL',
                consentType: 'ALL'
            };
        }
        if (this.isFilterOpen && this.draftFilterValues) {
            this.draftFilterValues = {
                ...this.draftFilterValues,
                lifecycleStage: 'ALL',
                authenticationType: 'ALL',
                consentType: 'ALL'
            };
        }

        this.syncSortForCurrentColumns();
        this.loadDataSubjects();
    }

    syncSortForCurrentColumns() {
        const sortableFieldNames = this.columns
            .filter((col) => col.sortable && col.fieldName)
            .map((col) => col.fieldName);
        if (!sortableFieldNames.includes(this.sortedBy)) {
            this.sortedBy = 'fullName';
            this.sortByApi = SORT_FIELD_MAP.fullName || DEFAULT_SORT_FIELD;
            this.sortDirection = DEFAULT_SORT_DIR;
        }
    }

    handleSearchChange(event) {
        const value = event.target.value || '';
        this.searchInput = value;
        window.clearTimeout(this.searchDebounce);
        this.searchDebounce = window.setTimeout(() => {
            this.searchKey = value;
            this.loadDataSubjects();
        }, 300);
    }

    handleRefresh() {
        this.loadDashboard();
    }

    handleUploadConsent() {
        this.isConsentUploadModalOpen = true;
    }

    handleConsentUploadModalClose() {
        this.isConsentUploadModalOpen = false;
    }

    handleConsentUploadModalSuccess() {
        this.isConsentUploadModalOpen = false;
        this.handleRefresh();
    }

    handleSort(event) {
        const fieldName = event.detail.fieldName;
        const dir = event.detail.sortDirection;
        this.sortedBy = fieldName;
        this.sortDirection = dir;
        this.sortByApi = SORT_FIELD_MAP[fieldName] || DEFAULT_SORT_FIELD;
        this.loadDataSubjects();
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
        Promise.all([this.loadSummary(), this.fetchSubjects()])
            .then(([sum, rows]) => {
                this.summary = sum;
                this.tableRows = rows;
            })
            .catch((e) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading dashboard',
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

    loadSummary() {
        return getConsentSummary();
    }

    loadDataSubjects() {
        this.loading = true;
        this.fetchSubjects()
            .then((rows) => {
                this.tableRows = rows;
            })
            .catch((e) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading data subjects',
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

    fetchSubjects() {
        return getDataSubjects({
            selectedCardValue: this.selectedCardValue,
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