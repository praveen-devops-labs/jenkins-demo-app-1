#!/bin/bash
set -eo pipefail

AUTHOR=$(git log -1 --format="%an <%ae>")
COMMIT_SHA=$(git rev-parse HEAD)
COMMIT_SHORT=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --format="%s")
TIMESTAMP=$(git log -1 --format="%ci")
BRANCH_NAME="${GITHUB_REF_NAME}"

echo "Scanning commit for deleted lines..."

# Detect deleted code lines only
DELETED=$(git diff HEAD~1..HEAD \
  -- '*.js' '*.ts' '*.py' '*.java' '*.go' '*.rb' '*.cs' '*.sh' \
  | grep '^-' \
  | grep -v '^---' \
  | grep -v '^-[[:space:]]*$' \
  | grep -v '^-[[:space:]]*//' \
  || true
)

DELETED_COUNT=$(echo "$DELETED" | grep -c '^-' || true)

if [ "$DELETED_COUNT" -eq 0 ]; then
  echo "No meaningful code deletions found."
  exit 0
fi

echo "⚠️ $DELETED_COUNT deleted lines detected"

# Limit output size
DELETED_PREVIEW=$(echo "$DELETED" | head -20 | sed 's/"/\\"/g')

COMMIT_URL="https://github.com/$GITHUB_REPOSITORY/commit/$COMMIT_SHA"

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
                  "text": "<b>Deleted Code Preview:</b><br><font color=\"#d93025\"><pre>$DELETED_PREVIEW</pre></font>"
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

CURRENT_BRANCH=$(git branch --show-current)

PR_NUMBER=$(gh pr list \
  --state open \
  --json number,headRefName \
  --jq '.[] | select(.headRefName == "'"$CURRENT_BRANCH"'") | .number' \
  2>/dev/null || true)

if [ -n "$PR_NUMBER" ]; then

  echo "Posting PR comment..."

  COMMENT_BODY=$(cat <<EOF
### ⚠️ Code Deletion Detected

**Author:** $AUTHOR

**Commit:** \`$COMMIT_SHORT\`

**Deleted Lines:** $DELETED_COUNT

<details>
<summary>Deleted Code Preview</summary>

\`\`\`diff
$(echo "$DELETED" | head -50)
\`\`\`

</details>

> Please verify this deletion is intentional.
EOF
)

  gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY"

fi
