import { LightningElement, api } from 'lwc';

const DEFAULT_NAV_ITEMS = [
    { label: 'Home', pageName: 'Home' },
    { label: 'Consent', pageName: 'Consent' },
    { label: 'Resignation / Departure', pageName: 'Resignation_Departure' },
    { label: 'Report Requests', pageName: 'Report_Requests' },
    { label: 'Batch', pageName: 'Batch' },
    { label: 'Exceptions', pageName: 'Exceptions' }
];

export default class CbsPortalThemeLayout extends LightningElement {
    @api logoUrl = '';
    @api homeUrl = '/s/';
    @api officialSiteUrl = 'https://www.creditbureau.com.sg';
    @api logoutUrl = '/secur/logout.jsp';
    @api homePageName = 'Home';
    @api privacyUrl = '/privacy-policy';
    @api termsUrl = '/terms-of-use';
    @api contactUsUrl = '/contact-us';
    _showStickyHeader = true;
    _showUserMenu = true;

    _navItemsJson = JSON.stringify(DEFAULT_NAV_ITEMS);

    @api
    get showStickyHeader() {
        return this._showStickyHeader;
    }

    set showStickyHeader(value) {
        this._showStickyHeader = value !== false && value !== 'false';
    }

    @api
    get showUserMenu() {
        return this._showUserMenu;
    }

    set showUserMenu(value) {
        this._showUserMenu = value !== false && value !== 'false';
    }

    @api
    get navItemsJson() {
        return this._navItemsJson;
    }

    set navItemsJson(value) {
        this._navItemsJson = value && value.trim() ? value : JSON.stringify(DEFAULT_NAV_ITEMS);
    }
}