#!/bin/bash

set -eo pipefail

echo "Starting deletion scan..."

AUTHOR=$(git log -1 --format="%an <%ae>")
COMMIT_SHA=$(git rev-parse HEAD)
COMMIT_SHORT=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --format="%s")
TIMESTAMP=$(git log -1 --format="%ci")
BRANCH_NAME="${GITHUB_REF_NAME}"

COMMIT_URL="https://github.com/$GITHUB_REPOSITORY/commit/$COMMIT_SHA"

# --------------------------------------------------------
# Detect meaningful deleted lines
# --------------------------------------------------------

DELETED=$(git diff HEAD~1..HEAD \
  -- '*.java' '*.js' '*.ts' '*.py' '*.go' '*.rb' '*.cs' \
  | grep '^-' \
  | grep -v '^---' \
  | grep -v '^-[[:space:]]*$' \
  | grep -v '^-[[:space:]]*//' \
  || true
)

DELETED_COUNT=$(echo "$DELETED" | grep -c '^-' || true)

if [ "$DELETED_COUNT" -eq 0 ]; then
  echo "No meaningful deletions found."
  exit 0
fi

echo "⚠️ $DELETED_COUNT deleted lines detected"

# --------------------------------------------------------
# Extract affected files
# --------------------------------------------------------

FILES_CHANGED=$(git diff --name-only HEAD~1..HEAD \
  -- '*.java' '*.js' '*.ts' '*.py' '*.go' '*.rb' '*.cs' \
  | sed 's/^/- /')

# --------------------------------------------------------
# Google Chat Notification
# --------------------------------------------------------

if [ -n "$GCHAT_WEBHOOK" ]; then

  echo "Sending Google Chat notification..."

  cat <<EOF > payload.json
{
  "cardsV2": [
    {
      "cardId": "deletion-alert",
      "card": {
        "header": {
          "title": "🚨 Code Deletion Detected",
          "subtitle": "Automated GitHub Actions Alert"
        },
        "sections": [
          {
            "widgets": [
              {
                "decoratedText": {
                  "topLabel": "Repository",
                  "text": "$GITHUB_REPOSITORY"
                }
              },
              {
                "decoratedText": {
                  "topLabel": "Branch",
                  "text": "$BRANCH_NAME"
                }
              },
              {
                "decoratedText": {
                  "topLabel": "Author",
                  "text": "$AUTHOR"
                }
              },
              {
                "decoratedText": {
                  "topLabel": "Commit",
                  "text": "$COMMIT_SHORT - $COMMIT_MSG"
                }
              },
              {
                "decoratedText": {
                  "topLabel": "Deleted Lines",
                  "text": "$DELETED_COUNT lines removed"
                }
              },
              {
                "textParagraph": {
                  "text": "<b>Affected Files:</b><br><pre>$FILES_CHANGED</pre>"
                }
              }
            ]
          },
          {
            "widgets": [
              {
                "buttonList": {
                  "buttons": [
                    {
                      "text": "VIEW COMMIT",
                      "onClick": {
                        "openLink": {
                          "url": "$COMMIT_URL"
                        }
                      }
                    }
                  ]
                }
              }
            ]
          }
        ]
      }
    }
  ]
}
EOF

  curl -s -X POST "$GCHAT_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d @payload.json

fi

# --------------------------------------------------------
# PR Comment
# --------------------------------------------------------

PR_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH" 2>/dev/null || true)

if [ "$PR_NUMBER" != "null" ] && [ -n "$PR_NUMBER" ]; then

  echo "Posting PR comment to PR #$PR_NUMBER"

  COMMENT_BODY=$(cat <<EOF
### ⚠️ Code Deletion Detected

| Field | Value |
|---|---|
| Author | $AUTHOR |
| Branch | $BRANCH_NAME |
| Commit | \`$COMMIT_SHORT\` |
| Deleted Lines | $DELETED_COUNT |

#### Affected Files

\`\`\`
$FILES_CHANGED
\`\`\`

[View Commit]($COMMIT_URL)

> Please verify that these deletions are intentional.
EOF
)

  gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY"

fi

echo "Deletion scan completed."
