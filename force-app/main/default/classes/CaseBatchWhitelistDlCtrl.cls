public without sharing class CaseBatchWhitelistDlCtrl {
    private static final List<String> EXPORT_HEADERS = new List<String>{
        'Principal Name',
        'NRIC / FIN',
        'Pass Type',
        'Passport Number',
        'Date of Birth',
        'Gender'
    };
    private static final List<String> REQUESTED_FIELDS = new List<String>{
        'Data_Subject__c',
        'Consent__c',
        'Eligibility_Status__c',
        'Consent_Revalidation_Status__c',
        'Delivery_Status__c',
        'SLA_Due_Date__c'
    };

    public String csvBody { get; private set; }
    public String fileName { get; private set; }
    public String errorMessage { get; private set; }

    public CaseBatchWhitelistDlCtrl() {
        csvBody = '';
        fileName = buildFileName('latest');
        errorMessage = null;
        try {
            ReportRequestExportService.BatchExportResult exportResult =
                ReportRequestExportService.exportAuthorizedListForLatestBatchNoTracking(REQUESTED_FIELDS);
            csvBody = exportResult == null || exportResult.csvBody == null ? '' : exportResult.csvBody;
            csvBody = keepOnlyRequiredHeaders(csvBody);
            csvBody = ensureExcelDelimiter(csvBody);
            fileName = buildFileName(exportResult == null ? null : exportResult.batchReference);
            applyDownloadHeaders(fileName);
        } catch (Exception ex) {
            errorMessage = reduceError(ex);
            csvBody = 'Export Failed,' + sanitizeForCsv(errorMessage) + '\n';
            csvBody = ensureExcelDelimiter(csvBody);
            fileName = buildFileName('error');
            applyDownloadHeaders(fileName);
        }
    }

    private static String buildFileName(String batchReference) {
        String normalizedBatch = String.isBlank(batchReference)
            ? 'latest'
            : batchReference.replaceAll('[^A-Za-z0-9._-]', '-');
        return 'credit-whitelist-' + normalizedBatch + '.csv';
    }

    private static void applyDownloadHeaders(String resolvedFileName) {
        if (ApexPages.currentPage() == null) {
            return;
        }
        String downloadName = String.isBlank(resolvedFileName)
            ? 'credit-whitelist-latest.csv'
            : resolvedFileName;
        ApexPages.currentPage().getHeaders().put('Content-Type', 'text/csv; charset=UTF-8');
        ApexPages.currentPage().getHeaders().put('Content-Disposition', 'attachment; filename=' + downloadName);
    }

    private static String reduceError(Exception ex) {
        if (ex == null) {
            return 'Unknown error';
        }
        String message = ex.getMessage();
        return String.isBlank(message) ? 'Unknown error' : message;
    }

    private static String sanitizeForCsv(String rawValue) {
        if (rawValue == null) {
            return '';
        }
        return '"' + rawValue.replace('"', '""') + '"';
    }

    private static String ensureExcelDelimiter(String rawCsv) {
        if (String.isBlank(rawCsv)) {
            return rawCsv;
        }
        if (rawCsv.startsWith('sep=,')) {
            return rawCsv;
        }
        return 'sep=,\n' + rawCsv;
    }

    private static String keepOnlyRequiredHeaders(String rawCsv) {
        if (String.isBlank(rawCsv)) {
            return rawCsv;
        }
        String normalizedCsv = rawCsv.startsWith('sep=,\n')
            ? rawCsv.substring('sep=,\n'.length())
            : rawCsv;
        List<String> lines = normalizedCsv.split('\n');
        if (lines.isEmpty()) {
            return normalizedCsv;
        }
        List<String> headerColumns = parseCsvLine(lines[0]);
        Map<String, Integer> indexByHeader = new Map<String, Integer>();
        for (Integer i = 0; i < headerColumns.size(); i++) {
            indexByHeader.put(headerColumns[i], i);
        }

        List<String> filteredLines = new List<String>();
        filteredLines.add(String.join(EXPORT_HEADERS, ','));
        for (Integer lineIndex = 1; lineIndex < lines.size(); lineIndex++) {
            String line = lines[lineIndex];
            if (String.isBlank(line)) {
                continue;
            }
            List<String> rowColumns = parseCsvLine(line);
            List<String> selectedValues = new List<String>();
            for (String requiredHeader : EXPORT_HEADERS) {
                Integer sourceIndex = indexByHeader.get(requiredHeader);
                String rawValue = sourceIndex == null || sourceIndex >= rowColumns.size()
                    ? ''
                    : rowColumns[sourceIndex];
                selectedValues.add(sanitizeForCsv(rawValue));
            }
            filteredLines.add(String.join(selectedValues, ','));
        }
        return String.join(filteredLines, '\n');
    }

    private static List<String> parseCsvLine(String csvLine) {
        List<String> values = new List<String>();
        if (csvLine == null) {
            return values;
        }
        String current = '';
        Boolean inQuotes = false;
        for (Integer i = 0; i < csvLine.length(); i++) {
            String ch = csvLine.substring(i, i + 1);
            if (ch == '"') {
                if (inQuotes && i + 1 < csvLine.length() && csvLine.substring(i + 1, i + 2) == '"') {
                    current += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch == ',' && !inQuotes) {
                values.add(current);
                current = '';
            } else {
                current += ch;
            }
        }
        values.add(current);
        return values;
    }
}