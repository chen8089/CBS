public with sharing class UploadSourceService {
    public static final String SOURCE_CONSENT_UPLOAD = 'Consent Upload';
    public static final String SOURCE_DEPARTURE_UPLOAD = 'Departure Upload';
    public static final String SOURCE_REPORT_UPLOAD = 'Report Upload';

    public static String consentUploadSource() {
        return SOURCE_CONSENT_UPLOAD;
    }

    public static String departureUploadSource() {
        return SOURCE_DEPARTURE_UPLOAD;
    }

    public static String reportUploadSource() {
        return SOURCE_REPORT_UPLOAD;
    }
}