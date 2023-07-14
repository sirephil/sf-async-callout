/*
 * MIT License. See the associated LICENSE file.
 * 
 * Copyright sirephil (c) 2023.
 */

/**
 * The interface for creating processors for triggered events.
 */
public interface EventProcessor {
    /**
     * Performs whatever processing is required when a triggered event is consumed.
     *
     * @param event the platform event being consumed. Will not be null.
     */
    void process(TriggeredEvent__e event);

    /**
     * Returns true when some processing is required.
     *
     * @return true iff some processing is required.
     */
    Boolean needsMoreProcessing();
}