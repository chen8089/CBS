import { LightningElement, api } from 'lwc';
import cbsAssets from '@salesforce/resourceUrl/cbsAssets';

export default class CbsHomeLandingSection extends LightningElement {
    @api bannerTitle;
    @api bannerDescription;
    @api buttonLabel;

    hasLoggedElements = false;

    get resolvedBannerTitle() {
        return this.bannerTitle || 'Credit Bureau Singapore';
    }

    get resolvedBannerDescription() {
        return (
            this.bannerDescription ||
            'Empowering better credit decisions with trusted data and insights.'
        );
    }

    get resolvedButtonLabel() {
        return this.buttonLabel || 'Learn More';
    }

    get bannerBackgroundStyle() {
        return `background-image:
            linear-gradient(120deg, rgba(8, 36, 84, 0.78), rgba(0, 118, 188, 0.55)),
            url("${cbsAssets}/images/home-banner.svg");`;
    }

    renderedCallback() {
        if (this.hasLoggedElements) {
            return;
        }

        const bannerCaptionEl = this.template.querySelector('.banner_caption');
        const homeSecEl = this.template.querySelector('.home-sec-1');

        // eslint-disable-next-line no-console
        console.log('[cbsHomeLandingSection] banner_caption found:', Boolean(bannerCaptionEl));
        // eslint-disable-next-line no-console
        console.log('[cbsHomeLandingSection] home-sec-1 found:', Boolean(homeSecEl));

        this.hasLoggedElements = true;
    }
}