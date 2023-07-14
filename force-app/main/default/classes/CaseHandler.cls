/*
 * MIT License. See the associated LICENSE file.
 * 
 * Copyright sirephil (c) 2023.
 */

/**
 * The handler for DML against the Case object.
 */
public without sharing class CaseHandler {
    /**
     * The transaction-wide tracking as to whether or not a "triggered event" has already been published by any
     * instances of this type of handler.
     */
    private static Boolean published = false;

    /**
     * Provides access to the singleton case handler.
     *
     * @return the singleton instance for this case handler. Will not be null.
     */
    public static CaseHandler getInstance() {
        return (CaseHandler) SingletonFactory.get(CaseHandler.class);
    }

    /**
     * Allows the Cases to be processed.
     *
     * @param oldCases the Case instances, in their previous state, to be processed. May be null.
     * @param newCases the Case instances, in their updated state, to be processed. May be null.
     */
    public void process(Case[] oldCases, Case[] newCases) {
        List<Command__c> commands = new List<Command__c>();

        if (newCases == null) {
            // The cases are being deleted so create appropriate commands
            for (Case oldCase : oldCases) {
                commands.add(new Command__c(
                        RecordId__c = oldCase.Id,
                        Operation__c = 'Delete'));
            }
        } else {
            // These fields are not of interest in the data sent to the callout
            Set<String> excludedFields = new Set<String> {
                    'SystemModstamp',
                    'CreatedById',
                    'CreatedDate',
                    'LastModifiedDate',
                    'LastModifiedById'
            };
            Map<String, SObjectField> fields = SObjectType.Case.fields.getMap();

            if (oldCases == null) {
                // The new cases are being added so create appropriate commands
                for (Case newCase : newCases) {
                    Map<String, String> changedFields = new Map<String, String>();

                    // Check each field in turn
                    for (SObjectField field : fields.values()) {
                        if (!excludedFields.contains(field.getDescribe().name) && newCase.get(field) != null) {
                            // The field wasn't an excluded one and has a value
                            changedFields.put(field.getDescribe().name, newCase.get(field).toString());
                        }
                    }

                    commands.add(new Command__c(
                            RecordId__c = newCase.Id,
                            Operation__c = 'Create',
                            UpdatedFieldsJSON__c = JSON.serialize(changedFields)));
                }
            } else if (newCases != null && oldCases != null) {
                // Cases are being updated, so generate commands if they are required, based on the changes made
                Map<Id, Case> oldCasesById = new Map<Id, Case>(oldCases);

                // Check all the cases to see if any of them have actual field value changes
                for (Case newCase : newCases) {
                    Case oldCase = oldCasesById.get(newCase.Id);
                    Map<String, String> changedFields = new Map<String, String>();

                    // Check each field in turn
                    for (SObjectField field : fields.values()) {
                        if (!excludedFields.contains(field.getDescribe().name) && newCase.get(field) != oldCase.get(field)) {
                            // The field wasn't an excluded one and has a value change
                            changedFields.put(field.getDescribe().name, newCase.get(field).toString());
                        }
                    }

                    if (!changedFields.isEmpty()) {
                        // There's some useful change information available so generate a command
                        commands.add(new Command__c(
                                RecordId__c = newCase.Id,
                                Operation__c = 'Update',
                                UpdatedFieldsJSON__c = JSON.serialize(changedFields)));
                    }
                }
            }
        }

        // Insert the commands (if there are any)
        insert commands;

        // Make sure to start processing of the command(s) that were added, in a separate transaction, using
        // the command processor
        if (!published && !commands.isEmpty()) {
            EventBus.publish(new TriggeredEvent__e(Type__c = CommandProcessor.class.getName()));

            // This transaction-wide tracking update ensures that we only publish at most one
            // triggered event in a given transaction for this type of processing.
            published = true;
        }
    }
}