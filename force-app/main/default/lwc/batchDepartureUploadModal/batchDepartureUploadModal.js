import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SHEETJS from '@salesforce/resourceUrl/sheetjs';
import validateRows from '@salesforce/apex/BatchDeparturesUploadController.validateRows';
import uploadDepartureDataWithBatch from '@salesforce/apex/BatchDeparturesUploadController.uploadDepartureDataWithBatch';
import { readAsBinaryString } from './readFile';

const REQUIRED_HEADERS = ['Email Address', 'Departure Date'];
const ISO_DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Converts Excel / string / Date values to yyyy-MM-dd, or null if invalid.
 */
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

export default class BatchDepartureUploadModal extends LightningElement {
    @track isOpen = false;
    @track fileName = '';
    @track parsedRows = [];
    @track validationResult = null;
    @track isValidating = false;
    @track isUploading = false;
    @track hasValidated = false;
    @track uploadResult = null;
    @track sheetReady = false;
    @track sheetLoading = false;

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

    get showModal() {
        return this.isOpen;
    }

    get summaryTotal() {
        return this.uploadResult?.totalRows ?? this.validationResult?.totalRows ?? 0;
    }

    get summarySuccess() {
        return this.uploadResult?.successRows ?? this.validationResult?.validRows ?? 0;
    }

    get summaryExceptions() {
        return this.uploadResult?.exceptionRows ?? this.validationResult?.errorRows ?? 0;
    }

    get summaryCreatedExceptions() {
        return this.uploadResult?.createdExceptions ?? this.uploadResult?.exceptionCreatedCount ?? 0;
    }

    get errorTableData() {
        return (this.validationResult?.errors || []).map((e, idx) => ({
            id: `err-${idx}`,
            rowNumber: e.rowNumber,
            fieldName: e.fieldName,
            value: e.value,
            message: e.message
        }));
    }

    get showErrorTable() {
        return this.hasValidated && !this.uploadResult && this.summaryExceptions > 0;
    }

    get uploadDisabled() {
        return !this.pendingFile || this.isValidating || this.isUploading || !this.sheetReady;
    }

    get busy() {
        return this.isValidating || this.isUploading;
    }

    get hasUploadSummary() {
        return this.hasValidated && !!this.uploadResult;
    }

    get showExceptionHint() {
        return this.hasUploadSummary && (this.uploadResult?.exceptionRows ?? 0) > 0;
    }

    @api
    open() {
        this.resetState();
        this.isOpen = true;
        this.ensureSheetJs();
    }

    @api
    close() {
        this.isOpen = false;
    }

    resetState() {
        this.fileName = '';
        this.pendingFile = null;
        this.parsedRows = [];
        this.validationResult = null;
        this.uploadResult = null;
        this.hasValidated = false;
        this.isValidating = false;
        this.isUploading = false;
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
            this.parsedRows = [];
            this.validationResult = null;
            this.uploadResult = null;
            this.hasValidated = false;
            return;
        }
        const file = files[0];
        const ext = file.name.split('.').pop()?.toLowerCase();
        if (ext !== 'xlsx' && ext !== 'xls') {
            this.showToast('Invalid file', 'Only .xlsx and .xls files are allowed.', 'error');
            event.target.value = '';
            return;
        }
        this.pendingFile = file;
        this.fileName = file.name;
        this.parsedRows = [];
        this.validationResult = null;
        this.uploadResult = null;
        this.hasValidated = false;
    }

    async runValidation() {
        if (!this.pendingFile) {
            this.showToast('No file', 'Please select an Excel file first.', 'warning');
            return false;
        }
        if (!this.sheetReady) {
            this.showToast('Please wait', 'Excel library is still loading.', 'info');
            return false;
        }

        this.isValidating = true;
        try {
            const rows = await this.parseExcelFile(this.pendingFile);
            this.parsedRows = rows;
            const result = await validateRows({ rowsJson: JSON.stringify(this.parsedRows) });
            this.validationResult = result;
            this.uploadResult = null;
            this.hasValidated = true;
            if (result?.errorRows > 0) {
                this.showToast('Validation failed', `${result.errorRows} row(s) have errors. Upload has been blocked.`, 'error');
                return false;
            } else {
                return true;
            }
        } catch (e) {
            this.showToast('Validation failed', this.reduceError(e), 'error');
            this.hasValidated = false;
            return false;
        } finally {
            this.isValidating = false;
        }
    }

    async handleUpload() {
        if (!this.pendingFile) {
            this.showToast('No file', 'Please select an Excel file first.', 'warning');
            return;
        }
        if (!this.sheetReady) {
            this.showToast('Please wait', 'Excel library is still loading.', 'info');
            return;
        }

        const isValid = await this.runValidation();
        if (!isValid) {
            return;
        }

        this.isUploading = true;
        try {
            const totalRecords = this.parsedRows.length;
            const validatedRecords = this.validationResult?.validRows ?? this.parsedRows.length;
            const failedValidationRecords = Math.max(0, totalRecords - validatedRecords);
            const fileBase64 = await this.readFileAsBase64(this.pendingFile);
            const result = await uploadDepartureDataWithBatch({
                recordJson: JSON.stringify(this.parsedRows),
                totalRecords: totalRecords,
                validatedRecords: validatedRecords,
                failedValidationRecords: failedValidationRecords,
                fileName: this.pendingFile?.name,
                fileBase64: fileBase64,
                contentType: this.pendingFile?.type
            });
            const errorCount = result?.errorCount ?? 0;
            const exceptionRows = result?.exceptionRows ?? 0;
            this.uploadResult = result;
            this.hasValidated = true;
            if (errorCount > 0 && result?.errors?.length) {
                this.showToast(
                    'Upload completed with errors',
                    `${result.insertedRows ?? 0} record(s) imported with ${errorCount} processing error(s).`,
                    'warning'
                );
            } else if (exceptionRows > 0) {
                this.showToast(
                    'Upload completed',
                    result?.message || 'Departure upload completed with exceptions. Please review the Exceptions list.',
                    'warning'
                );
            } else {
                this.showToast(
                    'Upload completed',
                    this.buildUploadSuccessMessage(result),
                    'success'
                );
            }
            this.dispatchEvent(
                new CustomEvent('success', {
                    detail: result,
                    bubbles: true,
                    composed: true
                })
            );
            if (errorCount === 0 && exceptionRows === 0) {
                this.close();
            }
        } catch (e) {
            this.showToast('Upload Failed', this.reduceError(e), 'error');
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
            reader.onerror = () => {
                reject(reader.error);
            };
            reader.readAsDataURL(file);
        });
    }

    buildUploadSuccessMessage(result) {
        if (!result) {
            return 'Departure upload completed successfully.';
        }
        const total = result.totalRows ?? this.parsedRows.length;
        const success = result.successRows ?? result.insertedRows ?? 0;
        const failed = result.failedValidationRecords ?? Math.max(0, total - success);
        const batchIdText = result.batchId ? `\nBatch Id: ${result.batchId}` : '';
        return `Departure upload completed.\nTotal Records: ${total}\nSuccessful Records: ${success}\nFailed Records: ${failed}${batchIdText}`;
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel', { bubbles: true, composed: true }));
        this.close();
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
            const isBlank = line.every((cell) => {
                if (cell === null || cell === undefined) {
                    return true;
                }
                return String(cell).trim() === '';
            });
            if (isBlank) {
                continue;
            }

            const emailAddress = String(line[colIndex.email] ?? '').trim();

            const rawDate = line[colIndex.departureDate];
            const departureDate = excelDateToISODate(rawDate) || '';

            rows.push({
                rowNumber: i + 1,
                emailAddress,
                departureDate
            });
        }

        if (!rows.length) {
            throw new Error('No data rows found in the Excel file.');
        }
        return rows;
    }

    resolveHeaderIndexes(headerRow) {
        const normalized = headerRow.map((h) => String(h ?? '').trim());
        const indexes = { email: -1, departureDate: -1 };

        REQUIRED_HEADERS.forEach((required) => {
            const idx = normalized.findIndex((h) => h === required);
            if (idx < 0) {
                throw new Error(
                    `Missing required column "${required}". Expected headers: ${REQUIRED_HEADERS.join(', ')}`
                );
            }
            if (required === 'Email Address') {
                indexes.email = idx;
            } else if (required === 'Departure Date') {
                indexes.departureDate = idx;
            }
        });

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