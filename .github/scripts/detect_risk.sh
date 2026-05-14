#!/bin/bash

set -eo pipefail

echo "Starting PR risk analysis..."

AUTHOR=$(git log -1 --format="%an <%ae>")
COMMIT_SHA=$(git rev-parse HEAD)
COMMIT_SHORT=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --format="%s")
BRANCH_NAME="${GITHUB_HEAD_REF:-$GITHUB_REF_NAME}"

COMMIT_URL="https://github.com/$GITHUB_REPOSITORY/commit/$COMMIT_SHA"
PR_URL="https://github.com/$GITHUB_REPOSITORY/pull"

# ------------------------------------------------------------
# FILE TYPES TO MONITOR
# ------------------------------------------------------------

FILE_PATTERNS=(
  '*.java'
  '*.js'
  '*.ts'
  '*.py'
  '*.go'
  '*.rb'
  '*.cs'
  '*.sh'
)

echo "Fetching base branch..."

git fetch origin "${GITHUB_BASE_REF}:${GITHUB_BASE_REF}"

# ------------------------------------------------------------
# DIFF ANALYSIS
# ------------------------------------------------------------

DELETED_LINES=$(git diff ${GITHUB_BASE_REF}...HEAD \
  -- "${FILE_PATTERNS[@]}" \
  | grep '^-' \
  | grep -v '^---' \
  | grep -v '^-[[:space:]]*$' \
  | grep -v '^-[[:space:]]*//' \
  || true
)

ADDED_LINES=$(git diff ${GITHUB_BASE_REF}...HEAD \
  -- "${FILE_PATTERNS[@]}" \
  | grep '^+' \
  | grep -v '^+++' \
  | grep -v '^[[:space:]]*$' \
  || true
)

DELETED_COUNT=$(echo "$DELETED_LINES" | grep -c '^-' || true)
ADDED_COUNT=$(echo "$ADDED_LINES" | grep -c '^+' || true)

FILES_CHANGED=$(git diff --name-only ${GITHUB_BASE_REF}...HEAD \
  -- "${FILE_PATTERNS[@]}" \
  || true
)

DELETED_LINE_INFO=$(git diff --unified=0 ${GITHUB_BASE_REF}...HEAD \
  -- "${FILE_PATTERNS[@]}" \
  | awk '
    /^diff --git/ {
        file=$4
        sub("b/", "", file)
    }
    /^@@/ {
        print file " -> " $0
    }
  ')

FORMATTED_DELETIONS=$(echo "$DELETED_LINE_INFO" \
  | sed 's/@@//g')

# ------------------------------------------------------------
# RISK ENGINE
# ------------------------------------------------------------

# RISK_SCORE=0
# SEVERITY="MINOR"
# FAIL_PR=true
# REASONS=()

# ---- deletion volume ----

if [ "$DELETED_COUNT" -gt 10 ]; then
  RISK_SCORE=$((RISK_SCORE + 3))
  REASONS+=("More than 10 deleted lines")
fi

if [ "$DELETED_COUNT" -gt 50 ]; then
  RISK_SCORE=$((RISK_SCORE + 5))
  REASONS+=("More than 50 deleted lines")
fi

# ---- additions replacing deletions ----

if [ "$ADDED_COUNT" -gt "$DELETED_COUNT" ]; then
  RISK_SCORE=$((RISK_SCORE - 1))
  REASONS+=("Code replacement detected")
fi

# ---- critical paths ----

if echo "$FILES_CHANGED" | grep -E 'auth|security|payment|prod|infra'; then
  RISK_SCORE=$((RISK_SCORE + 10))
  REASONS+=("Critical module modified")
fi

# ------------------------------------------------------------
# DETERMINE SEVERITY
# ------------------------------------------------------------

if [ "$DELETED_COUNT" -gt 0 ]; then
  ALERT_MESSAGE="Code deletions detected in this PR"
  ALERT_ICON="🚨"
else
  ALERT_MESSAGE="No risky deletions detected. All good."
  ALERT_ICON="✅"
fi

# if [ "$RISK_SCORE" -ge 10 ]; then
#   SEVERITY="CRITICAL"
#   FAIL_PR=true

# elif [ "$RISK_SCORE" -ge 4 ]; then
#   SEVERITY="MAJOR"
#   FAIL_PR=true

# else
#   SEVERITY="MINOR"
# fi

# echo "Risk Score: $RISK_SCORE"
# echo "Severity: $SEVERITY"

# ------------------------------------------------------------
# FORMAT FILE LIST
# ------------------------------------------------------------

FILES_MARKDOWN=$(echo "$FILES_CHANGED" | sed 's/^/- /')

REASON_TEXT=$(printf '%s\n' "${REASONS[@]}" | sed 's/^/- /')

# # ------------------------------------------------------------
# # GOOGLE CHAT ALERT
# # ------------------------------------------------------------

# if [ -n "$GCHAT_WEBHOOK" ]; then

# cat <<EOF > payload.json
# {
#   "cardsV2": [
#     {
#       "cardId": "risk-alert",
#       "card": {
#         "header": {
#           "title": "🚨 PR Risk Analysis",
#           "subtitle": "$SEVERITY severity detected"
#         },
#         "sections": [
#           {
#             "widgets": [
#               {
#                 "decoratedText": {
#                   "topLabel": "Repository",
#                   "text": "$GITHUB_REPOSITORY"
#                 }
#               },
#               {
#                 "decoratedText": {
#                   "topLabel": "Branch",
#                   "text": "$BRANCH_NAME"
#                 }
#               },
#               {
#                 "decoratedText": {
#                   "topLabel": "Commit",
#                   "text": "$COMMIT_SHORT: $COMMIT_MSG"
#                 }
#               },
#               {
#                 "decoratedText": {
#                   "topLabel": "Author",
#                   "text": "$AUTHOR"
#                 }
#               },
#               {
#                 "decoratedText": {
#                   "topLabel": "Severity",
#                   "text": "$SEVERITY"
#                 }
#               },
#               {
#                 "decoratedText": {
#                   "topLabel": "Deleted Lines",
#                   "text": "$DELETED_COUNT"
#                 }
#               },
#               {
#                 "decoratedText": {
#                   "topLabel": "Added Lines",
#                   "text": "$ADDED_COUNT"
#                 }
#               },
#               {
#                 "textParagraph": {
#                   "text": "<b>Risk Reasons:</b><br><pre>$REASON_TEXT</pre>"
#                 }
#               }
#             ]
#           },
#           {
#             "widgets": [
#               {
#                 "buttonList": {
#                   "buttons": [
#                     {
#                       "text": "VIEW COMMIT",
#                       "onClick": {
#                         "openLink": {
#                           "url": "$COMMIT_URL"
#                         }
#                       }
#                     }
#                   ]
#                 }
#               }
#             ]
#           }
#         ]
#       }
#     }
#   ]
# }
# EOF

# curl -s -X POST "$GCHAT_WEBHOOK" \
#   -H "Content-Type: application/json" \
#   -d @payload.json

# fi

# ------------------------------------------------------------
# PR COMMENT
# ------------------------------------------------------------

PR_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

COMMENT_BODY=$(cat <<EOF
# $ALERT_ICON Automated PR Alert

| Field | Value |
|---|---|
| Alert | $ALERT_MESSAGE |
| Deleted Lines | $DELETED_COUNT |
| Added Lines | $ADDED_COUNT |
| Commit | [$COMMIT_SHORT]($COMMIT_URL) |
| Author | $AUTHOR |


# ## Alert Reasons

# $REASON_TEXT

## Deleted Line References

\`\`\`
$FORMATTED_DELETIONS
\`\`\`

## Files Changed

\`\`\`
$FILES_MARKDOWN
\`\`\`

[View Commit]($COMMIT_URL)

EOF

)

gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY"


echo "Risk analysis completed successfully."
