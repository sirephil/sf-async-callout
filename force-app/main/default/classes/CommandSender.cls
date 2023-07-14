/*
 * MIT License. See the associated LICENSE file.
 *
 * Copyright sirephil (c) 2023.
 */

/**
 * This queueable is responsible for sending callouts to some fictional end point. This code doesn't actually do
 * the callout but does everything else that would be required.
 */
public with sharing class CommandSender implements Queueable, Database.AllowsCallouts {
    /**
     * The IDs of the commands that must be sent.
     */
    private final Set<Id> commandIds;

    /**
     * Initializes the new instance using the given parameters.
     *
     * @param commandIds the IDs of the commands that must be sent.
     */
    public CommandSender(Set<Id> commandIds) {
        Assert.isTrue(commandIds.size() <= 100, 'A maximum of 100 commands can be sent in one go');

        this.commandIds = commandIds;
    }

    // apexdoc inherited
    public void execute(QueueableContext context) {
        List<Command__c> updates = new List<Command__c>();

        // Firstly, get those callouts made for the commands the sender was given on construction
        doCallouts();

        // Update these sent commands to indicate they are now complete
        for (Id commandId : commandIds) {
            updates.add(new Command__c(
                    Id = commandId,
                    Status__c = 'Complete'));
        }

        update updates;

        // Ensure that any pending commands will be processed by generating a Platform Event to nudge this
        // processing
        if (new CommandProcessor().needsMoreProcessing()) {
            String processor = CommandProcessor.class.getName();

            EventBus.publish(new TriggeredEvent__e(Type__c = processor));
        }
    }

    /**
     * Perform the callouts using the commands this sender was given on construction.
     */
    private void doCallouts() {
        // TODO this is left for implementing as required
    }
}