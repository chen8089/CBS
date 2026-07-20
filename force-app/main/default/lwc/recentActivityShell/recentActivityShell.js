import { LightningElement, api } from 'lwc';

const MOCK_ACTIVITIES = [
    {
        id: 'activity-1',
        title: 'Contact Status Changed',
        description:
            'Status for <strong>PL-01384850</strong> has changed to <strong>Working</strong>',
        displayDate: '5月19日',
        iconName: 'standard:lead',
        recordId: 'PL-01384850'
    },
    {
        id: 'activity-2',
        title: 'Contact Converted',
        description:
            'Status for <strong>PL-01385509</strong> has changed to <strong>Converted</strong>',
        displayDate: '5月15日',
        iconName: 'standard:lead',
        recordId: 'PL-01385509'
    },
    {
        id: 'activity-3',
        title: 'Contact Status Changed',
        description:
            'Status for <strong>PL-01385509</strong> has changed to <strong>Working</strong>',
        displayDate: '5月13日',
        iconName: 'standard:lead',
        recordId: 'PL-01385509'
    },
    {
        id: 'activity-4',
        title: 'Contact Submitted',
        description:
            'Status for <strong>PL-01385509</strong> has changed to <strong>Submitted</strong>',
        displayDate: '5月12日',
        iconName: 'standard:lead',
        recordId: 'PL-01385509'
    },
    {
        id: 'activity-5',
        title: 'Contact Created',
        description: '<strong>PL-01385509</strong> created',
        displayDate: '5月12日',
        iconName: 'standard:lead',
        recordId: 'PL-01385509'
    },
    {
        id: 'activity-6',
        title: 'Contact Converted',
        description:
            'Status for <strong>PL-01383801</strong> has changed to <strong>Converted</strong>',
        displayDate: '5月11日',
        iconName: 'standard:lead',
        recordId: 'PL-01383801'
    },
    {
        id: 'activity-7',
        title: 'Contact Submitted',
        description:
            'Status for <strong>PL-01384850</strong> has changed to <strong>Submitted</strong>',
        displayDate: '5月07日',
        iconName: 'standard:lead',
        recordId: 'PL-01384850'
    },
    {
        id: 'activity-8',
        title: 'Contact Created',
        description: '<strong>PL-01384850</strong> created',
        displayDate: '5月07日',
        iconName: 'standard:lead',
        recordId: 'PL-01384850'
    }
];

export default class RecentActivityShell extends LightningElement {
    @api title = 'Recent Activity';
    @api maxHeight = '60rem';

    _showMockData = true;

    @api
    get showMockData() {
        return this._showMockData;
    }

    set showMockData(value) {
        if (value === undefined || value === null || value === '') {
            this._showMockData = true;
            return;
        }

        this._showMockData = value === true || value === 'true';
    }

    get activitiesToDisplay() {
        return this.showMockData ? MOCK_ACTIVITIES : [];
    }

    get activityCount() {
        return this.activitiesToDisplay.length;
    }

    get hasActivities() {
        return this.activityCount > 0;
    }

    get cardTitle() {
        return `${this.title} (${this.activityCount})`;
    }

    renderedCallback() {
        this.template.host.style.setProperty('--activityMaxHeight', this.maxHeight);
    }

    handleViewClick(event) {
        event.preventDefault();

        const activityId = event.currentTarget.dataset.id;
        const activity = this.activitiesToDisplay.find((item) => item.id === activityId);

        // Placeholder action until real navigation or data wiring is added.
        // eslint-disable-next-line no-console
        console.log('View activity:', activity);
    }
}