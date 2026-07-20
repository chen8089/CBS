import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReportRequestItems from '@salesforce/apex/PortalCaseDetailController.getReportRequestItems';
import exportAuthorizedList from '@salesforce/apex/ReportRequestExportService.exportAuthorizedList';

export default class CaseReportRequestItemsPanel extends LightningElement {
    @api recordId;
    rows = [];
    isLoading = true;
    isExporting = false;
    currentPageReference;

    columns = [
        { label: 'Item', fieldName: 'itemName', type: 'text' },
        { label: 'Data Subject', fieldName: 'dataSubjectName', type: 'text' },
        { label: 'Eligibility', fieldName: 'eligibilityStatus', type: 'text' },
        { label: 'Delivery', fieldName: 'deliveryStatus', type: 'text' },
        { label: 'Notice Sent', fieldName: 'noticeSent', type: 'boolean' },
        {
            label: 'Created',
            fieldName: 'createdDate',
            type: 'date',
            typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' }
        }
    ];

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        this.currentPageReference = pageRef;
    }

    @wire(getReportRequestItems, { caseId: '$effectiveCaseId' })
    wiredRows({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.rows = data;
            return;
        }
        this.rows = [];
        if (error) {
            // Keep UI functional without raising blocking errors in portal.
            // eslint-disable-next-line no-console
            console.error('Failed to load report request items', error);
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get effectiveCaseId() {
        if (this.recordId) {
            return this.recordId;
        }
        const attrs = this.currentPageReference?.attributes || {};
        const state = this.currentPageReference?.state || {};
        return attrs.recordId || state.recordId || null;
    }

    get cardTitle() {
        return `Report Request Items (${this.rows.length})`;
    }

    get disableExportButton() {
        return this.isLoading || this.isExporting || !this.effectiveCaseId;
    }

    async handleExportAuthorizedList() {
        if (!this.effectiveCaseId) {
            this.showToast('Export Failed', 'Cannot detect Case Id for export.', 'error');
            return;
        }
        this.isExporting = true;
        try {
            const requestedFields = [
                'Data_Subject__c',
                'Consent__c',
                'Eligibility_Status__c',
                'Consent_Revalidation_Status__c',
                'Delivery_Status__c',
                'SLA_Due_Date__c'
            ];
            const csvBody = await exportAuthorizedList({
                caseId: this.effectiveCaseId,
                requestedFields
            });
            this.downloadCsv(csvBody);
            this.showToast('Export Ready', 'Authorized list has been downloaded.', 'success');
        } catch (error) {
            const message =
                error?.body?.message ||
                (Array.isArray(error?.body) && error.body.length > 0 ? error.body[0].message : null) ||
                error?.message ||
                'Failed to export authorized list.';
            this.showToast('Export Failed', message, 'error');
            // eslint-disable-next-line no-console
            console.error('Export authorized list failed', error);
        } finally {
            this.isExporting = false;
        }
    }

    downloadCsv(csvBody) {
        const normalized = csvBody || '';
        const csvWithBom = `\uFEFF${normalized}`;
        const encodedCsv = encodeURIComponent(csvWithBom);
        const link = document.createElement('a');
        const datePart = new Date().toISOString().slice(0, 10);
        // Use data URI for LWS compatibility (avoids blocked blob MIME handling).
        link.href = `data:text/plain;charset=utf-8,${encodedCsv}`;
        link.download = `authorized-list-${this.effectiveCaseId}-${datePart}.csv`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
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
}