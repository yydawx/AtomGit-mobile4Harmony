import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { OffsetPageRequest, Page, PageRequest } from '../main/ets/common/Pager';
import { RepositoryItemKind, RepositoryItemRef } from '../main/ets/model/CollaborationEntities';
import { RepoSummary } from '../main/ets/model/Entities';
import {
  TodoFilter,
  TodoListItem,
  TodoListKind,
  TodoRelation
} from '../main/ets/model/TodoWorkbench';
import { PullRequestTodoScope, TodoWorkbenchRepository } from '../main/ets/repository/Ports';
import { LoadState } from '../main/ets/viewmodel/SessionStore';
import { TodoWorklistStore } from '../main/ets/viewmodel/TodoWorklistStore';

function item(kind: RepositoryItemKind, number: number, relation: TodoRelation,
  author: string = 'other', updatedAt: string = '2026-11-24T08:00:00Z'): TodoListItem {
  return new TodoListItem(kind, new RepositoryItemRef('owner', 'repo', number),
    'Item ' + number.toString(), 'open', updatedAt, [relation], author);
}

function page(items: TodoListItem[], request: PageRequest, hasMore: boolean = false):
  Page<TodoListItem> {
  const offset = request as OffsetPageRequest;
  return new Page<TodoListItem>(items, request, hasMore
    ? new OffsetPageRequest(offset.page + 1, offset.perPage) : undefined);
}

function repo(owner: string, name: string): RepoSummary {
  return new RepoSummary(1, owner, name, name, owner + '/' + name, '', '', 'main',
    false, false, 0, 0, 0);
}

type TodoResult = Page<TodoListItem> | ApiError;

class FakeTodoWorkbenchRepository implements TodoWorkbenchRepository {
  assignedIssueResults: TodoResult[] = [];
  createdIssueResults: TodoResult[] = [];
  assignedPullResults: TodoResult[] = [];
  reviewPullResults: TodoResult[] = [];
  approvalPullResults: TodoResult[] = [];
  createdPullResults: TodoResult[] = [];
  repositoryIssueResults: TodoResult[] = [];
  repositoryPullResults: TodoResult[] = [];
  repositoryCalls: string[] = [];

  async assignedIssueItems(request: PageRequest): Promise<Page<TodoListItem>> {
    return this.take(this.assignedIssueResults, request);
  }

  async createdIssueItems(request: PageRequest): Promise<Page<TodoListItem>> {
    return this.take(this.createdIssueResults, request);
  }

  async pullRequestItems(scope: PullRequestTodoScope,
    request: PageRequest): Promise<Page<TodoListItem>> {
    if (scope === PullRequestTodoScope.AssignedToMe) {
      return this.take(this.assignedPullResults, request);
    }
    if (scope === PullRequestTodoScope.NeedsReview) {
      return this.take(this.reviewPullResults, request);
    }
    if (scope === PullRequestTodoScope.NeedsApproval) {
      return this.take(this.approvalPullResults, request);
    }
    return this.take(this.createdPullResults, request);
  }

  async repositoryIssueItems(owner: string, repoName: string,
    request: PageRequest): Promise<Page<TodoListItem>> {
    this.repositoryCalls.push('issue:' + owner + '/' + repoName);
    return this.take(this.repositoryIssueResults, request);
  }

  async repositoryPullRequestItems(owner: string, repoName: string,
    request: PageRequest): Promise<Page<TodoListItem>> {
    this.repositoryCalls.push('pull:' + owner + '/' + repoName);
    return this.take(this.repositoryPullResults, request);
  }

  private take(results: TodoResult[], request: PageRequest): Promise<Page<TodoListItem>> {
    const result = results.length > 0
      ? results.shift() as TodoResult : Page.empty<TodoListItem>(request);
    if (result instanceof ApiError) {
      throw result;
    }
    return Promise.resolve(result);
  }
}

export default function todoWorklistStoreTest() {
  describe('TodoWorklistStore', () => {
    it('merges_sources_deduplicates_and_excludes_own_owned_project_items', 0, () => {
      const data = new FakeTodoWorkbenchRepository();
      const assigned = item(RepositoryItemKind.Issue, 1, TodoRelation.Assigned, 'other',
        '2026-11-24T09:00:00Z');
      const created = item(RepositoryItemKind.Issue, 2, TodoRelation.CreatedByMe, 'me',
        '2026-11-24T08:00:00Z');
      const ownOwnedProject = item(RepositoryItemKind.Issue, 3, TodoRelation.OwnedProject,
        'me', '2026-11-24T10:00:00Z');
      const duplicate = item(RepositoryItemKind.Issue, 1, TodoRelation.OwnedProject,
        'other', '2026-11-24T09:30:00Z');
      const otherOwnedProject = item(RepositoryItemKind.Issue, 4, TodoRelation.OwnedProject,
        'other', '2026-11-24T07:00:00Z');
      data.assignedIssueResults.push(page([assigned], new OffsetPageRequest()));
      data.createdIssueResults.push(page([created], new OffsetPageRequest()));
      data.repositoryIssueResults.push(page([ownOwnedProject, duplicate, otherOwnedProject],
        new OffsetPageRequest()));

      const store = new TodoWorklistStore(data, TodoListKind.Issues);
      store.initialize('account-a', 'me', [repo('me', 'owned'), repo('org', 'other')]);
      return store.loadIfNeeded().then(() => {
        expect(store.items.length).assertEqual(3);
        expect(store.items[0].ref.number).assertEqual(1);
        expect(store.items[0].relations.length).assertEqual(2);
        expect(store.items.some((entry: TodoListItem) => entry.ref.number === 3)).assertFalse();
        expect(data.repositoryCalls.length).assertEqual(1);
        expect(data.repositoryCalls[0]).assertEqual('issue:me/owned');
        expect(store.ownedRepoCount).assertEqual(1);
      });
    });

    it('projects_pull_request_relations_and_merges_review_reasons', 0, () => {
      const data = new FakeTodoWorkbenchRepository();
      const assigned = item(RepositoryItemKind.PullRequest, 1, TodoRelation.Assigned,
        'other', '2026-11-24T09:00:00Z');
      const review = item(RepositoryItemKind.PullRequest, 2, TodoRelation.ReviewRequested,
        'other', '2026-11-24T10:00:00Z');
      const approval = item(RepositoryItemKind.PullRequest, 2, TodoRelation.ApprovalRequested,
        'other', '2026-11-24T10:30:00Z');
      const created = item(RepositoryItemKind.PullRequest, 3, TodoRelation.CreatedByMe,
        'me', '2026-11-24T08:00:00Z');
      const owned = item(RepositoryItemKind.PullRequest, 4, TodoRelation.OwnedProject,
        'other', '2026-11-24T07:00:00Z');
      const ownOwned = item(RepositoryItemKind.PullRequest, 5, TodoRelation.OwnedProject,
        'me', '2026-11-24T06:00:00Z');
      data.assignedPullResults.push(page([assigned], new OffsetPageRequest()));
      data.reviewPullResults.push(page([review], new OffsetPageRequest()));
      data.approvalPullResults.push(page([approval], new OffsetPageRequest()));
      data.createdPullResults.push(page([created], new OffsetPageRequest()));
      data.repositoryPullResults.push(page([owned, ownOwned], new OffsetPageRequest()));

      const store = new TodoWorklistStore(data, TodoListKind.PullRequests);
      store.initialize('account-a', 'me', [repo('me', 'owned')]);
      return store.loadIfNeeded()
        .then(() => {
          expect(store.items.length).assertEqual(4);
          return store.selectFilter(TodoFilter.WaitingForYou);
        })
        .then(() => {
          expect(store.items.length).assertEqual(1);
          expect(store.items[0].ref.number).assertEqual(2);
          expect(store.items[0].relations.length).assertEqual(2);
          return store.selectFilter(TodoFilter.Assigned);
        })
        .then(() => {
          expect(store.items[0].ref.number).assertEqual(1);
          return store.selectFilter(TodoFilter.CreatedByMe);
        })
        .then(() => {
          expect(store.items[0].ref.number).assertEqual(3);
          return store.selectFilter(TodoFilter.OwnedProjects);
        })
        .then(() => {
          expect(store.items.length).assertEqual(1);
          expect(store.items[0].ref.number).assertEqual(4);
        });
    });

    it('keeps_loaded_items_when_one_source_fails', 0, () => {
      const data = new FakeTodoWorkbenchRepository();
      data.assignedIssueResults.push(page([
        item(RepositoryItemKind.Issue, 1, TodoRelation.Assigned)
      ], new OffsetPageRequest()));
      data.createdIssueResults.push(new ApiError(ApiErrorKind.Network, 0, 0, 'offline',
        '', '/user/issues'));
      data.repositoryIssueResults.push(page([
        item(RepositoryItemKind.Issue, 2, TodoRelation.OwnedProject)
      ], new OffsetPageRequest()));

      const store = new TodoWorklistStore(data, TodoListKind.Issues);
      store.initialize('account-a', 'me', [repo('me', 'owned')]);
      return store.loadIfNeeded().then(() => {
        expect(store.items.length).assertEqual(2);
        expect(store.state).assertEqual(LoadState.Ready);
        expect(store.partialErrorMessage.length > 0).assertTrue();
        expect(store.failedSourceCount()).assertEqual(1);
      });
    });

    it('reports_error_when_every_active_source_fails', 0, () => {
      const data = new FakeTodoWorkbenchRepository();
      const failure = new ApiError(ApiErrorKind.ServerError, 500, 0, 'server',
        '', '/user/issues');
      data.assignedIssueResults.push(failure);
      data.createdIssueResults.push(failure);
      data.repositoryIssueResults.push(failure);

      const store = new TodoWorklistStore(data, TodoListKind.Issues);
      store.initialize('account-a', 'me', [repo('me', 'owned')]);
      return store.loadIfNeeded().then(() => {
        expect(store.items.length).assertEqual(0);
        expect(store.state).assertEqual(LoadState.Error);
        expect(store.errorMessage.length > 0).assertTrue();
      });
    });

    it('loads_more_without_duplicating_items', 0, () => {
      const data = new FakeTodoWorkbenchRepository();
      data.assignedIssueResults.push(page([
        item(RepositoryItemKind.Issue, 1, TodoRelation.Assigned)
      ], new OffsetPageRequest(), true));
      data.assignedIssueResults.push(page([
        item(RepositoryItemKind.Issue, 1, TodoRelation.Assigned),
        item(RepositoryItemKind.Issue, 2, TodoRelation.Assigned, 'other',
          '2026-11-24T09:00:00Z')
      ], new OffsetPageRequest(2, 10)));
      data.createdIssueResults.push(page([], new OffsetPageRequest()));

      const store = new TodoWorklistStore(data, TodoListKind.Issues);
      store.initialize('account-a', 'me', []);
      return store.loadIfNeeded()
        .then(() => store.loadMore())
        .then(() => {
          expect(store.items.length).assertEqual(2);
          expect(store.items[0].ref.number).assertEqual(2);
          expect(store.hasMore).assertFalse();
        });
    });

    it('coalesces_refresh_for_the_current_account', 0, () => {
      const data = new FakeTodoWorkbenchRepository();
      data.assignedIssueResults.push(page([
        item(RepositoryItemKind.Issue, 1, TodoRelation.Assigned)
      ], new OffsetPageRequest()));
      data.createdIssueResults.push(page([], new OffsetPageRequest()));
      data.assignedIssueResults.push(page([
        item(RepositoryItemKind.Issue, 2, TodoRelation.Assigned)
      ], new OffsetPageRequest()));
      data.createdIssueResults.push(page([], new OffsetPageRequest()));
      let now = 1000;
      const store = new TodoWorklistStore(data, TodoListKind.Issues, 2500, () => now);
      store.initialize('account-a', 'me', []);
      return store.loadIfNeeded()
        .then(() => store.refreshForAccount('account-a'))
        .then((refreshed: boolean) => {
          expect(refreshed).assertTrue();
          expect(store.items[0].ref.number).assertEqual(2);
          return store.refreshForAccount('account-a');
        })
        .then((refreshed: boolean) => {
          expect(refreshed).assertFalse();
          now += 3000;
          return store.refreshForAccount('account-b');
        })
        .then((refreshed: boolean) => {
          expect(refreshed).assertFalse();
        });
    });
  });
}
