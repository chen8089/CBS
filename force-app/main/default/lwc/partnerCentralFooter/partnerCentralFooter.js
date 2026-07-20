import { LightningElement, api } from 'lwc';

export default class PartnerCentralFooter extends LightningElement {
    @api officialSiteUrl = 'https://www.creditbureau.com.sg/';
    @api faqUrl = 'https://www.creditbureau.com.sg/faqs.html';
    @api supportEmail = 'consumer_services@creditbureau.com.sg';
    @api supportHotline = '+65 6565 6363';
    @api officeAddress = '2 Shenton Way, #20-02 SGX Centre 1, Singapore 068804';
    @api copyrightText = '© Credit Bureau (Singapore) Pte Ltd';

    get contactMailTo() {
        return `mailto:${this.supportEmail}`;
    }
}