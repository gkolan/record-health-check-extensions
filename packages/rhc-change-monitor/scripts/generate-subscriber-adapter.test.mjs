/* eslint-disable @lwc/lwc-platform/no-aura-libs -- Node test, not LWC runtime code. */
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  checkAdapter,
  deriveAdapterNames,
  renderAdapter,
  writeAdapter,
} from "./generate-subscriber-adapter.mjs";

test("derives standard-object CDC names", () => {
  assert.deepEqual(deriveAdapterNames("Account"), {
    eventApiName: "AccountChangeEvent",
    memberName: "Account_ChangeEvent",
    objectApiName: "Account",
    triggerName: "RHCAccountChangeMonitor",
  });
});

test("derives custom-object CDC names", () => {
  assert.deepEqual(deriveAdapterNames("Order_Item__c"), {
    eventApiName: "Order_Item__ChangeEvent",
    memberName: "Order_Item_ChangeEvent",
    objectApiName: "Order_Item__c",
    triggerName: "RHCOrderItemChangeMonitor",
  });
});

test("renders installed-package and no-namespace intake references", () => {
  const installed = renderAdapter({ objectApiName: "Account" });
  const sourceMode = renderAdapter({
    objectApiName: "Account",
    namespace: "none",
  });
  const installedTrigger = installed.files.find((file) =>
    file.relativePath.endsWith(".trigger"),
  ).contents;
  const sourceTrigger = sourceMode.files.find((file) =>
    file.relativePath.endsWith(".trigger"),
  ).contents;

  assert.match(
    installedTrigger,
    /rhc\.RHCChangeMonitorIntake\.accept\(Trigger\.new\)/,
  );
  assert.match(
    sourceTrigger,
    /^\s*RHCChangeMonitorIntake\.accept\(Trigger\.new\)/m,
  );
});

test("writes the exact source-format adapter files and refuses overwrite", () => {
  const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "rhc-cdc-adapter-"),
  );
  try {
    const written = writeAdapter({
      objectApiName: "Example__c",
      outputDirectory: temporaryRoot,
    });
    assert.equal(written.length, 3);
    assert.ok(
      fs.existsSync(
        path.join(
          temporaryRoot,
          "platformEventChannelMembers/Example_ChangeEvent.platformEventChannelMember-meta.xml",
        ),
      ),
    );
    assert.ok(
      fs.existsSync(
        path.join(temporaryRoot, "triggers/RHCExampleChangeMonitor.trigger"),
      ),
    );
    assert.throws(
      () =>
        writeAdapter({
          objectApiName: "Example__c",
          outputDirectory: temporaryRoot,
        }),
      /Refusing to overwrite/,
    );
  } finally {
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
  }
});

test("checks generated files without changing them and detects drift", () => {
  const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "rhc-cdc-adapter-check-"),
  );
  try {
    writeAdapter({
      namespace: "none",
      objectApiName: "Account",
      outputDirectory: temporaryRoot,
    });
    assert.equal(
      checkAdapter({
        namespace: "none",
        objectApiName: "Account",
        outputDirectory: temporaryRoot,
      }).length,
      3,
    );
    fs.appendFileSync(
      path.join(temporaryRoot, "triggers/RHCAccountChangeMonitor.trigger"),
      "// drift\n",
    );
    assert.throws(
      () =>
        checkAdapter({
          namespace: "none",
          objectApiName: "Account",
          outputDirectory: temporaryRoot,
        }),
      /missing or out of date/,
    );
  } finally {
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
  }
});

test("rejects event names and invalid namespaces", () => {
  assert.throws(
    () => deriveAdapterNames("AccountChangeEvent"),
    /source object API name/,
  );
  assert.throws(() => deriveAdapterNames("Account_"), /source object API name/);
  assert.throws(
    () => renderAdapter({ objectApiName: "Account", namespace: "not-valid!" }),
    /valid namespace/,
  );
});
