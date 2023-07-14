/*
 * MIT License. See the associated LICENSE file.
 * 
 * Copyright sirephil (c) 2023.
 */

/**
 * The handler for the TriggeredEvent__e platform event. This processes events to ensure that the
 * required processing is performed based on the first platform event's type. It also ensures that
 * any platform events for that same type are discarded and unique events for other types are
 * re-published.
 */
public without sharing class TriggeredEventHandler {
    /**
     * Provides access to the singleton event handler.
     *
     * @return the singleton instance for this event handler. Will not be null.
     */
    public static TriggeredEventHandler getInstance() {
        return (TriggeredEventHandler) SingletonFactory.get(TriggeredEventHandler.class);
    }

    /**
     * Allows the newly received platform events to be processed.
     *
     * @param events the platform events to be processed. Will not be null and generally won't be empty.
     */
    public void process(TriggeredEvent__e[] events) {
        // This code has no error handling for simplicity.
        Set<String> otherTypes = new Set<String>();
        TriggeredEvent__e[] chain = new List<TriggeredEvent__e>();
        String currentType = events[0].Type__c;

        // Collate the set of other, unique types. Due to the way Set actually maintains order of insertion, these
        // unique types will be in the order in which they are first found in the events.
        for (TriggeredEvent__e event : events) {
            if (event.Type__c != currentType) {
                otherTypes.add(event.Type__c);
            }
        }

        // Make sure to chain the other types that are not being handled in this execution. That ensures
        // this execution has maximum limits available for the selected processing while also ensuring
        // that these other types will subsequently get processed.
        for (String type : otherTypes) {
            chain.add(new TriggeredEvent__e(Type__c = type));
        }

        // Instantiate the processor needed to handle this type of event.
        EventProcessor processor = (EventProcessor) SingletonFactory.get(Type.forName(currentType));

        // Have the processor do its processing
        processor.process(events[0]);

        // Check to see if the processor still needs more processing to be done.
        if (processor.needsMoreProcessing()) {
            // Since more processing is required, make sure this type will be processed again
            // shortly, after any other types that are already pending.
            chain.add(new TriggeredEvent__e(Type__c = currentType));
        }

        // Make sure pending types get processed.
        EventBus.publish(chain);
    }
}