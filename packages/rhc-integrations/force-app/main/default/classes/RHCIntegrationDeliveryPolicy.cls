/**
 * Applies route safety, callout, response classification, and bounded retry policy.
 */
public with sharing class RHCIntegrationDeliveryPolicy {
    private static final Integer CALLOUT_TIMEOUT_MS = 20000;

    /**
     * Performs one attempt and classifies it in memory; the caller persists the row after every
     * callout of its slice has completed.
     * @param delivery Locked delivery row and its selected route.
     */
    public static void process(Record_Health_Check_Integration_Delivery__c delivery) {
        delivery.AttemptCount__c = Integer.valueOf(delivery.AttemptCount__c) + 1;
        delivery.LastAttemptAt__c = System.now();
        delivery.NextAttemptAt__c = null;
        if (!isSafeRoute(delivery.Route__r)) {
            markDeadLetter(delivery, failure(
                null,
                'CONFIGURATION_INVALID',
                'Correct the active Named Credential and relative endpoint configuration before replay.'
            ));
            return;
        }
        try {
            HttpResponse response = new Http().send(requestFor(delivery));
            classifyResponse(delivery, response.getStatusCode());
        } catch (CalloutException exceptionRecord) {
            classifyRetryable(delivery, null, 'TRANSPORT_ERROR');
        }
    }

    /** @param delivery Delivery row whose parent Queueable failed unexpectedly. */
    public static void markUnhandled(Record_Health_Check_Integration_Delivery__c delivery) {
        markDeadLetter(delivery, failure(
            null,
            'QUEUEABLE_UNHANDLED',
            'The delivery worker failed unexpectedly. Review async job evidence before replay.'
        ));
    }

    private static HttpRequest requestFor(Record_Health_Check_Integration_Delivery__c delivery) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + delivery.Route__r.NamedCredential__c
            + delivery.Route__r.RelativeEndpoint__c);
        request.setMethod('POST');
        request.setTimeout(CALLOUT_TIMEOUT_MS);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Idempotency-Key', delivery.EventId__c);
        request.setHeader('X-RHC-Event-ID', delivery.EventId__c);
        request.setBody(delivery.Payload__c);
        return request;
    }

    private static void classifyResponse(
        Record_Health_Check_Integration_Delivery__c delivery,
        Integer statusCode
    ) {
        delivery.HttpStatus__c = statusCode;
        if (statusCode >= 200 && statusCode <= 299) {
            markSucceeded(delivery);
            return;
        }
        if (isRetryableStatus(statusCode)) {
            classifyRetryable(delivery, statusCode, 'HTTP_' + statusCode);
            return;
        }
        markDeadLetter(delivery, failure(
            statusCode,
            'HTTP_' + statusCode,
            'The endpoint returned a permanent response classification. Response content was discarded.'
        ));
    }

    private static void markSucceeded(Record_Health_Check_Integration_Delivery__c delivery) {
        delivery.Status__c = 'SUCCEEDED';
        delivery.HttpClassification__c = 'SUCCESS';
        delivery.ErrorCode__c = null;
        delivery.ErrorDetail__c = null;
        delivery.CompletedAt__c = System.now();
    }

    private static Boolean isRetryableStatus(Integer statusCode) {
        return statusCode == 408 || statusCode == 425 || statusCode == 429 || statusCode >= 500;
    }

    private static void classifyRetryable(
        Record_Health_Check_Integration_Delivery__c delivery,
        Integer statusCode,
        String errorCode
    ) {
        Integer attemptNumber = Integer.valueOf(delivery.AttemptCount__c);
        if (attemptNumber >= maxAttempts(delivery.Route__r.RetryPolicy__c)) {
            markDeadLetter(delivery, failure(
                statusCode,
                errorCode,
                'The bounded retry policy is exhausted. Correct external configuration before replay.'
            ));
            return;
        }
        Integer delayMinutes = nextDelayMinutes(delivery.Route__r.RetryPolicy__c, attemptNumber);
        delivery.Status__c = 'RETRY_WAIT';
        delivery.HttpClassification__c = statusCode == null ? 'TRANSPORT' : 'RETRYABLE';
        delivery.ErrorCode__c = errorCode;
        delivery.ErrorDetail__c = 'A retryable failure was classified without retaining response content.';
        delivery.NextAttemptAt__c = System.now().addMinutes(delayMinutes);
    }

    private static FailureDetail failure(Integer statusCode, String errorCode, String errorDetail) {
        FailureDetail detail = new FailureDetail();
        detail.statusCode = statusCode;
        detail.errorCode = errorCode;
        detail.errorDetail = errorDetail;
        return detail;
    }

    private static void markDeadLetter(
        Record_Health_Check_Integration_Delivery__c delivery,
        FailureDetail detail
    ) {
        delivery.Status__c = 'DEAD_LETTER';
        delivery.HttpStatus__c = detail.statusCode;
        delivery.HttpClassification__c = 'PERMANENT';
        delivery.ErrorCode__c = detail.errorCode;
        delivery.ErrorDetail__c = detail.errorDetail;
        delivery.NextAttemptAt__c = null;
        delivery.CompletedAt__c = System.now();
    }

    private static Integer maxAttempts(String policy) {
        if (policy == 'NONE') {
            return 1;
        }
        if (policy == 'AGGRESSIVE') {
            return 5;
        }
        return 3;
    }

    /**
     * @param policy Route retry policy.
     * @param completedAttempts Number of attempts already completed.
     * @return Bounded delay before the next Queueable execution.
     */
    public static Integer nextDelayMinutes(String policy, Integer completedAttempts) {
        if (policy == 'AGGRESSIVE') {
            List<Integer> delays = new List<Integer>{ 1, 2, 5, 10 };
            return delays[Math.min(Math.max(completedAttempts - 1, 0), delays.size() - 1)];
        }
        List<Integer> standardDelays = new List<Integer>{ 1, 5 };
        return standardDelays[Math.min(Math.max(completedAttempts - 1, 0), standardDelays.size() - 1)];
    }

    /** @param route Route to validate independently from metadata validation rules. */
    @TestVisible
    private static Boolean isSafeRoute(Record_Health_Check_Integration_Route__c route) {
        return route.Active__c
            && !String.isBlank(route.NamedCredential__c)
            && Pattern.matches('^[A-Za-z][A-Za-z0-9_]{0,79}$', route.NamedCredential__c)
            && !String.isBlank(route.RelativeEndpoint__c)
            && route.RelativeEndpoint__c.startsWith('/')
            && !route.RelativeEndpoint__c.startsWith('//')
            && !route.RelativeEndpoint__c.contains('://')
            && !route.RelativeEndpoint__c.contains('\\\\')
            && !route.RelativeEndpoint__c.contains('?')
            && !route.RelativeEndpoint__c.contains('#')
            && !route.RelativeEndpoint__c.contains('..');
    }

    private class FailureDetail {
        private Integer statusCode;
        private String errorCode;
        private String errorDetail;
    }
}
