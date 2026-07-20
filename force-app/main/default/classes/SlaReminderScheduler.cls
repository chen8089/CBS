public without sharing class SlaReminderScheduler implements Schedulable {
    @TestVisible
    private static final Integer DEFAULT_BATCH_SIZE = 200;
    @TestVisible
    private static final String DEFAULT_CRON = '0 0 9 * * ?';

    public void execute(SchedulableContext context) {
        Database.executeBatch(new SlaReminderBatch(), DEFAULT_BATCH_SIZE);
    }

    public static Id scheduleDailyJob() {
        return System.schedule('SLA Reminder Daily Job', DEFAULT_CRON, new SlaReminderScheduler());
    }
}