import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import cbsLogo from '@salesforce/resourceUrl/cbsLogo';

export default class CbsPortalHeader extends NavigationMixin(LightningElement) {
    @api logoUrl = '';
    @api homeUrl = '/s/';
    @api officialSiteUrl = 'https://www.creditbureau.com.sg';
    @api logoutUrl = '/secur/logout.jsp';
    _showStickyHeader = true;
    _showUserMenu = true;

    userDisplayName = '';

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

    @wire(getRecord, { recordId: userId, fields: [USER_NAME_FIELD] })
    wiredUser({ data }) {
        if (data) {
            this.userDisplayName = data.fields.Name.value;
        }
    }

    get computedLogoUrl() {
        return this.logoUrl && this.logoUrl.trim() ? this.logoUrl : cbsLogo;
    }

    get profileLabel() {
        return this.userDisplayName ? this.userDisplayName : 'My Profile';
    }

    get headerClass() {
        return `cbs-header${this.showStickyHeader ? ' sticky' : ''}`;
    }

    handleUserMenuSelect(event) {
        const action = event.detail.value;
        if (action === 'logout') {
            this.handleLogout();
            return;
        }
        if (action === 'profile') {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/s/profile'
                }
            });
        }
    }

    handleLogout() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: this.logoutUrl
            }
        });
    }
}