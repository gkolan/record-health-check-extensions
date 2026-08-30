/**
 * Processes Platform Event deliveries in checkpointed, governor-safe chunks.
 */
public with sharing class RHCActionResultSubscriberHandler {
  private static final Integer CHUNK_SIZE = 50;
  private static final Integer MAX_FIRST_CHUNK_RETRIES = 3;

  /**
   * Captures delivered core result events in checkpointed chunks.
   *
   * @param events Result events supplied by the subscriber trigger
   */
  public static void process(List<Record_Health_Check_Result__e> events) {
    if (events == null || events.isEmpty()) {
      return;
    }
    Integer processedCount = 0;
    for (
      Integer startIndex = 0;
      startIndex < events.size();
      startIndex += CHUNK_SIZE
    ) {
      List<Record_Health_Check_Result__e> eventChunk = chunkFrom(
        events,
        startIndex
      );
      try {
        RHCActionCaptureService.capture(eventChunk);
        setCheckpoint(eventChunk[eventChunk.size() - 1]);
        processedCount += eventChunk.size();
      } catch (
        RHCActionCaptureService.TransientCaptureException captureFailure
      ) {
        retryOrResume(captureFailure, processedCount);
      }
    }
  }

  private static List<Record_Health_Check_Result__e> chunkFrom(
    List<Record_Health_Check_Result__e> events,
    Integer startIndex
  ) {
    Integer endIndex = Math.min(startIndex + CHUNK_SIZE, events.size());
    List<Record_Health_Check_Result__e> chunk = new List<Record_Health_Check_Result__e>();
    for (Integer index = startIndex; index < endIndex; index++) {
      chunk.add(events[index]);
    }
    return chunk;
  }

  private static void setCheckpoint(
    Record_Health_Check_Result__e lastEvent
  ) {
    EventBus.TriggerContext.currentContext().setResumeCheckpoint(
      lastEvent.ReplayId
    );
  }

  @TestVisible
  private static void retryOrResume(
    RHCActionCaptureService.TransientCaptureException captureFailure,
    Integer processedCount
  ) {
    EventBus.TriggerContext context = EventBus.TriggerContext.currentContext();
    if (
      processedCount == 0 &&
      context.retries < MAX_FIRST_CHUNK_RETRIES
    ) {
      throw new EventBus.RetryableException(
        'Transient RHC Actions subscriber failure.'
      );
    }
    throw captureFailure;
  }
}
