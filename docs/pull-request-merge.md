# Pull Request Merge

The pull request detail page supports merging without requiring the current user to be an
assignee. AtomGit computes merge eligibility and authorization for the authenticated user.

## Server Permission Discovery

`GET /api/v5/repos/{owner}/{repo}/pulls/{number}` returns:

- `mergeable`: whether the branch has conflicts.
- `can_merge_check`: whether the merge checks pass.
- `draft`: whether the pull request is a draft.
- `mergeable_state`: access-control and merge-gate information for the authenticated viewer.
- `mergeable_state.state`: the overall server merge gate.
- `mergeable_state.merged_by_user_passed`: whether the current user passes the user merge
  permission gate.
- `mergeable_state.reason`: server explanations for failed gates.

Live anonymous verification against an open public pull request returned:

```json
{
  "state": false,
  "merged_by_user_passed": false,
  "reason": {
    "merged_by_user_passed": "You are in project members list, but do not have PUSH permission, please check it."
  }
}
```

This confirms that merge permission is viewer-specific and supplied by the server. The client
does not infer permission from assignment, author, or repository ownership.

## Merge Endpoint

`PUT /api/v5/repos/{owner}/{repo}/pulls/{number}/merge`

Supported body fields include `merge_method`, `force_merge`, and `squash`. The app sends the
normal `merge` method and does not request force merge.

## Client Behavior

The merge action is available only when all server gates and local state checks pass:

- Open and not already merged.
- Not a draft.
- `mergeable` is true.
- `can_merge_check` is true.
- `mergeable_state.state` is true.
- `mergeable_state.merged_by_user_passed` is true.

The UI displays the server-provided blocking reason when permission or merge gates fail.

Before writing, the client re-reads the pull request and verifies the expected head SHA. This
prevents merging a head that changed after the user opened the page.

The user must confirm the merge a second time. After the PUT request, the adapter reads the
pull request again and returns the reread detail only when it is merged. The store does not
show success until that readback confirms `merged`, `merged_at`, or `state: "merged"`.

After confirmation, the pull request store publishes a collaboration refresh so the TODO
worklist and related pull request list data update.

## Error Behavior

- A server permission gate failure is shown before any merge request is sent.
- A head mismatch requires reviewing and refreshing the latest head.
- A merge request followed by a failed or unconfirmed readback is marked unconfirmed.
- A normal merge failure returns the original `ApiError` and never displays success.

## Tests

Contract tests cover:

- Mapping `mergeable_state` and `reason`.
- Permission denial before the write.
- Expected-head mismatch before the write.
- PUT path and payload.
- Merge readback confirmation.
- Store confirmation and callback behavior.
- Store unconfirmed and permission-denied states.

A real destructive merge is not part of the automated device test. Final acceptance should use
a dedicated repository where the test account has the required merge permission.
