import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

const DEFAULT_ITEMS = [
    { label: 'Home', pageName: 'Home' },
    { label: 'Consent', pageName: 'Consent' },
    { label: 'Resignation / Departure', pageName: 'Resignation_Departure' },
    { label: 'Report Requests', pageName: 'Report_Requests' },
    { label: 'Batch', pageName: 'Batch' },
    { label: 'Exceptions', pageName: 'Exceptions' }
];

export default class CbsPortalNavigation extends NavigationMixin(LightningElement) {
    @api navItemsJson = JSON.stringify(DEFAULT_ITEMS);
    @api homePageName = 'Home';
    @api homeUrl = '/s/';

    isMobileMenuOpen = false;
    currentPageName = '';
    currentPathname = '';

    @wire(CurrentPageReference)
    capturePageReference(pageRef) {
        this.currentPageName = pageRef?.attributes?.name || '';
        this.currentPathname = typeof window !== 'undefined' ? window.location.pathname : '';
    }

    get resolvedNavItems() {
        const parsed = this.parseNavItems();
        return parsed.map((item, index) => {
            const key = `${item.label}-${index}`;
            const href = item.url || '#';
            const active = this.isItemActive(item);
            return {
                ...item,
                key,
                href,
                className: `nav-link${active ? ' is-active' : ''}`
            };
        });
    }

    parseNavItems() {
        try {
            const parsed = JSON.parse(this.navItemsJson);
            if (Array.isArray(parsed) && parsed.length > 0) {
                return parsed.filter((item) => item && item.label && (item.pageName || item.url));
            }
        } catch (error) {
            // Falls back to default values when JSON is invalid.
        }
        return DEFAULT_ITEMS;
    }

    isItemActive(item) {
        if (item.pageName && this.currentPageName) {
            const itemName = item.pageName.toLowerCase();
            const currentName = this.currentPageName.toLowerCase();
            return currentName === itemName || currentName.endsWith(`/${itemName}`);
        }
        if (item.url && this.currentPathname) {
            return this.currentPathname.includes(item.url.replace('/s/', ''));
        }
        return false;
    }

    toggleMobileMenu() {
        this.isMobileMenuOpen = !this.isMobileMenuOpen;
    }

    handleNavigate(event) {
        event.preventDefault();
        const pageName = event.currentTarget.dataset.pageName;
        const url = event.currentTarget.dataset.url;

        this.isMobileMenuOpen = false;

        if (pageName) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: pageName
                }
            });
            return;
        }

        if (url) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url
                }
            });
        }
    }
}