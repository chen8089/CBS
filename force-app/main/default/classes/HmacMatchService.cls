public without sharing class HmacMatchService {
    public interface SecretProvider {
        Blob getSecret();
    }

    public class MissingSecretException extends Exception {}

    @TestVisible
    private static SecretProvider provider;

    public static void setSecretProvider(SecretProvider injectedProvider) {
        provider = injectedProvider;
    }

    public static String normalizeIdNumber(String rawIdNumber) {
        if (String.isBlank(rawIdNumber)) {
            return '';
        }
        return rawIdNumber.replaceAll('\\s+', '').toUpperCase();
    }

    public static String normalizeDob(Date rawDob) {
        if (rawDob == null) {
            return '';
        }
        String monthValue = String.valueOf(rawDob.month()).leftPad(2, '0');
        String dayValue = String.valueOf(rawDob.day()).leftPad(2, '0');
        return rawDob.year() + '-' + monthValue + '-' + dayValue;
    }

    public static String computeHmacHex(String canonicalValue) {
        Blob secret = (provider == null) ? null : provider.getSecret();
        if (secret == null) {
            throw new MissingSecretException('HMAC secret provider is not configured.');
        }
        Blob payload = Blob.valueOf(canonicalValue == null ? '' : canonicalValue);
        Blob mac = Crypto.generateMac('HmacSHA256', payload, secret);
        return EncodingUtil.convertToHex(mac);
    }

    public static String computeCompositeMatchHmac(String clientIdNumber, Date clientDob, Id clientAccountId) {
        String canonical = String.join(
            new List<String>{
                normalizeIdNumber(clientIdNumber),
                normalizeDob(clientDob),
                String.valueOf(clientAccountId)
            },
            '|'
        );
        return computeHmacHex(canonical);
    }
}