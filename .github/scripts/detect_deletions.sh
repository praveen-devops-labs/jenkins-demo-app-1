#!/bin/bash
set -e

AUTHOR=$(git log -1 --format="%an <%ae>")
COMMIT_SHA=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --format="%s")
TIMESTAMP=$(git log -1 --format="%ci")

# Get only deleted lines (starts with -) from actual code files
# Excludes lock files, changelogs, etc.
DELETED=$(git diff HEAD~1..HEAD \
  -- '*.js' '*.ts' '*.py' '*.java' '*.go' '*.rb' '*.cs' \
  | grep '^-' \
  | grep -v '^---' \       # exclude file path lines
  | grep -v '^-[[:space:]]*$' \   # exclude blank line deletions
  | grep -v '^-[[:space:]]*//' \  # exclude comment deletions (optional)
)

DELETED_COUNT=$(echo "$DELETED" | grep -c '^-' || true)

if [ "$DELETED_COUNT" -eq 0 ]; then
  echo "No meaningful code deletions found."
  exit 0
fi

echo "⚠️ $DELETED_COUNT deleted lines detected"

# ---- Post to Google Chat ----
if [ -n "$GCHAT_WEBHOOK" ]; then
  curl -s -X POST "$GCHAT_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
      \"cardsV2\": [{
        \"cardId\": \"deletion-alert\",
        \"card\": {
          \"header\": {
            \"title\": \"🚨 Code Deletion Detected\",
            \"subtitle\": \"Automated alert from GitHub Actions\",
            \"imageUrl\": \"https://www.gstatic.com/images/icons/material/system/2x/warning_red_24dp.png\",
            \"imageType\": \"CIRCLE\"
          },
          \"sections\": [{
            \"widgets\": [
              {
                \"decoratedText\": {
                  \"topLabel\": \"Author\",
                  \"text\": \"$AUTHOR\"
                }
              },
              {
                \"decoratedText\": {
                  \"topLabel\": \"Commit\",
                  \"text\": \"$COMMIT_SHA — $COMMIT_MSG\"
                }
              },
              {
                \"decoratedText\": {
                  \"topLabel\": \"Lines Deleted\",
                  \"text\": \"$DELETED_COUNT lines removed\"
                }
              },
              {
                \"decoratedText\": {
                  \"topLabel\": \"Branch\",
                  \"text\": \"$GITHUB_REF_NAME\"
                }
              },
              {
                \"decoratedText\": {
                  \"topLabel\": \"Timestamp\",
                  \"text\": \"$TIMESTAMP\"
                }
              }
            ]
          },
          {
            \"widgets\": [{
              \"buttonList\": {
                \"buttons\": [{
                  \"text\": \"View Commit\",
                  \"onClick\": {
                    \"openLink\": {
                      \"url\": \"https://github.com/$GITHUB_REPOSITORY/commit/$COMMIT_SHA\"
                    }
                  }
                }]
              }
            }]
          }]
        }
      }]
    }"
fi
# ---- Post PR comment (if this commit is tied to an open PR) ----
PR_NUMBER=$(gh pr list --state open --json number,headRefName \
  --jq '.[] | select(.headRefName == "'"$(git branch --show-current)"'") | .number' \
  2>/dev/null || true)

if [ -n "$PR_NUMBER" ]; then
  COMMENT_BODY="### ⚠️ Code Deletion Detected

**Author:** $AUTHOR
**Commit:** \`$COMMIT_SHA\`
**Deleted lines:** $DELETED_COUNT

<details>
<summary>View deleted lines</summary>

\`\`\`diff
$(echo "$DELETED" | head -50)
\`\`\`

</details>

> This is an automated alert. Please confirm this deletion was intentional."

  gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY"
fi
