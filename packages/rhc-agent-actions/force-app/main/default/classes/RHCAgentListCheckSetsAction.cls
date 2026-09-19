/**
 * Lets an Agentforce agent discover which active Record Health Check Sets apply to a record or
 * object before asking for an explanation.
 */
public with sharing class RHCAgentListCheckSetsAction {
  /** One discovery request; supply a record ID or an object API name. */
  public class Request {
    @InvocableVariable(
      label='Record ID'
      description='Optional Salesforce record ID; its object determines the applicable Check Sets.'
    )
    public Id recordId;
    @InvocableVariable(
      label='Object API Name'
      description='Optional exact object API name, for example Account. Ignored when Record ID is given.'
    )
    public String objectApiName;
  }

  /** Applicable Check Sets for one request. */
  public class Response {
    @InvocableVariable(label='Contract Version')
    public String contractVersion = RHCAgentSupport.CONTRACT_VERSION;
    @InvocableVariable(label='Success')
    public Boolean success;
    @InvocableVariable(label='Object API Name')
    public String objectApiName;
    @InvocableVariable(label='Check Sets')
    public List<RHCAgentSupport.CheckSetInfo> checkSets = new List<RHCAgentSupport.CheckSetInfo>();
    @InvocableVariable(label='Summary Text')
    public String summaryText;
    @InvocableVariable(label='Error Message')
    public String errorMessage;
  }

  /**
   * @param requests one request per invocation
   * @return one response per request, in order
   */
  @InvocableMethod(
    label='List Record Health Check Sets for Agentforce'
    description='Use to find which active Record Health Check Sets apply to a record or object before explaining its health. Returns exact Qualified API Names to pass to Explain Record Health.'
    category='Record Health Check'
  )
  public static List<Response> listCheckSets(List<Request> requests) {
    List<Response> responses = new List<Response>();
    for (Request input : requests ?? new List<Request>()) {
      responses.add(respond(input));
    }
    return responses;
  }

  private static Response respond(Request input) {
    Response response = new Response();
    response.objectApiName = input?.recordId != null
      ? RHCAgentSupport.objectApiNameOf(input.recordId)
      : input?.objectApiName?.trim();
    if (String.isBlank(response.objectApiName)) {
      response.success = false;
      response.errorMessage = 'Supply a record ID or an object API name.';
      return response;
    }
    response.checkSets = RHCAgentSupport.applicableCheckSets(response.objectApiName, 50);
    response.success = true;
    List<String> labels = new List<String>();
    for (RHCAgentSupport.CheckSetInfo info : response.checkSets) {
      labels.add(info.label + ' (' + info.qualifiedApiName + ')');
    }
    response.summaryText = labels.isEmpty()
      ? 'No active Record Health Check Sets apply to ' + response.objectApiName + '.'
      : response.checkSets.size() + ' Check Set(s) apply to ' + response.objectApiName + ': '
        + String.join(labels, '; ') + '.';
    return response;
  }
}
