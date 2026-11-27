# Todo Workbench

The Todo tab is a two-level workbench modeled on GitHub Mobile's My Work interaction.

## Navigation

```text
Todo
Related to me
Issues           >
Pull Requests    >
```

- The Todo landing page performs no API requests and shows no counts.
- Both entries push full-screen `HdsNavDestination` pages; the bottom tab bar is hidden.
- A list row pushes the existing Issue or Pull Request detail page.
- Back navigation returns to the same list and preserves the selected filter.
- The Todo store remains alive across detail navigation so loaded rows are not discarded.

## Lists

Both lists use a back button, title, active-filter subtitle, filter menu, flat rows,
pull-to-refresh, and continuation loading.

Issue row metadata:

- Repository and Issue number.
- Title.
- Relation label and open/closed state.
- Comment count and relative update time.

Pull Request row metadata:

- Repository and Pull Request number.
- Title.
- Relation label, draft/review state, and open state.
- Note count and relative update time.

## Filters

Issues:

- All
- Assigned to you
- Created by you
- Owned projects

Pull Requests:

- All
- Waiting for your review or approval
- Assigned to you
- Created by you
- Owned projects

`All` is the default. Selecting a filter only projects the loaded relation union; items are
not duplicated between filters.

## Sources and Ordering

Issues use:

- `/user/issues?filter=assigned`
- `/user/issues?filter=created`
- Open Issues from each repository owned by the current user.

Pull Requests use:

- `/user/pulls?scope=assigned_to_me`
- `/user/pulls?scope=need_my_review`
- `/user/pulls?scope=need_my_approve`
- `/user/pulls?scope=created_by_me`
- Open Pull Requests from each repository owned by the current user.

An owned repository is one whose `owner.login` equals the current user's login. Items from
owned repositories are excluded when their author is the current user.

Every item is keyed by `kind + RepositoryItemRef.key()`. If the same item appears in
multiple sources, the reasons are merged and the item is rendered once.

Ordering is:

1. Assigned to the current user.
2. Review or approval requested from the current user.
3. Another author's item in an owned project.
4. Created by the current user.

Within one relation priority, items are ordered by update time descending and then by
stable item key.

## Loading and Failure Behavior

- Sources are loaded with a maximum concurrency of two.
- A source page contains ten items by default.
- Source requests continue with independent offset cursors.
- A failed source does not discard rows loaded by another source.
- A full-page error appears only when every active source fails and no rows exist.
- A partial-failure banner preserves loaded rows and exposes retry.
- Pull-to-refresh reloads all sources, including sources for inactive filters.
- Issue and Pull Request write confirmations refresh the matching Todo store.
- Counts are never presented as complete totals; the list only says that all currently
  loaded rows are visible.

## API Limitations

- Issue search does not return the author, so owned-project Issue filtering uses
  repository-level lists.
- Repository Pull Request list responses do not contain reviewer or approval lists.
  Review and approval membership comes from the authenticated `/user/pulls` scopes.
- Organization-owned projects are not inferred from membership in the first version.
  Only repositories whose direct owner is the current user are included.
- No local-only Done or Save action is added because AtomGit has no matching persisted
  state for these rows.

See [Todo Workbench API Verification](todo-workbench-api-verification.md) for field-level
evidence.

## Verification

Local tests:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
--mode module -p module=entry@default -p product=default test
```

Main HAP:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
--mode module -p module=entry@default -p product=default assembleHap
```

Device test and emulator commands are documented in [End-to-End Testing](e2e-testing.md).
