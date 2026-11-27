import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { CancellationSignal } from '../main/ets/common/Cancellation';
import { CursorPageRequest, OffsetPageRequest, Page } from '../main/ets/common/Pager';
import { RepositoryItemKind } from '../main/ets/model/CollaborationEntities';
import { TodoListItem, TodoRelation } from '../main/ets/model/TodoWorkbench';
import { PullRequestTodoScope } from '../main/ets/repository/Ports';
import { TodoApiRepository } from '../main/ets/repository/TodoRepository';
import { FakeHttp } from './fakes/FakeHttp';

function issuePayload(number: number, repository: string = 'owner/repo'): string {
  return '{"number":"' + number.toString() + '","title":"Issue ' + number.toString()
    + '","state":"open","updated_at":"2026-11-24T08:00:00Z",'
    + '"user":{"login":"other-author"},"assignees":[{"login":"assigned-user"}],'
    + '"comments":2,"labels":[{"name":"bug"}],'
    + '"repository":{"full_name":"' + repository + '"}}';
}

function pullRequestPayload(number: number, repository: string = 'owner/repo'): string {
  return '{"number":' + number.toString() + ',"title":"Pull request ' + number.toString()
    + '","state":"open","updated_at":"2026-11-24T09:00:00Z",'
    + '"user":{"login":"other-author"},"assignees":[{"login":"assigned-user"}],'
    + '"testers":[{"login":"tester"}],"draft":true,"notes":4,'
    + '"approval_reviewers":[{"login":"reviewer","accept_status":"accept"}],'
    + '"repository":{"full_name":"' + repository + '"}}';
}

function pageUrl(http: FakeHttp, index: number): string {
  return http.requestedUrls[index];
}

class CanceledSignal implements CancellationSignal {
  isCanceled(): boolean {
    return true;
  }

  cancel(): void {
  }

  wait(): Promise<void> {
    return Promise.resolve();
  }
}

export default function todoRepositoryTest() {
  describe('TodoRepository', () => {
    it('maps_user_issue_scopes_and_metadata', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/issues', '[' + issuePayload(1) + ']');
      const repo = new TodoApiRepository(http);
      return repo.assignedIssueItems(new OffsetPageRequest(2, 10))
        .then((page: Page<TodoListItem>) => {
          const item = page.items[0];
          expect(item.kind).assertEqual(RepositoryItemKind.Issue);
          expect(item.author).assertEqual('other-author');
          expect(item.assignees[0]).assertEqual('assigned-user');
          expect(item.comments).assertEqual(2);
          expect(item.labels[0]).assertEqual('bug');
          expect(item.relations[0]).assertEqual(TodoRelation.Assigned);
          expect(pageUrl(http, 0).indexOf('filter=assigned') >= 0).assertTrue();
          expect(pageUrl(http, 0).indexOf('page=2') >= 0).assertTrue();
          expect(pageUrl(http, 0).indexOf('per_page=10') >= 0).assertTrue();
          return repo.createdIssueItems(new OffsetPageRequest(1, 20));
        })
        .then(() => {
          expect(pageUrl(http, 1).indexOf('filter=created') >= 0).assertTrue();
        });
    });

    it('maps_all_pull_request_scopes_and_list_metadata', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/pulls', '[' + pullRequestPayload(2) + ']');
      const repo = new TodoApiRepository(http);
      return repo.pullRequestItems(PullRequestTodoScope.NeedsReview, new OffsetPageRequest())
        .then((page: Page<TodoListItem>) => {
          const item = page.items[0];
          expect(item.kind).assertEqual(RepositoryItemKind.PullRequest);
          expect(item.author).assertEqual('other-author');
          expect(item.assignees[0]).assertEqual('assigned-user');
          expect(item.reviewers[0]).assertEqual('reviewer');
          expect(item.comments).assertEqual(4);
          expect(item.draft).assertTrue();
          expect(item.reviewState).assertEqual('Approved');
          expect(item.relations[0]).assertEqual(TodoRelation.ReviewRequested);
          expect(pageUrl(http, 0).indexOf('scope=need_my_review') >= 0).assertTrue();
          return repo.pullRequestItems(PullRequestTodoScope.NeedsApproval,
            new OffsetPageRequest());
        })
        .then(() => {
          expect(pageUrl(http, 1).indexOf('scope=need_my_approve') >= 0).assertTrue();
          return repo.pullRequestItems(PullRequestTodoScope.AssignedToMe,
            new OffsetPageRequest());
        })
        .then(() => {
          expect(pageUrl(http, 2).indexOf('scope=assigned_to_me') >= 0).assertTrue();
          return repo.pullRequestItems(PullRequestTodoScope.CreatedByMe,
            new OffsetPageRequest());
        })
        .then(() => {
          expect(pageUrl(http, 3).indexOf('scope=created_by_me') >= 0).assertTrue();
        });
    });

    it('maps_repository_issue_and_pull_request_queries', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/repos/me/owned/issues',
        '[' + issuePayload(3, 'me/owned') + ']');
      http.onJson('/api/v5/repos/me/owned/pulls',
        '[' + pullRequestPayload(4, 'me/owned') + ']');
      const repo = new TodoApiRepository(http);
      return repo.repositoryIssueItems('me', 'owned', new OffsetPageRequest())
        .then((page: Page<TodoListItem>) => {
          expect(page.items[0].relations[0]).assertEqual(TodoRelation.OwnedProject);
          expect(pageUrl(http, 0).indexOf('/api/v5/repos/me/owned/issues?') >= 0).assertTrue();
          expect(pageUrl(http, 0).indexOf('state=open') >= 0).assertTrue();
          expect(pageUrl(http, 0).indexOf('sort=updated') >= 0).assertTrue();
          return repo.repositoryPullRequestItems('me', 'owned', new OffsetPageRequest());
        })
        .then((page: Page<TodoListItem>) => {
          expect(page.items[0].relations[0]).assertEqual(TodoRelation.OwnedProject);
          expect(pageUrl(http, 1).indexOf('/api/v5/repos/me/owned/pulls?') >= 0).assertTrue();
          expect(pageUrl(http, 1).indexOf('state=open') >= 0).assertTrue();
        });
    });

    it('uses_short_pages_as_terminal_and_full_pages_as_continuable', 0, () => {
      const shortHttp = new FakeHttp();
      shortHttp.onJson('/api/v5/user/issues', '[' + issuePayload(1) + ']');
      const shortRepo = new TodoApiRepository(shortHttp);
      return shortRepo.assignedIssueItems(new OffsetPageRequest(1, 2))
        .then((shortPage: Page<TodoListItem>) => {
          expect(shortPage.hasMore).assertFalse();
          const fullHttp = new FakeHttp();
          fullHttp.onJson('/api/v5/user/issues',
            '[' + issuePayload(1) + ',' + issuePayload(2) + ']');
          const fullRepo = new TodoApiRepository(fullHttp);
          return fullRepo.assignedIssueItems(new OffsetPageRequest(1, 2));
        })
        .then((fullPage: Page<TodoListItem>) => {
          expect(fullPage.hasMore).assertTrue();
          expect(fullPage.nextRequest instanceof OffsetPageRequest).assertTrue();
          expect((fullPage.nextRequest as OffsetPageRequest).page).assertEqual(2);
        });
    });

    it('rejects_malformed_payloads_and_preserves_api_errors', 0, () => {
      const malformed = new FakeHttp();
      malformed.onJson('/api/v5/user/issues', '[{"number":"4","title":"Orphan"}]');
      const malformedRepo = new TodoApiRepository(malformed);
      return malformedRepo.assignedIssueItems(new OffsetPageRequest()).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect(error instanceof ApiError).assertTrue();
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Parse);
        const forbidden = new FakeHttp();
        forbidden.onError('/api/v5/user/pulls',
          new ApiError(ApiErrorKind.Forbidden, 403, 403, 'forbidden', 'trace', '/user/pulls'));
        const forbiddenRepo = new TodoApiRepository(forbidden);
        return forbiddenRepo.pullRequestItems(PullRequestTodoScope.AssignedToMe,
          new OffsetPageRequest());
      }).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Forbidden);
      });
    });

    it('rejects_cursor_paging_and_honors_cancellation', 0, () => {
      const http = new FakeHttp();
      const repo = new TodoApiRepository(http);
      return repo.assignedIssueItems(new CursorPageRequest('next')).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Parse);
        return repo.assignedIssueItems(new OffsetPageRequest(), new CanceledSignal());
      }).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Canceled);
        expect(http.requestedUrls.length).assertEqual(0);
      });
    });
  });
}
