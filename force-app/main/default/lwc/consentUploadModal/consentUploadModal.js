import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SHEETJS from '@salesforce/resourceUrl/sheetjs';
import validateAndUploadConsents from '@salesforce/apex/ConsentUploadController.validateAndUploadConsents';
import ACTION_CANCEL_LABEL from '@salesforce/label/c.CBS_Action_Cancel';
import ACTION_UPLOAD_LABEL from '@salesforce/label/c.CBS_Action_Upload';
import { readAsArrayBuffer } from './readFile';

const REQUIRED_HEADER_DEFS = [
    { key: 'email', labels: ['email address'] },
    { key: 'fullName', labels: ['full name'] },
    { key: 'idType', labels: ['id type'] },
    { key: 'idNumber', labels: ['id number'] },
    { key: 'dateOfBirth', labels: ['date of birth'] },
    { key: 'employmentStatus', labels: ['employment status'] }
];
const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;
const ALLOWED_EXTENSIONS = ['xlsx', 'xls', 'csv'];
const MAX_FILE_SIZE = 5 * 1024 * 1024;

export default class ConsentUploadModal extends LightningElement {
    actionCancelLabel = ACTION_CANCEL_LABEL;
    actionUploadLabel = ACTION_UPLOAD_LABEL;

    @track isOpen = true;
    @track batchName = '';
    @track fileName = '';
    @track isUploading = false;
    @track sheetReady = false;
    @track sheetLoading = false;
    @track uploadRejectMessage = '';
    @track uploadSummary = null;
    @track uploadMessage = '';

    pendingFile = null;

    connectedCallback() {
        this.ensureSheetJs();
    }

    get showModal() {
        return this.isOpen;
    }

    @api
    close() {
        this.isOpen = false;
    }

    get uploadDisabled() {
        return !this.pendingFile || this.isUploading || !this.sheetReady;
    }

    get busy() {
        return this.isUploading;
    }

    handleBatchNameChange(event) {
        this.batchName = event.target.value || '';
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
        this.uploadRejectMessage = '';
        this.uploadSummary = null;
        this.uploadMessage = '';
        const files = event.target.files;
        if (!files?.length) {
            this.pendingFile = null;
            this.fileName = '';
            return;
        }
        const file = files[0];
        this.pendingFile = file;
        this.fileName = file.name;
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
            const fileValidation = this.validateSelectedFile(this.pendingFile);
            if (!fileValidation.success) {
                this.uploadRejectMessage = fileValidation.errorMessage;
                return;
            }

            const parsedFile = await this.parseExcelFile(this.pendingFile);
            const result = await validateAndUploadConsents({
                batchName: this.batchName?.trim() || null,
                fileName: this.fileName,
                fileSizeBytes: this.pendingFile?.size || 0,
                headersJson: JSON.stringify(parsedFile.headers || []),
                rowsJson: JSON.stringify(parsedFile.rows || []),
                fileBodyBase64: parsedFile.fileBodyBase64 || null,
                fileMimeType: this.pendingFile?.type || null
            });
            if (!result?.success) {
                this.uploadRejectMessage = result?.errorMessage || 'Upload failed. Please review your file.';
                this.uploadSummary = null;
                this.uploadMessage = '';
                this.showToast('Upload failed', this.uploadRejectMessage, 'error');
                return;
            }

            this.uploadRejectMessage = '';
            this.uploadSummary = this.buildUploadSummary(result);
            this.uploadMessage = result?.message || result?.uploadResult?.message || 'Upload completed successfully.';
            this.showToast('Upload completed', this.uploadMessage, 'success');
            this.dispatchUploadEvents(result.uploadResult || {});
            this.resetState();
            this.handleCancel();
        } catch (e) {
            this.uploadRejectMessage = this.reduceError(e);
            this.uploadSummary = null;
            this.uploadMessage = '';
            this.showToast('Upload failed', this.uploadRejectMessage, 'error');
        } finally {
            this.isUploading = false;
        }
    }

    validateSelectedFile(file) {
        if (!file) {
            return {
                success: false,
                errorMessage: 'Please select a file to upload.'
            };
        }

        const fileExtension = file.name.split('.').pop()?.toLowerCase();
        if (!ALLOWED_EXTENSIONS.includes(fileExtension)) {
            return {
                success: false,
                errorMessage: 'Invalid File Format: Please upload the approved Excel / CSV template only.'
            };
        }

        if (file.size > MAX_FILE_SIZE) {
            return {
                success: false,
                errorMessage: 'Upload File Exceeds Size Limit: The selected file exceeds the configured file-size limit.'
            };
        }

        return { success: true };
    }

    dispatchUploadEvents(result) {
        const eventDetail = result || {};
        this.dispatchEvent(new CustomEvent('success', { detail: eventDetail, bubbles: true, composed: true }));
        this.dispatchEvent(new CustomEvent('uploadsuccess', { detail: eventDetail, bubbles: true, composed: true }));
        this.dispatchEvent(new CustomEvent('refresh', { detail: eventDetail, bubbles: true, composed: true }));
    }

    buildUploadSummary(result) {
        const uploadResult = result?.uploadResult || {};
        const totalRows = Number(uploadResult.totalRows ?? result?.totalRows ?? 0);
        const successRows = Number(uploadResult.successRows ?? uploadResult.successCount ?? 0);
        const exceptionRows = Number(uploadResult.exceptionRows ?? uploadResult.exceptionCreatedCount ?? 0);
        return {
            totalRows,
            successRows,
            exceptionRows,
            createdContacts: Number(uploadResult.createdContacts ?? uploadResult.successCount ?? successRows),
            createdExceptions: Number(uploadResult.createdExceptions ?? uploadResult.exceptionCreatedCount ?? exceptionRows)
        };
    }

    resetState() {
        this.batchName = '';
        this.fileName = '';
        this.pendingFile = null;
        this.uploadRejectMessage = '';
        this.uploadSummary = null;
        this.uploadMessage = '';
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
        this.close();
    }

    handleBackdropClick() {
        this.handleCancel();
    }

    handleDialogClick(event) {
        event.stopPropagation();
    }

    async parseExcelFile(file) {
        const buffer = await readAsArrayBuffer(file);
        const workbook = window.XLSX.read(buffer, { type: 'array', cellDates: true });
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

            rows.push({
                rowNumber: i + 1,
                email: this.resolveCellValue(line, colIndex.email),
                fullName: this.resolveCellValue(line, colIndex.fullName),
                idType: this.resolveCellValue(line, colIndex.idType),
                idNumber: this.resolveCellValue(line, colIndex.idNumber),
                dateOfBirth: this.resolveDateCellValue(line, colIndex.dateOfBirth),
                employmentStatus: this.resolveCellValue(line, colIndex.employmentStatus)
            });
        }
        return {
            headers: headerRow,
            rows,
            fileBodyBase64: this.arrayBufferToBase64(buffer)
        };
    }

    arrayBufferToBase64(buffer) {
        if (!buffer) {
            return '';
        }
        const bytes = new Uint8Array(buffer);
        const chunkSize = 0x8000;
        let binary = '';
        for (let i = 0; i < bytes.length; i += chunkSize) {
            const chunk = bytes.subarray(i, i + chunkSize);
            binary += String.fromCharCode.apply(null, chunk);
        }
        return btoa(binary);
    }

    resolveHeaderIndexes(headerRow) {
        const normalized = headerRow.map((h) => String(h ?? '').trim().toLowerCase());
        const indexes = {};

        for (const def of REQUIRED_HEADER_DEFS) {
            let idx = -1;
            for (const label of def.labels) {
                const found = normalized.findIndex((h) => h === label);
                if (found >= 0) {
                    idx = found;
                    break;
                }
            }
            if (idx < 0) {
                throw new Error(`Missing required column: ${def.labels[0]}`);
            }
            indexes[def.key] = idx;
        }

        return indexes;
    }

    resolveCellValue(line, index) {
        if (index === undefined || index < 0) {
            return '';
        }
        return String(line[index] ?? '').trim();
    }

    resolveDateCellValue(line, index) {
        if (index === undefined || index < 0) {
            return '';
        }
        return this.normalizeDate(line[index]) || '';
    }

    normalizeDate(raw) {
        if (raw === null || raw === undefined || raw === '') {
            return '';
        }
        if (raw instanceof Date && !Number.isNaN(raw.getTime())) {
            return this.toIsoDate(raw);
        }
        if (typeof raw === 'number' && window.XLSX?.SSF?.parse_date_code) {
            const parsed = window.XLSX.SSF.parse_date_code(raw);
            if (parsed) {
                const d = new Date(parsed.y, parsed.m - 1, parsed.d);
                return this.toIsoDate(d);
            }
        }
        const s = String(raw).trim();
        if (DATE_REGEX.test(s) && this.isValidIsoDate(s)) {
            return s;
        }
        return s;
    }

    isValidIsoDate(s) {
        const m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (!m) {
            return false;
        }
        const y = Number(m[1]);
        const mo = Number(m[2]);
        const d = Number(m[3]);
        const dt = new Date(y, mo - 1, d);
        return dt.getFullYear() === y && dt.getMonth() === mo - 1 && dt.getDate() === d;
    }

    toIsoDate(dt) {
        const y = dt.getFullYear();
        const m = String(dt.getMonth() + 1).padStart(2, '0');
        const d = String(dt.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
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