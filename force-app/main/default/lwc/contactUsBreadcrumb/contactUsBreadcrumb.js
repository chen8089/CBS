import { LightningElement, api } from 'lwc';

export default class ContactUsBreadcrumb extends LightningElement {
    @api homeLabel = 'HOME';
    @api currentLabel = 'CONTACT US';
    @api homeUrl = '/partnercommunity/s';
    @api homePageName = 'Home';
    @api headerTitle = 'Partner Community';
    @api officialSiteUrl = 'https://www.creditbureau.com.sg/';
    @api contactEmail = 'consumer_services@creditbureau.com.sg';
    @api supportHotline = '+65 6565 6363';
    @api showQuickActions;
    @api maxWidth = '1280px';
    @api topSpacing = '24px';
    @api bottomSpacing = '24px';

    renderedCallback() {
        const wrapper = this.template.querySelector('.breadcrumb-wrapper');
        if (!wrapper) {
            return;
        }
        wrapper.style.setProperty('--breadcrumbMaxWidth', this.maxWidth);
        wrapper.style.setProperty('--breadcrumbTopSpacing', this.topSpacing);
        wrapper.style.setProperty('--breadcrumbBottomSpacing', this.bottomSpacing);
    }
}