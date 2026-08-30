#!/usr/bin/env bash
set -euo pipefail

target_org="${1:-}"
if [[ -z "${target_org}" ]]; then
  echo "Usage: scripts/verify-runtime-lifecycle.sh <target-org>" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apex_dir="${script_dir}/apex"

run_apex() {
  local apex_file="$1"
  local output
  output="$(sf apex run --file "${apex_dir}/${apex_file}" --target-org "${target_org}" --json)"
  if ! jq -e '.status == 0 and .result.success == true and .result.compiled == true' <<<"${output}" >/dev/null; then
    jq '{status, result:{success:.result.success, compiled:.result.compiled, compileProblem:.result.compileProblem, exceptionMessage:.result.exceptionMessage, exceptionStackTrace:.result.exceptionStackTrace}}' <<<"${output}" >&2
    exit 1
  fi
}

query() {
  local soql="$1"
  sf data query --query "${soql}" --target-org "${target_org}" --json
}

poll_operation() {
  local token="$1"
  local attempt
  local output
  local status
  for attempt in $(seq 1 45); do
    output="$(query "SELECT ${builder_prefix}Status__c, ${builder_prefix}MetadataRequestId__c, ${builder_prefix}ResultSummary__c FROM ${builder_prefix}Record_Health_Check_Set_Deployment__c WHERE ${builder_prefix}OperationToken__c = '${token}'")"
    status="$(jq -r --arg field "${builder_prefix}Status__c" '.result.records[0][$field] // "MISSING"' <<<"${output}")"
    if [[ "${status}" == "SUCCEEDED" ]]; then
      jq -e --arg field "${builder_prefix}MetadataRequestId__c" '.result.records[0][$field] | strings | length > 0' <<<"${output}" >/dev/null
      return
    fi
    if [[ "${status}" == "FAILED" ]]; then
      jq '.result.records[0]' <<<"${output}" >&2
      exit 1
    fi
    sleep 2
  done
  echo "Timed out waiting for Builder operation ${token}." >&2
  exit 1
}

assert_query() {
  local soql="$1"
  local jq_assertion="$2"
  local message="$3"
  local output
  output="$(query "${soql}")"
  if ! jq -e "${jq_assertion}" <<<"${output}" >/dev/null; then
    echo "${message}" >&2
    jq '.result.records' <<<"${output}" >&2
    exit 1
  fi
}

org_namespace="$(query "SELECT NamespacePrefix FROM Organization" | jq -r '.result.records[0].NamespacePrefix // ""')"
builder_prefix=""
if [[ "${org_namespace}" == "rhc" ]]; then
  builder_prefix="rhc__"
fi
core_prefix="rhc__"
if [[ "${org_namespace}" != "rhc" ]]; then
  local_core_types="$(query "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName = 'Record_Health_Check__mdt'" | jq -r '.result.records | length')"
  if [[ "${local_core_types}" -gt 0 ]]; then
    core_prefix=""
  fi
fi

completed_run="$(query "SELECT ${builder_prefix}Status__c FROM ${builder_prefix}Record_Health_Check_Set_Deployment__c WHERE ${builder_prefix}OperationToken__c = 'ci-runtime-rollback-v2'" | jq -r --arg field "${builder_prefix}Status__c" '.result.records[0][$field] // "MISSING"')"
if [[ "${completed_run}" == "SUCCEEDED" ]]; then
  assert_query \
    "SELECT DeveloperName, ${core_prefix}IsActive__c FROM ${core_prefix}Record_Health_Check__mdt WHERE DeveloperName = 'Builder_CI_Runtime_Second_Check'" \
    ".result.records | length == 1 and .[0].${core_prefix}IsActive__c == true" \
    "Completed rollback did not leave the restored Check active."
  assert_query \
    "SELECT ${builder_prefix}VersionNumber__c, ${builder_prefix}Status__c, ${builder_prefix}IsActive__c FROM ${builder_prefix}Record_Health_Check_Set_Version__c WHERE ${builder_prefix}CheckSetDraft__r.${builder_prefix}DeveloperName__c = 'Builder_CI_Runtime_Acceptance' AND ${builder_prefix}VersionNumber__c IN (2,3)" \
    ".result.records | length == 2 and any(.${builder_prefix}VersionNumber__c == 2 and .${builder_prefix}Status__c == \"DEPLOYED\" and .${builder_prefix}IsActive__c == true) and any(.${builder_prefix}VersionNumber__c == 3 and .${builder_prefix}Status__c == \"SUPERSEDED\" and .${builder_prefix}IsActive__c == false)" \
    "Completed rollback did not preserve the final version state."
  echo "Builder runtime lifecycle gate passed for ${target_org} (verified completed run)."
  exit 0
fi

run_apex runtime-save-publish-inactive.apex
poll_operation ci-runtime-publish-inactive-v1
assert_query \
  "SELECT ${builder_prefix}Status__c, ${builder_prefix}IsActive__c FROM ${builder_prefix}Record_Health_Check_Set_Version__c WHERE ${builder_prefix}CheckSetDraft__r.${builder_prefix}DeveloperName__c = 'Builder_CI_Runtime_Acceptance' AND ${builder_prefix}VersionNumber__c = 1" \
  ".result.records | length == 1 and .[0].${builder_prefix}Status__c == \"DEPLOYED\" and .[0].${builder_prefix}IsActive__c == false" \
  "Inactive publication did not preserve inactive version state."

run_apex runtime-create-activate-v2.apex
poll_operation ci-runtime-activate-v2
assert_query \
  "SELECT DeveloperName, ${core_prefix}IsActive__c FROM ${core_prefix}Record_Health_Check__mdt WHERE DeveloperName IN ('Builder_CI_Runtime_Formula','Builder_CI_Runtime_Second_Check')" \
  ".result.records | length == 2 and all(.${core_prefix}IsActive__c == true)" \
  "Activation did not activate both Checks."

run_apex runtime-create-activate-v3.apex
poll_operation ci-runtime-activate-v3
assert_query \
  "SELECT DeveloperName, ${core_prefix}IsActive__c FROM ${core_prefix}Record_Health_Check__mdt WHERE DeveloperName = 'Builder_CI_Runtime_Second_Check'" \
  ".result.records | length == 1 and .[0].${core_prefix}IsActive__c == false" \
  "Omitted-Check publication did not deactivate the omitted Check."
assert_query \
  "SELECT ${builder_prefix}VersionNumber__c, ${builder_prefix}Status__c, ${builder_prefix}IsActive__c FROM ${builder_prefix}Record_Health_Check_Set_Version__c WHERE ${builder_prefix}CheckSetDraft__r.${builder_prefix}DeveloperName__c = 'Builder_CI_Runtime_Acceptance' AND ${builder_prefix}VersionNumber__c IN (2,3)" \
  ".result.records | length == 2 and any(.${builder_prefix}VersionNumber__c == 2 and .${builder_prefix}Status__c == \"SUPERSEDED\" and .${builder_prefix}IsActive__c == false) and any(.${builder_prefix}VersionNumber__c == 3 and .${builder_prefix}Status__c == \"DEPLOYED\" and .${builder_prefix}IsActive__c == true)" \
  "Version 3 activation did not supersede version 2."

run_apex runtime-rollback-v2.apex
poll_operation ci-runtime-rollback-v2
assert_query \
  "SELECT DeveloperName, ${core_prefix}IsActive__c FROM ${core_prefix}Record_Health_Check__mdt WHERE DeveloperName = 'Builder_CI_Runtime_Second_Check'" \
  ".result.records | length == 1 and .[0].${core_prefix}IsActive__c == true" \
  "Rollback did not reactivate the restored Check."
assert_query \
  "SELECT ${builder_prefix}VersionNumber__c, ${builder_prefix}Status__c, ${builder_prefix}IsActive__c FROM ${builder_prefix}Record_Health_Check_Set_Version__c WHERE ${builder_prefix}CheckSetDraft__r.${builder_prefix}DeveloperName__c = 'Builder_CI_Runtime_Acceptance' AND ${builder_prefix}VersionNumber__c IN (2,3)" \
  ".result.records | length == 2 and any(.${builder_prefix}VersionNumber__c == 2 and .${builder_prefix}Status__c == \"DEPLOYED\" and .${builder_prefix}IsActive__c == true) and any(.${builder_prefix}VersionNumber__c == 3 and .${builder_prefix}Status__c == \"SUPERSEDED\" and .${builder_prefix}IsActive__c == false)" \
  "Rollback did not restore version 2 and supersede version 3."

echo "Builder runtime lifecycle gate passed for ${target_org}."
