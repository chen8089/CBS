import { LightningElement, api } from 'lwc';

export default class CbsPortalFooter extends LightningElement {
    @api privacyUrl = '/privacy-policy';
    @api termsUrl = '/terms-of-use';
    @api contactUsUrl = '/contact-us';

    get currentYear() {
        return new Date().getFullYear();
    }
}