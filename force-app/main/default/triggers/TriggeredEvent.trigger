trigger TriggeredEvent on TriggeredEvent__e (after insert) {
    TriggeredEventHandler.getInstance().process(Trigger.new);
}