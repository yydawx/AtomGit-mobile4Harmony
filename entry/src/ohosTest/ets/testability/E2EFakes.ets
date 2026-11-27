import { OffsetPageRequest, Page, PageRequest } from '../../../main/ets/common/Pager';
import {
  ActivityItem,
  RepositoryItemKind,
  RepositoryItemRef
} from '../../../main/ets/model/CollaborationEntities';
import {
  CurrentUser,
  NamespaceItem,
  OrgSummary,
  RepoSummary
} from '../../../main/ets/model/Entities';
import {
  ActivityRepository,
  PullRequestTodoScope,
  SessionReadRepository,
  TodoWorkbenchRepository
} from '../../../main/ets/repository/Ports';
import { TodoListItem, TodoRelation } from '../../../main/ets/model/TodoWorkbench';
import { CredentialStore } from '../../../main/ets/security/CredentialStore';
import { CacheCleaner, SettingsCleaner } from '../../../main/ets/storage/StoragePorts';

export const E2E_TOKEN: string = 'E2E-TEST-TOKEN';
export const E2E_PERSONAL_TITLE: string = 'E2E personal activity';
export const E2E_PROJECT_TITLE: string = 'E2E project activity';
export const E2E_TODO_ISSUE_TITLE: string = 'E2E assigned issue';
export const E2E_TODO_OWNED_ISSUE_TITLE: string = 'E2E owned project issue';
export const E2E_TODO_PULL_TITLE: string = 'E2E assigned pull request';
export const E2E_TODO_OWNED_PULL_TITLE: string = 'E2E owned project pull request';

export class E2ESessionRepository implements SessionReadRepository {
  async currentUser(): Promise<CurrentUser> {
    return new CurrentUser('e2e-account', 'e2e-user', 'E2E User', '',
      'https://atomgit.com/e2e-user', '', '', '');
  }

  async myRepos(request: OffsetPageRequest): Promise<Page<RepoSummary>> {
    return new Page<RepoSummary>([e2eRepo(), e2eOwnedRepo()], request);
  }

  async myNamespaces(): Promise<NamespaceItem[]> {
    return [];
  }

  async orgsOf(username: string): Promise<OrgSummary[]> {
    return [];
  }
}

export class E2EActivityRepository implements ActivityRepository {
  async personalActivity(username: string, year: number,
    request: PageRequest): Promise<Page<ActivityItem>> {
    return new Page<ActivityItem>([e2eItem(E2E_PERSONAL_TITLE)], request);
  }

  async repositoryActivity(owner: string, repo: string,
    request: PageRequest): Promise<Page<ActivityItem>> {
    return new Page<ActivityItem>([e2eItem(E2E_PROJECT_TITLE)], request);
  }
}


export class E2ETodoWorkbenchRepository implements TodoWorkbenchRepository {
  async assignedIssueItems(request: PageRequest): Promise<Page<TodoListItem>> {
    return new Page<TodoListItem>([e2eTodoItem(RepositoryItemKind.Issue, 1,
      E2E_TODO_ISSUE_TITLE, TodoRelation.Assigned, 'e2e-owner', 'e2e-repo',
      'e2e-owner')], request);
  }

  async createdIssueItems(request: PageRequest): Promise<Page<TodoListItem>> {
    return Page.empty<TodoListItem>(request);
  }

  async pullRequestItems(scope: PullRequestTodoScope,
    request: PageRequest): Promise<Page<TodoListItem>> {
    if (scope === PullRequestTodoScope.AssignedToMe) {
      return new Page<TodoListItem>([e2eTodoItem(RepositoryItemKind.PullRequest, 2,
        E2E_TODO_PULL_TITLE, TodoRelation.Assigned, 'e2e-owner', 'e2e-repo',
        'e2e-owner')], request);
    }
    return Page.empty<TodoListItem>(request);
  }

  async repositoryIssueItems(owner: string, repo: string,
    request: PageRequest): Promise<Page<TodoListItem>> {
    if (owner !== 'e2e-user' || repo !== 'todo-repo') {
      return Page.empty<TodoListItem>(request);
    }
    return new Page<TodoListItem>([e2eTodoItem(RepositoryItemKind.Issue, 3,
      E2E_TODO_OWNED_ISSUE_TITLE, TodoRelation.OwnedProject, owner, repo,
      'other-author')], request);
  }

  async repositoryPullRequestItems(owner: string, repo: string,
    request: PageRequest): Promise<Page<TodoListItem>> {
    if (owner !== 'e2e-user' || repo !== 'todo-repo') {
      return Page.empty<TodoListItem>(request);
    }
    return new Page<TodoListItem>([e2eTodoItem(RepositoryItemKind.PullRequest, 4,
      E2E_TODO_OWNED_PULL_TITLE, TodoRelation.OwnedProject, owner, repo,
      'other-author')], request);
  }
}

export class E2ECredentialStore implements CredentialStore {
  private value: string | undefined = undefined;

  async save(token: string): Promise<void> {
    this.value = token;
  }

  async load(): Promise<string | undefined> {
    return this.value;
  }

  async remove(): Promise<void> {
    this.value = undefined;
  }
}

export class E2ECacheCleaner implements CacheCleaner {
  async clearCurrentAccount(): Promise<void> {
  }
}

export class E2ESettingsCleaner implements SettingsCleaner {
  async clear(): Promise<void> {
  }
}

export function e2eRepo(): RepoSummary {
  return new RepoSummary(1, 'e2e-owner', 'e2e-repo', 'e2e-repo',
    'e2e-owner/e2e-repo', 'E2E repository',
    'https://atomgit.com/e2e-owner/e2e-repo', 'main', false, false, 0, 0, 0);
}

export function e2eOwnedRepo(): RepoSummary {
  return new RepoSummary(2, 'e2e-user', 'todo-repo', 'todo-repo',
    'e2e-user/todo-repo', 'E2E owned repository',
    'https://atomgit.com/e2e-user/todo-repo', 'main', false, false, 0, 0, 0);
}

function e2eTodoItem(kind: RepositoryItemKind, number: number, title: string,
  relation: TodoRelation, owner: string, repo: string, author: string): TodoListItem {
  return new TodoListItem(kind, new RepositoryItemRef(owner, repo, number), title,
    'open', new Date().toISOString(), [relation], author);
}

function e2eItem(title: string): ActivityItem {
  return new ActivityItem('e2e-' + title, 'issue', title, 'e2e-user',
    'e2e-owner/e2e-repo', new Date().toISOString(),
    new RepositoryItemRef('e2e-owner', 'e2e-repo', 1),
    RepositoryItemKind.Issue, '', 'opened');
}
