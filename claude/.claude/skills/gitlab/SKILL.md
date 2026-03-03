---
name: gitlab
description: Access GitLab at gitlab.abagile.com using the read-only API. Use when user wants to view MRs, pipelines, issues, diffs, comments, or any GitLab data.
---

# GitLab API Access

Access `https://gitlab.abagile.com/` via GitLab API v4 using `$GITLAB_READONLY_TOKEN`.

## Step 1: Get Token

The token is stored in env `$GITLAB_READONLY_TOKEN`. Always read it from the environment:

```bash
echo "$GITLAB_READONLY_TOKEN"
```

- **DO NOT** look for token files, config files, or credentials directories
- **DO NOT** prompt the user for the token
- **DO NOT** try `glab`, `.gitlabrc`, `.netrc`, or any other source
- If `$GITLAB_READONLY_TOKEN` is empty, tell the user to set it and stop

## Step 2: API Calls

All API calls use the token from Step 1:
```bash
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" "https://gitlab.abagile.com/api/v4/..."
```

## Project Detection

Auto-detect the current project from git remote, then **resolve to numeric ID**:

```bash
# 1. Extract project path from git remote (handles both SSH and HTTPS)
PROJECT_PATH=$(git remote get-url origin 2>/dev/null \
  | sed -E 's#(ssh://)?git@gitlab\.abagile\.com(:7788)?[:/]##; s#https://gitlab\.abagile\.com/##; s#\.git$##')

# 2. Resolve to numeric project ID (more reliable than URL-encoded path)
PROJECT_ID=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$(echo $PROJECT_PATH | sed 's#/#%2F#g')" \
  | jq '.id')
```

**Always use the numeric `$PROJECT_ID` in API calls** instead of URL-encoded path. The URL-encoded path (`metis%2Fnerv`) can intermittently return 404 on some endpoints (notably wikis), while numeric IDs are always reliable.

When parsing user-provided URLs, also resolve the project path to ID before making API calls.

## Common Operations

### Merge Requests

```bash
# List open MRs for current project
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/merge_requests?state=opened&per_page=20" \
  | jq '.[] | {iid, title, author: .author.name, source_branch, target_branch, web_url}'

# Get single MR by IID (the ! number)
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/merge_requests/<iid>"

# Get MR changes (diff)
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/merge_requests/<iid>/changes"

# Get MR discussions (comments/threads)
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/merge_requests/<iid>/discussions?per_page=100"

# Get MR approvals
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/merge_requests/<iid>/approvals"
```

### Pipelines

```bash
# List recent pipelines
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/pipelines?per_page=10" \
  | jq '.[] | {id, status, ref, created_at, web_url}'

# Get pipeline jobs
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/pipelines/<pipeline_id>/jobs" \
  | jq '.[] | {id, name, stage, status, web_url}'

# Get job log
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/jobs/<job_id>/trace"
```

### Issues

```bash
# List open issues
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/issues?state=opened&per_page=20" \
  | jq '.[] | {iid, title, author: .author.name, labels, web_url}'
```

### Repository

```bash
# List branches
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/repository/branches?per_page=20" \
  | jq '.[] | {name, commit: .commit.short_id, updated: .commit.committed_date}'

# Read file content (base64 decoded)
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/repository/files/<url_encoded_file_path>?ref=<branch>" \
  | jq -r '.content' | base64 -d

# Compare branches
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/repository/compare?from=<base>&to=<head>"
```

### Wiki

```bash
# List wiki pages
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/wikis" \
  | jq '.[] | {slug, title}'

# Get wiki page content
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/wikis/<slug>" \
  | jq -r '.content'
```

### Search

```bash
# Search in project code
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/search?scope=blobs&search=<query>"

# Search MRs
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/merge_requests?search=<query>&per_page=10"
```

## URL Parsing

When user provides a GitLab URL, extract the info:

- MR URL: `https://gitlab.abagile.com/metis/nerv/-/merge_requests/123` → project=`metis/nerv`, iid=`123`
- Pipeline URL: `https://gitlab.abagile.com/metis/nerv/-/pipelines/456` → project=`metis/nerv`, pipeline_id=`456`
- Issue URL: `https://gitlab.abagile.com/metis/nerv/-/issues/78` → project=`metis/nerv`, iid=`78`
- Wiki URL: `https://gitlab.abagile.com/metis/nerv/-/wikis/ng-input` → project=`metis/nerv`, slug=`ng-input`

## Guidelines

- Always use `jq` to format JSON output for readability
- Use `per_page` parameter to control result count (default 20, max 100)
- For paginated results, check `x-total` and `x-next-page` response headers if needed
- The token is **read-only** - do not attempt write operations (POST/PUT/DELETE)
- When fetching MR diffs, summarize large diffs instead of dumping raw output
- When fetching discussions, focus on unresolved threads unless asked otherwise
