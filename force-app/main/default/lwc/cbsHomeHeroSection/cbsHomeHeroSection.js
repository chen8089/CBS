import { LightningElement } from 'lwc';
import cbsHomeAssets from '@salesforce/resourceUrl/cbsHomeAssets';

export default class CbsHomeHeroSection extends LightningElement {
    get heroStyle() {
        return `background-image: 
            url("${cbsHomeAssets}/images/main_slant.svg"),
            linear-gradient(120deg, #0456a7 0%, #0f7adb 48%, #2f95ee 100%);`;
    }
}