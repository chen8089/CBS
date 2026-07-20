import { LightningElement, track } from 'lwc';
import login from '@salesforce/apex/CbsExperienceLoginController.login';
import resetPassword from '@salesforce/apex/CbsExperienceLoginController.resetPassword';
import cbsLogo from '@salesforce/resourceUrl/cbsLogo';
import cbsHomeAssets from '@salesforce/resourceUrl/cbsHomeAssets';

const REMEMBERED_USERNAME_KEY = 'cbsExperienceRememberedUsername';
const DEFAULT_START_URL = '/s/';
const LOGIN_FAILED_MESSAGE = 'Your login attempt has failed. Please check your username and password.';
const RESET_PASSWORD_ERROR_MESSAGE = 'Unable to process your request. Please try again.';

export default class CbsExperienceLogin extends LightningElement {
    logoUrl = cbsLogo;
    mainSlantUrl = `${cbsHomeAssets}/images/main_slant.svg`;
    showLogo = true;

    @track username = '';
    @track password = '';
    @track rememberMe = false;
    @track errorMessage = '';
    @track successMessage = '';
    @track isLoading = false;
    @track showCapsLockWarning = false;
    @track forgotPasswordUsername = '';

    mode = 'login';

    startUrl = DEFAULT_START_URL;

    connectedCallback() {
        this.startUrl = this.getStartUrlFromQuery();
        this.loadRememberedUsername();
    }

    get loginButtonLabel() {
        return this.isLoading ? 'Logging in...' : 'Log In';
    }

    get forgotPasswordButtonLabel() {
        return this.isLoading ? 'Sending...' : 'Reset Password';
    }

    get isLoginMode() {
        return this.mode === 'login';
    }

    get isForgotPasswordMode() {
        return this.mode === 'forgotPassword';
    }

    get isForgotPasswordSuccessMode() {
        return this.mode === 'forgotPasswordSuccess';
    }

    get rightPanelStyle() {
        return `background-image: url(${this.mainSlantUrl});`;
    }

    handleLogoError() {
        this.showLogo = false;
    }

    handleUsernameChange(event) {
        this.username = event.target.value;
    }

    handlePasswordChange(event) {
        this.password = event.target.value;
        this.updateCapsLockState(event);
    }

    handleRememberMeChange(event) {
        this.rememberMe = event.target.checked;
        if (!this.rememberMe) {
            this.clearRememberedUsername();
        }
    }

    handleInputKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleLogin();
            return;
        }

        if (event.target.name === 'password') {
            this.updateCapsLockState(event);
        }
    }

    handlePasswordBlur() {
        this.showCapsLockWarning = false;
    }

    async handleLogin() {
        if (!this.isLoginMode) {
            return;
        }

        if (this.isLoading) {
            return;
        }

        this.errorMessage = '';
        this.successMessage = '';

        const normalizedUsername = (this.username || '').trim();
        if (!normalizedUsername) {
            this.errorMessage = 'Please enter your username.';
            return;
        }

        if (!this.password) {
            this.errorMessage = 'Please enter your password.';
            return;
        }

        this.isLoading = true;

        try {
            const redirectUrl = await login({
                username: normalizedUsername,
                password: this.password,
                rememberMe: this.rememberMe,
                startUrl: this.startUrl
            });

            if (this.rememberMe) {
                this.rememberUsername(normalizedUsername);
            } else {
                this.clearRememberedUsername();
            }

            window.location.href = redirectUrl || DEFAULT_START_URL;
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleForgotPasswordClick(event) {
        event.preventDefault();
        if (this.isLoading) {
            return;
        }

        this.mode = 'forgotPassword';
        this.errorMessage = '';
        this.successMessage = '';
        this.forgotPasswordUsername = (this.username || '').trim();
    }

    handleForgotPasswordUsernameChange(event) {
        this.forgotPasswordUsername = event.target.value;
    }

    handleForgotPasswordInputKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleForgotPasswordContinue();
        }
    }

    handleForgotPasswordCancel() {
        if (this.isLoading) {
            return;
        }

        this.mode = 'login';
        this.forgotPasswordUsername = '';
        this.errorMessage = '';
        this.successMessage = '';
    }

    async handleForgotPasswordContinue() {
        if (this.isLoading) {
            return;
        }

        const normalizedUsername = (this.forgotPasswordUsername || '').trim();
        if (!normalizedUsername) {
            this.errorMessage = 'Please enter your username.';
            this.successMessage = '';
            return;
        }

        this.errorMessage = '';
        this.successMessage = '';
        this.isLoading = true;

        try {
            const message = await resetPassword({ username: normalizedUsername });
            this.successMessage = message;
            this.mode = 'forgotPasswordSuccess';
            this.forgotPasswordUsername = '';
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error, RESET_PASSWORD_ERROR_MESSAGE);
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToLogin() {
        if (this.isLoading) {
            return;
        }

        this.mode = 'login';
        this.errorMessage = '';
        this.successMessage = '';
        this.forgotPasswordUsername = '';
    }

    updateCapsLockState(event) {
        this.showCapsLockWarning = Boolean(
            event &&
            typeof event.getModifierState === 'function' &&
            event.getModifierState('CapsLock')
        );
    }

    getStartUrlFromQuery() {
        const params = new URLSearchParams(window.location.search || '');
        const requestedStartUrl = params.get('startURL') || params.get('startUrl');
        return this.normalizeStartUrl(requestedStartUrl);
    }

    normalizeStartUrl(value) {
        if (!value) {
            return DEFAULT_START_URL;
        }

        const trimmed = value.trim();
        const lowered = trimmed.toLowerCase();
        if (!trimmed.startsWith('/')) {
            return DEFAULT_START_URL;
        }

        if (lowered.startsWith('http://') || lowered.startsWith('https://') || lowered.startsWith('//')) {
            return DEFAULT_START_URL;
        }

        return trimmed;
    }

    loadRememberedUsername() {
        try {
            const remembered = window.localStorage.getItem(REMEMBERED_USERNAME_KEY);
            if (remembered) {
                this.username = remembered;
                this.rememberMe = true;
            }
        } catch (e) {
            this.rememberMe = false;
        }
    }

    rememberUsername(username) {
        try {
            window.localStorage.setItem(REMEMBERED_USERNAME_KEY, username);
        } catch (e) {
            // Ignore localStorage unavailability.
        }
    }

    clearRememberedUsername() {
        try {
            window.localStorage.removeItem(REMEMBERED_USERNAME_KEY);
        } catch (e) {
            // Ignore localStorage unavailability.
        }
    }

    resolveErrorMessage(error, fallbackMessage = LOGIN_FAILED_MESSAGE) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return fallbackMessage;
    }
}