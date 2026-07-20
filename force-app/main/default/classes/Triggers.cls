public class Triggers {
    /**
        Enum representing each of before/after CRUD events on Sobjects
    */
    public enum Evt {
        afterdelete, afterinsert, afterundelete,
        afterupdate, beforedelete, beforeinsert, beforeupdate
    }

    /**
        Simplistic handler to implement on any of the event. It doesn't requires or enforces any patter except the
        method name to be "handle()", a developer is free to use any Trigger context variable or reuse any other
        apex class here.
    */
    public interface Handler {
        void handle();
    }

    // Internal mapping of handlers
    Map<String, List<Handler>> eventHandlerMapping = new Map<String, List<Handler>>();

    /**
        Core API to bind handlers with events
    */
    public Triggers bind(Evt event, Handler eh) {
        List<Handler> handlers = eventHandlerMapping.get(event.name());
        if (handlers == null) {
            handlers = new List<Handler>();
            eventHandlerMapping.put(event.name(), handlers);
        }
        handlers.add(eh);
        return this;
    }

    /**
        Invokes correct handlers as per the context of trigger and available registered handlers
    */
    public void manage() {
        Evt ev = resolveEvent(
            Trigger.isInsert,
            Trigger.isBefore,
            Trigger.isAfter,
            Trigger.isUpdate,
            Trigger.isDelete,
            Trigger.isUndelete
        );
        manage(ev);
    }

    @TestVisible
    void manage(Evt ev) {
        if (ev == null) {
            return;
        }
        List<Handler> handlers = eventHandlerMapping.get(ev.name());
        if (handlers != null && !handlers.isEmpty()) {
            for (Handler h : handlers) {
                h.handle();
            }
        }
    }

    @TestVisible
    static Evt resolveEvent(
        Boolean isInsert,
        Boolean isBefore,
        Boolean isAfter,
        Boolean isUpdate,
        Boolean isDelete,
        Boolean isUndelete
    ) {
        if (isInsert && isBefore) {
            return Evt.beforeinsert;
        } else if (isInsert && isAfter) {
            return Evt.afterinsert;
        } else if (isUpdate && isBefore) {
            return Evt.beforeupdate;
        } else if (isUpdate && isAfter) {
            return Evt.afterupdate;
        } else if (isDelete && isBefore) {
            return Evt.beforedelete;
        } else if (isDelete && isAfter) {
            return Evt.afterdelete;
        } else if (isUndelete) {
            return Evt.afterundelete;
        }
        return null;
    }
}