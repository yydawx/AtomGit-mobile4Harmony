import { RepositoryItemRef } from '../model/CollaborationEntities';
import { TodoListKind } from '../model/TodoWorkbench';

export enum AppRouteName {
  IssueDetail = 'issueDetail',
  PullRequestDetail = 'pullRequestDetail',
  RepositoryDetail = 'repoDetail',
  TodoIssues = 'todoIssues',
  TodoPullRequests = 'todoPullRequests'
}

export class RepositoryDetailParams {
  readonly owner: string;
  readonly repo: string;
  constructor(owner: string, repo: string) { this.owner = owner; this.repo = repo; }
}

export class IssueDetailParams {
  readonly ref: RepositoryItemRef;
  constructor(ref: RepositoryItemRef) { this.ref = ref; }
}

export class PullRequestDetailParams {
  readonly ref: RepositoryItemRef;
  constructor(ref: RepositoryItemRef) { this.ref = ref; }
}

export class TodoListParams {
  readonly kind: TodoListKind;
  constructor(kind: TodoListKind) { this.kind = kind; }
}

export type AppRouteParams =
  RepositoryDetailParams | IssueDetailParams | PullRequestDetailParams | TodoListParams;

/** NavPathStack still receives a name and object; this helper centralizes route spelling. */
export class AppRoute {
  readonly name: AppRouteName;
  readonly params: AppRouteParams;
  private constructor(name: AppRouteName, params: AppRouteParams) {
    this.name = name;
    this.params = params;
  }

  static issue(ref: RepositoryItemRef): AppRoute {
    return new AppRoute(AppRouteName.IssueDetail, new IssueDetailParams(ref));
  }

  static pullRequest(ref: RepositoryItemRef): AppRoute {
    return new AppRoute(AppRouteName.PullRequestDetail, new PullRequestDetailParams(ref));
  }

  static repository(owner: string, repo: string): AppRoute {
    return new AppRoute(AppRouteName.RepositoryDetail, new RepositoryDetailParams(owner, repo));
  }

  static todoIssues(): AppRoute {
    return new AppRoute(AppRouteName.TodoIssues, new TodoListParams(TodoListKind.Issues));
  }

  static todoPullRequests(): AppRoute {
    return new AppRoute(AppRouteName.TodoPullRequests,
      new TodoListParams(TodoListKind.PullRequests));
  }
}
