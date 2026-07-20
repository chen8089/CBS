import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SHEETJS from '@salesforce/resourceUrl/sheetjs';
import uploadReportsWithBatch from '@salesforce/apex/ReportUploadController.uploadReportsWithBatch';
import { readAsBinaryString } from './readFile';

const REQUIRED_HEADERS = ['Email Address'];

export default class ReportUploadModal extends LightningElement {
    @track fileName = '';
    @track uploadResult = null;
    @track isUploading = false;
    @track sheetReady = false;
    @track sheetLoading = false;
    @track hasValidated = false;
    pendingFile = null;

    errorColumns = [
        { label: 'Row Number', fieldName: 'rowNumber', type: 'number', hideDefaultActions: true },
        { label: 'Field', fieldName: 'fieldName', hideDefaultActions: true },
        { label: 'Value', fieldName: 'value', hideDefaultActions: true, wrapText: true },
        { label: 'Error Message', fieldName: 'message', hideDefaultActions: true, wrapText: true }
    ];

    connectedCallback() {
        this.ensureSheetJs();
    }

    get showErrorTable() {
        return this.hasUploadSummary && this.errorTableData.length > 0;
    }

    get errorTableData() {
        return (this.uploadResult?.errors || []).map((e, idx) => ({
            id: `err-${idx}`,
            rowNumber: e.rowNumber,
            fieldName: e.fieldName,
            value: e.value,
            message: e.message
        }));
    }

    get uploadDisabled() {
        return !this.pendingFile || this.isUploading || !this.sheetReady;
    }

    get summaryTotal() {
        return this.uploadResult?.totalRows ?? 0;
    }

    get summarySuccess() {
        return this.uploadResult?.successRows ?? this.uploadResult?.successCount ?? 0;
    }

    get summaryExceptions() {
        return this.uploadResult?.exceptionRows ?? this.uploadResult?.failedValidationRecords ?? 0;
    }

    get summaryCreatedExceptions() {
        return this.uploadResult?.createdExceptions ?? this.uploadResult?.exceptionCreatedCount ?? 0;
    }

    get hasUploadSummary() {
        return this.hasValidated && !!this.uploadResult;
    }

    get showExceptionHint() {
        return this.hasUploadSummary && (this.uploadResult?.exceptionRows ?? 0) > 0;
    }

    get busy() {
        return this.isUploading;
    }

    ensureSheetJs() {
        if (this.sheetReady || this.sheetLoading) {
            return;
        }
        this.sheetLoading = true;
        loadScript(this, `${SHEETJS}/xlsx.full.min.js`)
            .then(() => {
                if (!window.XLSX) {
                    throw new Error('SheetJS failed to load.');
                }
                this.sheetReady = true;
                this.sheetLoading = false;
            })
            .catch((e) => {
                this.sheetLoading = false;
                this.showToast('Error', e.message || 'Failed to load Excel library.', 'error');
            });
    }

    handleFileChange(event) {
        const files = event.target.files;
        if (!files?.length) {
            this.pendingFile = null;
            this.fileName = '';
            this.uploadResult = null;
            this.hasValidated = false;
            return;
        }
        const file = files[0];
        const ext = file.name.split('.').pop()?.toLowerCase();
        if (ext !== 'xlsx' && ext !== 'xls' && ext !== 'csv') {
            this.showToast('Invalid file', 'Only .xlsx, .xls and .csv files are allowed.', 'error');
            event.target.value = '';
            return;
        }
        this.pendingFile = file;
        this.fileName = file.name;
        this.uploadResult = null;
        this.hasValidated = false;
    }

    async handleUpload() {
        if (this.uploadDisabled) {
            return;
        }
        if (!this.sheetReady) {
            this.showToast('Please wait', 'Excel library is still loading.', 'info');
            return;
        }

        this.isUploading = true;
        try {
            const rows = await this.parseExcelFile(this.pendingFile);
            const fileBase64 = await this.readFileAsBase64(this.pendingFile);
            const result = await uploadReportsWithBatch({
                rowsJson: JSON.stringify(rows),
                fileName: this.pendingFile?.name,
                fileBase64: fileBase64,
                contentType: this.pendingFile?.type
            });
            this.uploadResult = result;
            this.hasValidated = true;
            const isPartial = (result?.exceptionRows ?? 0) > 0 || (result?.errorCount ?? 0) > 0;

            if ((result?.exceptionRows ?? 0) > 0) {
                // Do not show extra popup/toast when row-level details are already visible below.
            } else {
                this.showToast('Upload completed', this.buildUploadSuccessMessage(result), 'success');
            }
            this.dispatchEvent(
                new CustomEvent('success', {
                    detail: { partial: isPartial, ...result },
                    bubbles: true,
                    composed: true
                })
            );
        } catch (e) {
            this.showToast('Upload failed', this.reduceError(e), 'error');
        } finally {
            this.isUploading = false;
        }
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result?.split(',')[1] || '';
                resolve(base64);
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    buildUploadSuccessMessage(result) {
        if (!result) {
            return 'Report upload completed successfully.';
        }
        const total = result.totalRows ?? 0;
        const success = result.successRows ?? result.successCount ?? 0;
        const failed = result.failedValidationRecords ?? Math.max(0, total - success);
        const batchIdText = result.batchId ? `\nBatch Id: ${result.batchId}` : '';
        return `Report upload completed.\nTotal Records: ${total}\nSuccessful Records: ${success}\nFailed Records: ${failed}${batchIdText}`;
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
    }

    handleBackdropClick() {
        this.handleCancel();
    }

    handleDialogClick(event) {
        event.stopPropagation();
    }

    async parseExcelFile(file) {
        const binary = await readAsBinaryString(file);
        const workbook = window.XLSX.read(binary, { type: 'binary', cellDates: true });
        if (!workbook?.SheetNames?.length) {
            throw new Error('Excel file does not contain any sheets.');
        }

        const sheet = workbook.Sheets[workbook.SheetNames[0]];
        const matrix = window.XLSX.utils.sheet_to_json(sheet, {
            header: 1,
            defval: '',
            raw: true
        });

        if (!matrix?.length) {
            throw new Error('Excel sheet is empty.');
        }

        const headerRow = (matrix[0] || []).map((h) => String(h ?? '').trim());
        const colIndex = this.resolveHeaderIndexes(headerRow);
        const rows = [];

        for (let i = 1; i < matrix.length; i++) {
            const line = matrix[i] || [];
            if (!line.length) {
                continue;
            }

            const emailAddress = String(line[colIndex.email] ?? '').trim();

            rows.push({
                rowNumber: i + 1,
                emailAddress
            });
        }

        if (!rows.length) {
            throw new Error('No data rows found in the Excel file.');
        }
        return rows;
    }

    resolveHeaderIndexes(headerRow) {
        const normalized = headerRow.map((h) => String(h ?? '').trim());
        const indexes = { email: -1 };

        for (const required of REQUIRED_HEADERS) {
            const idx = normalized.findIndex((h) => h === required);
            if (idx < 0) {
                throw new Error(
                    `Missing required column "${required}". Expected headers: ${REQUIRED_HEADERS.join(', ')}`
                );
            }
            if (required === 'Email Address') {
                indexes.email = idx;
            }
        }

        return indexes;
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