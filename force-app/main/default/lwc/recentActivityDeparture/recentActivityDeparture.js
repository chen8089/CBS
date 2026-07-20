import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRecentActivities from '@salesforce/apex/RecentActivityDepartureController.getRecentActivities';

export default class RecentActivityDeparture extends NavigationMixin(LightningElement) {
    @api maxItems = 20;

    wiredResult;

    @wire(getRecentActivities, {
        maxItems: '$normalizedMaxItems'
    })
    wiredRecentActivities(result) {
        this.wiredResult = result;
    }

    get normalizedMaxItems() {
        const parsedMaxItems = Number(this.maxItems);
        return Number.isFinite(parsedMaxItems) && parsedMaxItems > 0 ? parsedMaxItems : 20;
    }

    get activitiesToDisplay() {
        return this.wiredResult?.data || [];
    }

    get error() {
        return this.wiredResult?.error;
    }

    get isLoading() {
        return !this.wiredResult?.data && !this.error;
    }

    get activityCount() {
        return this.activitiesToDisplay.length;
    }

    get hasActivities() {
        return this.activityCount > 0;
    }

    get cardTitle() {
        return `Recent Activity (${this.activityCount})`;
    }

    get errorMessage() {
        return this.reduceError(this.error);
    }

    renderedCallback() {
        this.template.host.style.setProperty('--activityMaxHeight', '43rem');
    }

    handleViewClick(event) {
        event.preventDefault();

        const activityId = event.currentTarget.dataset.id;
        const activity = this.activitiesToDisplay.find((item) => item.id === activityId);

        if (activity?.recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: activity.recordId,
                    objectApiName: 'Departure__c',
                    actionName: 'view'
                }
            });
        }
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