import { describe, it, expect } from '@ohos/hypium';

import { RepositoryItemKind, RepositoryItemRef } from '../main/ets/model/CollaborationEntities';
import { IssueDto, PullRequestDto } from '../main/ets/model/CollaborationDtos';
import {
  mergeTodoItems,
  projectTodoItems,
  relativeTodoTime,
  sortTodoItems,
  TodoFilter,
  TodoListItem,
  TodoListKind,
  TodoRelation,
  todoFilterOptions,
  todoStatusSummary
} from '../main/ets/model/TodoWorkbench';
import { AppRoute, AppRouteName, TodoListParams } from '../main/ets/navigation/AppRoute';

function todoItem(kind: RepositoryItemKind, number: number, updatedAt: string,
  relations: TodoRelation[], title: string = ''): TodoListItem {
  return new TodoListItem(kind, new RepositoryItemRef('owner', 'repo', number),
    title.length > 0 ? title : 'Item ' + number.toString(), 'open', updatedAt, relations);
}

export default function todoWorkbenchTest() {
  describe('TodoWorkbench', () => {
    it('deduplicates_items_and_merges_relation_reasons', 0, () => {
      const older = new TodoListItem(RepositoryItemKind.PullRequest,
        new RepositoryItemRef('owner', 'repo', 12), 'Older title', 'open',
        '2026-11-24T08:00:00Z', [TodoRelation.Assigned], 'author', [], [], 1, ['bug']);
      const newer = new TodoListItem(RepositoryItemKind.PullRequest,
        new RepositoryItemRef('owner', 'repo', 12), 'Newer title', 'open',
        '2026-11-24T09:00:00Z',
        [TodoRelation.ReviewRequested, TodoRelation.ApprovalRequested],
        'author', [], ['reviewer'], 3, ['bug', 'priority']);

      const merged = mergeTodoItems([older], [newer]);

      expect(merged.length).assertEqual(1);
      expect(merged[0].title).assertEqual('Newer title');
      expect(merged[0].comments).assertEqual(3);
      expect(merged[0].labels.length).assertEqual(2);
      expect(merged[0].relations.length).assertEqual(3);
      expect(merged[0].relations[0]).assertEqual(TodoRelation.Assigned);
    });

    it('handles_missing_authors_and_trims_metadata', 0, () => {
      const withoutAuthor = new TodoListItem(RepositoryItemKind.Issue,
        new RepositoryItemRef('owner', 'repo', 5), 'Missing author', 'open',
        '2026-11-24T08:00:00Z', [TodoRelation.OwnedProject], '',
        [], [], 0, [' bug ', '', 'bug']);
      const withAuthor = new TodoListItem(RepositoryItemKind.Issue,
        new RepositoryItemRef('owner', 'repo', 5), 'With author', 'open',
        '2026-11-24T09:00:00Z', [TodoRelation.Assigned], 'other-author');

      const merged = mergeTodoItems([withoutAuthor], [withAuthor]);

      expect(merged.length).assertEqual(1);
      expect(merged[0].author).assertEqual('other-author');
      expect(merged[0].labels.length).assertEqual(1);
      expect(merged[0].labels[0]).assertEqual('bug');
      expect(merged[0].relations.length).assertEqual(2);
    });

    it('orders_assigned_review_owned_and_created_items', 0, () => {
      const created = todoItem(RepositoryItemKind.Issue, 4, '2026-11-24T12:00:00Z',
        [TodoRelation.CreatedByMe]);
      const owned = todoItem(RepositoryItemKind.Issue, 3, '2026-11-24T11:00:00Z',
        [TodoRelation.OwnedProject]);
      const review = todoItem(RepositoryItemKind.PullRequest, 2, '2026-11-24T10:00:00Z',
        [TodoRelation.ReviewRequested]);
      const assigned = todoItem(RepositoryItemKind.Issue, 1, '2026-11-24T09:00:00Z',
        [TodoRelation.Assigned]);

      const sorted = sortTodoItems([created, owned, review, assigned]);

      expect(sorted[0].ref.number).assertEqual(1);
      expect(sorted[1].ref.number).assertEqual(2);
      expect(sorted[2].ref.number).assertEqual(3);
      expect(sorted[3].ref.number).assertEqual(4);
    });

    it('uses_update_time_within_the_same_relation_priority', 0, () => {
      const older = todoItem(RepositoryItemKind.Issue, 1, '2026-11-24T09:00:00Z',
        [TodoRelation.Assigned]);
      const newer = todoItem(RepositoryItemKind.Issue, 2, '2026-11-24T10:00:00Z',
        [TodoRelation.Assigned]);

      const sorted = sortTodoItems([older, newer]);

      expect(sorted[0].ref.number).assertEqual(2);
      expect(sorted[1].ref.number).assertEqual(1);
    });

    it('defines_kind_specific_filter_options', 0, () => {
      const issueOptions = todoFilterOptions(TodoListKind.Issues);
      const pullOptions = todoFilterOptions(TodoListKind.PullRequests);

      expect(issueOptions.length).assertEqual(4);
      expect(pullOptions.length).assertEqual(5);
      expect(issueOptions.map((option) => option.value).indexOf(TodoFilter.WaitingForYou) < 0)
        .assertTrue();
      expect(pullOptions.map((option) => option.value).indexOf(TodoFilter.WaitingForYou) >= 0)
        .assertTrue();
    });

    it('projects_items_by_relation_filter', 0, () => {
      const assigned = todoItem(RepositoryItemKind.Issue, 1, '2026-11-24T09:00:00Z',
        [TodoRelation.Assigned]);
      const waiting = todoItem(RepositoryItemKind.PullRequest, 2, '2026-11-24T10:00:00Z',
        [TodoRelation.ApprovalRequested]);
      const owned = todoItem(RepositoryItemKind.Issue, 3, '2026-11-24T11:00:00Z',
        [TodoRelation.OwnedProject]);
      const created = todoItem(RepositoryItemKind.Issue, 4, '2026-11-24T12:00:00Z',
        [TodoRelation.CreatedByMe]);

      expect(projectTodoItems([assigned, waiting, owned, created], TodoFilter.All).length)
        .assertEqual(4);
      expect(projectTodoItems([assigned, waiting, owned, created], TodoFilter.Assigned)[0].ref.number)
        .assertEqual(1);
      expect(projectTodoItems([assigned, waiting, owned, created], TodoFilter.WaitingForYou)[0].ref.number)
        .assertEqual(2);
      expect(projectTodoItems([assigned, waiting, owned, created], TodoFilter.OwnedProjects)[0].ref.number)
        .assertEqual(3);
      expect(projectTodoItems([assigned, waiting, owned, created], TodoFilter.CreatedByMe)[0].ref.number)
        .assertEqual(4);
    });

    it('formats_relative_time_and_status_metadata', 0, () => {
      const now = new Date('2026-11-24T12:00:00Z');
      const item = new TodoListItem(RepositoryItemKind.PullRequest,
        new RepositoryItemRef('owner', 'repo', 8), 'Fix status', 'open',
        '2026-11-24T10:30:00Z', [TodoRelation.ReviewRequested], 'author', [], ['reviewer'],
        2, [], 'Waiting for review');

      expect(relativeTodoTime(item.updatedAt, now)).assertEqual('1 小时前');
      expect(todoStatusSummary(item, now).indexOf('待评审') >= 0).assertTrue();
      expect(todoStatusSummary(item, now).indexOf('2 条评论') >= 0).assertTrue();
    });

    it('covers_author_and_pull_request_list_fields', 0, () => {
      const issue: IssueDto = {
        user: { login: 'other-author' },
        assignees: [{ login: 'assigned-user' }],
        comments: 2
      };
      const pull: PullRequestDto = {
        user: { login: 'other-author' },
        assignees: [{ login: 'assigned-user' }],
        testers: [{ login: 'tester' }],
        draft: true,
        notes: 4
      };

      expect(issue.user === undefined ? '' : (issue.user.login ?? '')).assertEqual('other-author');
      expect(issue.comments).assertEqual(2);
      expect(pull.draft).assertTrue();
      expect(pull.notes).assertEqual(4);
      expect(pull.testers === undefined ? 0 : pull.testers.length).assertEqual(1);
    });

    it('creates_typed_todo_list_routes', 0, () => {
      const issues = AppRoute.todoIssues();
      const pulls = AppRoute.todoPullRequests();
      const issueParams = issues.params as TodoListParams;
      const pullParams = pulls.params as TodoListParams;

      expect(issues.name).assertEqual(AppRouteName.TodoIssues);
      expect(pulls.name).assertEqual(AppRouteName.TodoPullRequests);
      expect(issueParams.kind).assertEqual(TodoListKind.Issues);
      expect(pullParams.kind).assertEqual(TodoListKind.PullRequests);
    });
  });
}
