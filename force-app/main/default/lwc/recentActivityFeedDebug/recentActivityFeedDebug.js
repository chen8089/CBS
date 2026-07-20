import { LightningElement, api, wire } from 'lwc';
import getContactDebugInfo from '@salesforce/apex/RecentActivityFeedDebugController.getContactDebugInfo';

export default class RecentActivityFeedDebug extends LightningElement {
    @api maxRecords;

    wiredResult;

    @wire(getContactDebugInfo, {
        maxRecords: '$normalizedMaxRecords'
    })
    wiredContactDebugInfo(result) {
        this.wiredResult = result;
    }

    get normalizedMaxRecords() {
        const parsedValue = Number(this.maxRecords);
        return Number.isFinite(parsedValue) ? parsedValue : null;
    }

    get data() {
        return this.wiredResult?.data;
    }

    get error() {
        return this.wiredResult?.error;
    }

    get isLoading() {
        return !this.data && !this.error;
    }

    get hasData() {
        return Boolean(this.data);
    }

    get hasErrors() {
        return this.data?.errors?.length > 0;
    }

    get apexErrorMessage() {
        return this.reduceError(this.error);
    }

    get contactRecordsJson() {
        return this.formatJson(this.data?.contactRecordsSample);
    }

    get feedJson() {
        return this.formatJson(this.data?.feedSample);
    }

    get feedTrackedChangeJson() {
        return this.formatJson(this.data?.feedTrackedChangeSample);
    }

    get trackedFieldNamesText() {
        return this.data?.trackedFieldNames?.length > 0 ? this.data.trackedFieldNames.join(', ') : '';
    }

    formatJson(value) {
        return JSON.stringify(value || [], null, 2);
    }

    reduceError(error) {
        if (!error) {
            return null;
        }

        if (Array.isArray(error.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }

        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }

        if (typeof error.message === 'string') {
            return error.message;
        }

        return JSON.stringify(error);
    }
}