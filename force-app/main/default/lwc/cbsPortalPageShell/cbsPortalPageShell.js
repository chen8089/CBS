import { LightningElement, api } from 'lwc';

export default class CbsPortalPageShell extends LightningElement {
    @api pageTitle = 'Page Title';
    @api subtitle = '';
    @api breadcrumbText = '';
    _useCardBody = true;

    @api
    get useCardBody() {
        return this._useCardBody;
    }

    set useCardBody(value) {
        this._useCardBody = value !== false && value !== 'false';
    }

    get showBreadcrumb() {
        return !!(this.breadcrumbText && this.breadcrumbText.trim());
    }

    get bodyClass() {
        return `shell-body${this.useCardBody ? ' card-body' : ''}`;
    }
}