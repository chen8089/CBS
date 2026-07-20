import { LightningElement, track } from 'lwc';
import cbsLogo from '@salesforce/resourceUrl/cbsLogo';
import resetPassword from '@salesforce/apex/CbsForgotPasswordController.resetPassword';

const DEFAULT_LOGIN_PATH = '/s/login';
const GENERIC_ERROR_MESSAGE = 'We could not process your request right now. Please try again later.';

export default class CbsForgotPassword extends LightningElement {
    logoUrl = cbsLogo;
    showLogo = true;

    @track username = '';
    @track message = '';
    @track isSuccess = false;
    @track isLoading = false;

    get continueButtonLabel() {
        return this.isLoading ? 'Sending...' : 'Reset Password';
    }

    get messageClass() {
        return this.isSuccess ? 'message success-message' : 'message error-message';
    }

    handleLogoError() {
        this.showLogo = false;
    }

    handleUsernameChange(event) {
        this.username = event.target.value;
        if (this.message && !this.isSuccess) {
            this.message = '';
        }
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleContinue();
        }
    }

    async handleContinue() {
        if (this.isLoading) {
            return;
        }

        const normalizedUsername = (this.username || '').trim();
        if (!normalizedUsername) {
            this.isSuccess = false;
            this.message = 'Please enter your username.';
            return;
        }

        this.isLoading = true;
        this.message = '';

        try {
            const responseMessage = await resetPassword({ username: normalizedUsername });
            this.isSuccess = true;
            this.message = responseMessage;
        } catch (error) {
            this.isSuccess = false;
            this.message = this.resolveErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        window.location.href = this.getLoginUrl();
    }

    getLoginUrl() {
        return `${this.getCommunityBasePath()}/login`;
    }

    getCommunityBasePath() {
        const pathName = (window.location && window.location.pathname) || '';
        const marker = '/s/';
        const markerIndex = pathName.indexOf(marker);

        if (markerIndex > -1) {
            return pathName.substring(0, markerIndex + 2);
        }

        if (pathName.endsWith('/s')) {
            return pathName;
        }

        return DEFAULT_LOGIN_PATH.replace('/login', '');
    }

    resolveErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return GENERIC_ERROR_MESSAGE;
    }
}