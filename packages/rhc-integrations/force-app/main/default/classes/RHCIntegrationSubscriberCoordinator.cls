/**
 * Processes canonical Platform Event deliveries in checkpointed, governor-safe chunks.
 */
public with sharing class RHCIntegrationSubscriberCoordinator {
    private static final Integer CHUNK_SIZE = 50;
    private static final Integer MAX_FIRST_CHUNK_RETRIES = 3;

    /** @param events Canonical Result events supplied by the package trigger. */
    public static void processResults(List<Record_Health_Check_Result__e> events) {
        Integer processedCount = 0;
        for (Integer startIndex = 0; events != null && startIndex < events.size(); startIndex += CHUNK_SIZE) {
            List<Record_Health_Check_Result__e> chunk = resultChunk(events, startIndex);
            try {
                RHCIntegrationEventHandler.handleResults(chunk);
                setCheckpoint(chunk[chunk.size() - 1].ReplayId);
                processedCount += chunk.size();
            } catch (RHCIntegrationIngestionService.TransientIngestionException failure) {
                retryOrResume(failure, processedCount);
            }
        }
    }

    /** @param events Canonical Set Run events supplied by the package trigger. */
    public static void processRuns(List<Record_Health_Check_Set_Run__e> events) {
        Integer processedCount = 0;
        for (Integer startIndex = 0; events != null && startIndex < events.size(); startIndex += CHUNK_SIZE) {
            List<Record_Health_Check_Set_Run__e> chunk = runChunk(events, startIndex);
            try {
                RHCIntegrationEventHandler.handleRuns(chunk);
                setCheckpoint(chunk[chunk.size() - 1].ReplayId);
                processedCount += chunk.size();
            } catch (RHCIntegrationIngestionService.TransientIngestionException failure) {
                retryOrResume(failure, processedCount);
            }
        }
    }

    /** @param events Canonical Log events supplied by the package trigger. */
    public static void processLogs(List<Record_Health_Check_Log__e> events) {
        Integer processedCount = 0;
        for (Integer startIndex = 0; events != null && startIndex < events.size(); startIndex += CHUNK_SIZE) {
            List<Record_Health_Check_Log__e> chunk = logChunk(events, startIndex);
            try {
                RHCIntegrationEventHandler.handleLogs(chunk);
                setCheckpoint(chunk[chunk.size() - 1].ReplayId);
                processedCount += chunk.size();
            } catch (RHCIntegrationIngestionService.TransientIngestionException failure) {
                retryOrResume(failure, processedCount);
            }
        }
    }

    private static List<Record_Health_Check_Result__e> resultChunk(
        List<Record_Health_Check_Result__e> events,
        Integer startIndex
    ) {
        List<Record_Health_Check_Result__e> chunk = new List<Record_Health_Check_Result__e>();
        for (Integer index = startIndex; index < Math.min(startIndex + CHUNK_SIZE, events.size()); index++) {
            chunk.add(events[index]);
        }
        return chunk;
    }

    private static List<Record_Health_Check_Set_Run__e> runChunk(
        List<Record_Health_Check_Set_Run__e> events,
        Integer startIndex
    ) {
        List<Record_Health_Check_Set_Run__e> chunk = new List<Record_Health_Check_Set_Run__e>();
        for (Integer index = startIndex; index < Math.min(startIndex + CHUNK_SIZE, events.size()); index++) {
            chunk.add(events[index]);
        }
        return chunk;
    }

    private static List<Record_Health_Check_Log__e> logChunk(
        List<Record_Health_Check_Log__e> events,
        Integer startIndex
    ) {
        List<Record_Health_Check_Log__e> chunk = new List<Record_Health_Check_Log__e>();
        for (Integer index = startIndex; index < Math.min(startIndex + CHUNK_SIZE, events.size()); index++) {
            chunk.add(events[index]);
        }
        return chunk;
    }

    private static void setCheckpoint(String replayId) {
        EventBus.TriggerContext.currentContext().setResumeCheckpoint(replayId);
    }

    private static void retryOrResume(
        RHCIntegrationIngestionService.TransientIngestionException failure,
        Integer processedCount
    ) {
        EventBus.TriggerContext context = EventBus.TriggerContext.currentContext();
        if (processedCount == 0 && context.retries < MAX_FIRST_CHUNK_RETRIES) {
            throw new EventBus.RetryableException('Transient RHC Integrations subscriber failure.');
        }
        throw failure;
    }
}
