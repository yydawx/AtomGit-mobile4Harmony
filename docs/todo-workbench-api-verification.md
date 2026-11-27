# Todo Workbench API Verification

This record captures the API evidence used by the Issue and Pull Request worklists.
It contains no credentials or private repository data.

**Verified:** 2026-11-24 (Asia/Shanghai)

## Evidence Legend

| Mark | Meaning |
| --- | --- |
| D | Official AtomGit API documentation |
| L | Live read against `https://api.atomgit.com` |
| S | Local fixture, contract test, or existing verified adapter test |
| T | Requires an authenticated test account or device |

## Endpoint Matrix

| Purpose | Endpoint | Evidence | Notes |
| --- | --- | --- | --- |
| Assigned Issues | `GET /api/v5/user/issues?filter=assigned` | D, S | Requires authentication. Covered by the existing Todo adapter tests. |
| Created Issues | `GET /api/v5/user/issues?filter=created` | D, S | Requires authentication. Returns the current user's Issues. |
| Assigned Pull Requests | `GET /api/v5/user/pulls?scope=assigned_to_me` | D, S | Requires authentication. |
| Review-requested Pull Requests | `GET /api/v5/user/pulls?scope=need_my_review` | D, S | Requires authentication. |
| Approval-requested Pull Requests | `GET /api/v5/user/pulls?scope=need_my_approve` | D, S | Requires authentication. |
| Created Pull Requests | `GET /api/v5/user/pulls?scope=created_by_me` | D, S | Requires authentication. |
| Repository Issues | `GET /api/v5/repos/{owner}/{repo}/issues` | D, L, S | Public response verified. Supports open state, updated sort, pagination, assignee, creator, labels, and keyword search. |
| Repository Pull Requests | `GET /api/v5/repos/{owner}/{repo}/pulls` | D, L, S | Public response verified. Supports open state, pagination, author, assignee, and reviewer filters. |
| Issue Search | `GET /api/v5/search/issues` | D | The response has repository owner information but no Issue author. Not sufficient for excluding the current user without extra reads. |

Anonymous requests to `/user/issues`, `/user/pulls`, and `/user/repos` returned `401`, confirming that these endpoints require authentication.

## Observed Repository Issue Fields

A live request against the public `hust-open-atom-club/atomgit-cli` repository returned:

- `user.login`: Issue author.
- `assignees[]`: assigned users.
- `labels[]`: Issue labels.
- `comments`: comment count.
- `state`, `created_at`, `updated_at`, `number`, `title`, and `html_url`.

The author is available in the repository Issue list, so owned-project filtering does not require one detail request per Issue.

## Observed Repository Pull Request Fields

A live request against the same repository returned:

- `user.login`: Pull Request author.
- `assignees[]`: assigned users.
- `testers[]`: test users.
- `labels[]`: labels.
- `draft`: draft state.
- `notes`: timeline note count. This is the list-level comment/activity count.
- `state`, `created_at`, `updated_at`, `number`, `title`, `html_url`, `mergeable`, and `merged_at`.

The repository Pull Request list does **not** include `reviewers` or `approval_reviewers`. Review and approval membership must come from the authenticated `/user/pulls` scopes or a detail readback.

## Owned Repository Discovery

Use the authenticated `/user/repos` pages and retain repositories whose
`owner.login` equals the current user's login. The first workbench version treats
this as an owned project. Organization-owned repositories require a separate
permission check and are not inferred from membership alone.

## Workbench Decisions

- Assigned and review/approval relations come from authenticated user-level endpoints.
- Owned-project candidates come from repository-level Issue and Pull Request lists.
- Filter out repository items whose `user.login` equals the current user.
- Use `comments` for Issue rows and `notes` for Pull Request rows.
- Do not use Issue search for owned-project exclusion because it omits the author.
- Do not show a total count unless the server returns a complete count. The workbench
  may show a count of loaded items or an explicit `+` continuation, but not an invented total.
- Review and approval reasons are merged into one visible Pull Request item. The item
  is deduplicated by `kind + RepositoryItemRef.key()`.
- A PR may appear as assigned and review-requested at the same time. Both reasons remain
  attached to the single row.

## Remaining Authenticated Checks

- Verify `/user/issues` and `/user/pulls` responses with a dedicated test account.
- Verify owned-project pagination with more repositories than one page.
- Verify that a PR returned by multiple `/user/pulls` scopes has a stable repository and
  number across responses.
- Verify 401, 403, 429, cancellation, and short non-terminal pages on the repository
  Issue/Pull Request endpoints.
- Verify large-page behavior for accounts with many owned repositories.
