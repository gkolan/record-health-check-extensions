/* eslint-disable @lwc/lwc-platform/no-aura-libs, @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const API_VERSION = "66.0";
const XML_HEADER = '<?xml version="1.0" encoding="UTF-8"?>\n';
const XML_NAMESPACE = ' xmlns="http://soap.sforce.com/2006/04/metadata"';

export function deriveAdapterNames(objectApiName, triggerNameOverride) {
  const customObject =
    typeof objectApiName === "string" && objectApiName.endsWith("__c");
  const objectStem = customObject ? objectApiName.slice(0, -3) : objectApiName;
  if (
    typeof objectApiName !== "string" ||
    !/^[A-Za-z][A-Za-z0-9_]*[A-Za-z0-9]$/.test(objectStem) ||
    objectApiName.endsWith("ChangeEvent") ||
    objectApiName.endsWith("__ChangeEvent")
  ) {
    throw new Error(
      "--object must be a source object API name such as Account or Order__c.",
    );
  }

  const eventApiName = customObject
    ? `${objectStem}__ChangeEvent`
    : `${objectApiName}ChangeEvent`;
  const memberName = `${objectStem}_ChangeEvent`;
  const typeToken = objectStem
    .split(/[^A-Za-z0-9]+/)
    .filter(Boolean)
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join("");
  const triggerName = triggerNameOverride || `RHC${typeToken}ChangeMonitor`;

  if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(triggerName) || triggerName.length > 40) {
    throw new Error(
      "The generated trigger name is invalid or exceeds 40 characters; pass --trigger-name.",
    );
  }

  return { eventApiName, memberName, objectApiName, triggerName };
}

export function renderAdapter({
  objectApiName,
  namespace = "rhc",
  triggerName,
}) {
  if (namespace !== "none" && !/^[A-Za-z][A-Za-z0-9_]*$/.test(namespace)) {
    throw new Error(
      "--namespace must be a valid namespace or the literal value none.",
    );
  }
  const names = deriveAdapterNames(objectApiName, triggerName);
  const intakeType =
    namespace === "none"
      ? "RHCChangeMonitorIntake"
      : `${namespace}.RHCChangeMonitorIntake`;
  const channelMember =
    `${XML_HEADER}<PlatformEventChannelMember${XML_NAMESPACE}>\n` +
    "    <eventChannel>ChangeEvents</eventChannel>\n" +
    `    <selectedEntity>${names.eventApiName}</selectedEntity>\n` +
    "</PlatformEventChannelMember>\n";
  const trigger =
    `/**\n * Subscriber-owned adapter for ${names.objectApiName} change events.\n */\n` +
    `trigger ${names.triggerName} on ${names.eventApiName} (after insert) {\n` +
    `  ${intakeType}.accept(Trigger.new);\n` +
    "}\n";
  const triggerMetadata =
    `${XML_HEADER}<ApexTrigger${XML_NAMESPACE}>\n` +
    `    <apiVersion>${API_VERSION}</apiVersion>\n` +
    "    <status>Active</status>\n" +
    "</ApexTrigger>\n";

  return {
    names,
    files: [
      {
        relativePath: `platformEventChannelMembers/${names.memberName}.platformEventChannelMember-meta.xml`,
        contents: channelMember,
      },
      {
        relativePath: `triggers/${names.triggerName}.trigger`,
        contents: trigger,
      },
      {
        relativePath: `triggers/${names.triggerName}.trigger-meta.xml`,
        contents: triggerMetadata,
      },
    ],
  };
}

export function writeAdapter({ outputDirectory, force = false, ...options }) {
  if (!outputDirectory) {
    throw new Error(
      "--output is required and must name a Salesforce source-format default directory.",
    );
  }
  const adapter = renderAdapter(options);
  const targets = adapter.files.map((file) => ({
    ...file,
    target: path.resolve(outputDirectory, file.relativePath),
  }));
  const existing = targets.filter((file) => fs.existsSync(file.target));
  if (existing.length > 0 && !force) {
    throw new Error(
      `Refusing to overwrite existing adapter files: ${existing.map((file) => file.target).join(", ")}`,
    );
  }
  for (const file of targets) {
    fs.mkdirSync(path.dirname(file.target), { recursive: true });
    fs.writeFileSync(file.target, file.contents);
  }
  return targets.map((file) => file.target);
}

export function checkAdapter({ outputDirectory, ...options }) {
  if (!outputDirectory) {
    throw new Error(
      "--output is required and must name a Salesforce source-format default directory.",
    );
  }
  const adapter = renderAdapter(options);
  const mismatches = adapter.files
    .map((file) => ({
      ...file,
      target: path.resolve(outputDirectory, file.relativePath),
    }))
    .filter(
      (file) =>
        !fs.existsSync(file.target) ||
        fs.readFileSync(file.target, "utf8") !== file.contents,
    );
  if (mismatches.length > 0) {
    throw new Error(
      `Adapter files are missing or out of date: ${mismatches.map((file) => file.target).join(", ")}`,
    );
  }
  return adapter.files.map((file) =>
    path.resolve(outputDirectory, file.relativePath),
  );
}

function usage() {
  return [
    "Generate a subscriber-owned RHC Change Monitor CDC adapter.",
    "",
    "Usage:",
    "  npm run adapter:generate -- --object Account --output ../../subscriber-repo/force-app/main/default",
    "",
    "Options:",
    "  --object <api-name>       Required source object, for example Account or Order__c",
    "  --output <directory>      Required Salesforce source-format default directory",
    "  --namespace <namespace>   Installed package namespace; defaults to rhc",
    "  --namespace none          Use only for no-namespace source-deployment verification",
    "  --trigger-name <name>     Override the derived Apex trigger name",
    "  --check                   Verify the three generated files without changing them",
    "  --force                   Overwrite only the three exact generated files",
    "  --help                    Show this help",
  ].join("\n");
}

function parseArguments(argumentsList) {
  const options = { namespace: "rhc", force: false };
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--help") {
      options.help = true;
    } else if (argument === "--check") {
      options.check = true;
    } else if (argument === "--force") {
      options.force = true;
    } else if (argument === "--object") {
      options.objectApiName = argumentsList[++index];
    } else if (argument === "--output") {
      options.outputDirectory = argumentsList[++index];
    } else if (argument === "--namespace") {
      options.namespace = argumentsList[++index];
    } else if (argument === "--trigger-name") {
      options.triggerName = argumentsList[++index];
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  return options;
}

function main() {
  try {
    const options = parseArguments(process.argv.slice(2));
    if (options.help) {
      console.log(usage());
      return;
    }
    if (options.check && options.force) {
      throw new Error("--check and --force cannot be used together.");
    }
    const targets = options.check
      ? checkAdapter(options)
      : writeAdapter(options);
    console.log(
      `${options.check ? "Verified" : "Generated"} ${targets.length} CDC adapter files:`,
    );
    for (const target of targets) {
      console.log(`- ${target}`);
    }
    if (!options.check) {
      console.log(
        "Add an object-specific Apex contract test and validate in a sandbox before activating a policy.",
      );
    }
  } catch (error) {
    console.error(error.message);
    console.error(usage());
    process.exitCode = 1;
  }
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main();
}
