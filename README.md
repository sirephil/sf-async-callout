# sf-async-callout

Demonstrates how to capture and asynchronously perform callouts, in an appropriate sequence, to an external system, all initiated from triggers.

## Why?

* Avoid restricting DML to synchronous-only contexts.
* Allow callouts on record changes without massively impacting the performance of those record changes.
* Ensure these callouts are sent to the external system in the correct order via a single-threaded processor.

## What?

An apex trigger processes record creation, update, delete, undelete operations (or a subset thereof) for a given object. A major limitation is the inability to perform a callout from within a trigger; callouts are used to initiate communication with external systems and are a common integration mechanism with off-platform software or systems.

Salesforce generally recommends performing callouts in a future method called from a trigger, but futures cannot be called when the initiating transaction itself is already asynchronous. That means it becomes impossible to make these callouts initiate from the trigger in a robust way that works in all contexts where that trigger could be called.

The above issue is addressed by changing the approach and using a "command object", Platform Events and (until Salesforce supports callouts from a Platform Event apex trigger-based subscriber) a Queueable. The "command object" captures relevant details of the happenings in the originating apex trigger and the Platform Events are used to initiate a simple Queueable that does the callout(s), passing the detail from the "command object(s)".

## How

This repo contains code that addresses the callout invocation in an elegant and robust manner.

This demonstration does not include any unit tests, but shows how you can use a "command object", a platform event and a simple queueable to safely and robustly send information to an external system while preserving the order of sending. The number of actual asynchronous apex calls can and will be optimized when there are a large number of concurrent changes, though will be suboptimal otherwise, to ensure the updates are sent as soon as possible. If the sending can be delayed arbitrarily, the code could be updated to better optimize the number of async apex calls.

The key parts are:

* The `Command__c` custom object representing the callout that is required. In this example, creation and updates to Case records generate these commands, but this could, in principle, be used with any type of object.
* The `CommandProcessor` that encapsulates the processing to be applied. This is an `EventProcessor` implementation.
* The `TriggeredEvent__e` platform event that is used to initiate the required processing. This includes a `Type__c` field that simply selects the processor to be run - additional implementations of the `EventProcessor` could easily be created if other types of processing was needed against the `Example__c` object, or even other object(s), in different situations. A key takeaway here is that the event processing is single threaded, meaning there is no worry that the `Example__c` processing might face race conditions (a problem with `Queueable` and `Batchable` implementations where two or more instances of the same code can run concurrently and interfere with each other).

The `Case` object's trigger sets up the required `Command__c` records. It ensures that at most one Platform Event is published for the `CommandProcessor` in a given transaction when command record(s) get inserted (this processing could be moved to a Command trigger, but was left here for simplicity). The platform event will be processed in a subsequent transaction.

The `TriggeredEvent__e` event's trigger determines the type(s) of processing that are required and ensures that the first of these types gets executed. If that type cannot be fully executed in the trigger an appropriate event gets published to allow the trigger to be called again, for that type, in a subsequent transaction.

The `Command__c` object includes a `Status__c` to allow them to be processed cleanly, despite having to use a Queueable to perform the callout (Salesforce does not yet allow a Callout from a Platform Event Apex trigger-based subscriber). In this example, the "Commands" are not deleted when "sent" (as they should be in a production scenario), to allow for inspection of what happened. Additionally, the queueable should be updated to implement the transaction finalizer to robustly handle issues encountered during the sending.

# Setup and Running the Demo

After deployment, assign the `CaseCommand` permission set to your user then access the `Case` tab to start playing. You might also like to bulk create or update `Case` records, view the Commands and look at the Automated Process debug to see what happens. Note how the processing encapsulated in the `CommandProcessor` is attributed to the Automated Process user, while your changes are attributed to your user.

# Who caused the changes?

The `Command__c` records updated by the processor are marked as Last Modified By the Automated Process user. This can be a good thing - you can see they have been processed by automation after the initial creation of them under transactional users. If this is a significant problem, it is actually possible to engineer a flow-based Platform Event subscriber to replace this apex version. In this case the changes actually get attributed to the contextual user who caused the Platform Event to be published.
