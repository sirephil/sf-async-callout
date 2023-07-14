/*
 * MIT License. See the associated LICENSE file.
 * 
 * Copyright sirephil (c) 2023.
 */

/**
 * Initiates the sending queueable when some commands are available.
 */
public without sharing class CommandProcessor implements EventProcessor {
    // apexdoc inherited
    public void process(TriggeredEvent__e event) {
        // This code has no error handling for simplicity.
        // The following queries would normally be done in Selectors, but are inline to simplify the code.

        // Ensure any commands for records currently queued or being sent get ignored. Note that this query
        // takes advantage of the fact that an AggregateResult is actually a type of SObject, and by mapping
        // the field of interest (here the RecordId__c) to the name "Id", the quick conversion of an array of
        // SObjects to a Map of SObjects by Id can be used. This improves performance by avoiding any
        // iteration in the apex code itself
        Set<Id> sendingCommandRecordIds = new Map<Id, SObject>([
                SELECT RecordId__c Id FROM Command__c WHERE Status__c = 'Sending' GROUP BY RecordId__c
        ]).keySet();

        // Note that this query has a specific limit to ensure that at most 100 callouts are made in a single
        // execution, and uses the oldest commands available first. Because of the ORDER BY it is not possible
        // to apply a FOR UPDATE, but this should be the only place where pending commands are being processed
        // (and this should only be called in single threaded manner)
        Set<Id> commandIds = new Map<Id, Command__c>([
                SELECT Id
                    FROM Command__c
                    WHERE Id NOT IN :sendingCommandRecordIds
                        AND Status__c = 'Pending'
                    ORDER BY CreatedDate ASC
                    LIMIT 100
        ]).keySet();

        List<Command__c> updates = new List<Command__c>();

        // Update the sent commands to indicate they are now sending
        for (Id commandId : commandIds) {
            updates.add(new Command__c(
                    Id = commandId,
                    Status__c = 'Sending'));
        }

        update updates;

        // Enqueue sending of these commands
        System.enqueueJob(new CommandSender(commandIds));
    }

    // apexdoc inherited
    public Boolean needsMoreProcessing() {
        // Note that this query (which would normally be done in a Selector) is used to test
        // whether there are more commands to be processed.
        return [SELECT COUNT() FROM Command__c WHERE Status__c = 'Pending'] != 0;
    }
}