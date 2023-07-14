trigger CaseCommand on Case (after insert, after update, after delete) {
    CaseHandler.getInstance().process(Trigger.old, Trigger.new);
}