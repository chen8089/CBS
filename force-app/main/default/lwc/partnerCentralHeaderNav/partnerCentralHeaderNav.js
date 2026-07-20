import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PartnerCentralHeaderNav extends NavigationMixin(LightningElement) {
    @api moduleLabel = 'Consent';
    @api modulePageName = 'Consent';
    @api moduleUrl = '';
    @api currentPageLabel = 'Data Subjects';
    @api currentPageName = 'Data_Subjects';
    @api headerTitle = 'Partner Community';
    @api homeUrl = '/partnercommunity/s/';
    @api officialSiteUrl = 'https://www.creditbureau.com.sg/';
    @api contactEmail = 'consumer_services@creditbureau.com.sg';
    @api supportHotline = '+65 6565 6363';
    @api showQuickActions;

    @api showSubNavigation = false;

    @api navItemsJson = '[]';

    handleModuleClick(event) {
        event.preventDefault();
        const name =
            this.modulePageName != null ? String(this.modulePageName).trim() : '';
        const url = this.moduleUrl != null ? String(this.moduleUrl).trim() : '';
        if (!name) {
            if (url) {
                window.location.assign(url);
                return;
            }
            console.warn('partnerCentralHeaderNav: modulePageName is empty; cannot navigate.');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to navigate',
                    message: 'Module page name is missing.',
                    variant: 'error'
                })
            );
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name
            }
        });
    }
}