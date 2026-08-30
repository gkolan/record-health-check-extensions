import { createElement } from "lwc";
import RhcAlertsDeliveryHistory from "c/rhcAlertsDeliveryHistory";
import listDeliveries from "@salesforce/apex/RHCAlertsViewerController.listDeliveries";

jest.mock(
  "@salesforce/apex/RHCAlertsViewerController.listDeliveries",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = async () => {
  await Promise.resolve();
  await Promise.resolve();
};

describe("c-rhc-alerts-delivery-history", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("renders distinct operational outcomes without payload columns", async () => {
    listDeliveries.mockResolvedValue([
      {
        Id: "a01",
        Name: "RHC-AD-000001",
        Outcome__c: "DELIVERED",
        Status__c: "FAIL",
        Policy__r: { DisplayName__c: "Critical checks" }
      },
      {
        Id: "a02",
        Name: "RHC-AD-000002",
        Outcome__c: "DUPLICATE",
        Status__c: "FAIL",
        Policy__r: { DisplayName__c: "Critical checks" }
      }
    ]);
    const element = createElement("c-rhc-alerts-delivery-history", {
      is: RhcAlertsDeliveryHistory
    });
    document.body.appendChild(element);
    await flush();
    const table = element.shadowRoot.querySelector("lightning-datatable");
    expect(table.data.map((row) => row.Outcome__c)).toEqual([
      "DELIVERED",
      "DUPLICATE"
    ]);
    expect(table.columns.map((column) => column.fieldName)).not.toContain(
      "Payload__c"
    );
  });

  it("shows an accessible empty state", async () => {
    listDeliveries.mockResolvedValue([]);
    const element = createElement("c-rhc-alerts-delivery-history", {
      is: RhcAlertsDeliveryHistory
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain(
      "No delivery attempts yet"
    );
  });

  it("shows a bounded error and allows a successful refresh", async () => {
    listDeliveries
      .mockRejectedValueOnce({ body: { message: "History access denied." } })
      .mockResolvedValueOnce([
        { Id: "a03", Name: "RHC-AD-000003", Outcome__c: "FAILED" }
      ]);
    const element = createElement("c-rhc-alerts-delivery-history", {
      is: RhcAlertsDeliveryHistory
    });
    document.body.appendChild(element);
    await flush();
    expect(element.shadowRoot.textContent).toContain("History access denied.");

    element.shadowRoot.querySelector("lightning-button").click();
    await flush();
    expect(
      element.shadowRoot.querySelector("lightning-datatable").data[0].Outcome__c
    ).toBe("FAILED");
  });
});
