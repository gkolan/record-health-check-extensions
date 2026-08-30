/** Configurable callout mock that captures the request without returning real response content. */
@isTest
public class RHCIntegrationHttpMock implements HttpCalloutMock {
    public static HttpRequest capturedRequest;
    private Integer statusCode;
    private String responseBody;

    /** @param statusCode HTTP status to return. @param responseBody Body used to prove it is discarded. */
    public RHCIntegrationHttpMock(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    /** @param request Captured outbound request. @return Configured mock response. */
    public HttpResponse respond(HttpRequest request) {
        capturedRequest = request;
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setBody(responseBody);
        return response;
    }
}
