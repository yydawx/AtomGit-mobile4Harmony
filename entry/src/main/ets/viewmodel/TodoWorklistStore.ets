import { ApiError, ApiErrorKind } from '../common/ApiError';
import { CancellationSignal } from '../common/Cancellation';
import { OffsetPageRequest, Page, PageRequest } from '../common/Pager';
import { CancelToken } from '../network/HttpClient';
import { RepoSummary } from '../model/Entities';
import {
  mergeTodoItems,
  projectTodoItems,
  TodoFilter,
  TodoListItem,
  TodoListKind,
  TodoRelation,
  todoFilterLabel
} from '../model/TodoWorkbench';
import { PullRequestTodoScope, TodoWorkbenchRepository } from '../repository/Ports';
import { LoadState } from './SessionStore';

const TODOLIST_PAGE_SIZE: number = 10;
const TODOLIST_CONCURRENCY: number = 2;

enum TodoSourceType {
  AssignedIssues = 'assigned_issues',
  CreatedIssues = 'created_issues',
  AssignedPullRequests = 'assigned_pull_requests',
  ReviewPullRequests = 'review_pull_requests',
  ApprovalPullRequests = 'approval_pull_requests',
  CreatedPullRequests = 'created_pull_requests',
  RepositoryIssues = 'repository_issues',
  RepositoryPullRequests = 'repository_pull_requests'
}

class TodoSourceState {
  readonly key: string;
  readonly type: TodoSourceType;
  readonly relation: TodoRelation;
  readonly owner: string;
  readonly repo: string;

  request: OffsetPageRequest = new OffsetPageRequest(1, TODOLIST_PAGE_SIZE);
  items: TodoListItem[] = [];
  hasMore: boolean = true;
  loaded: boolean = false;
  pending: boolean = false;
  errorMessage: string = '';
  cancelToken: CancelToken | undefined = undefined;

  constructor(key: string, type: TodoSourceType, relation: TodoRelation,
    owner: string = '', repo: string = '') {
    this.key = key;
    this.type = type;
    this.relation = relation;
    this.owner = owner;
    this.repo = repo;
  }

  cancel(): void {
    if (this.cancelToken !== undefined) {
      this.cancelToken.cancel();
      this.cancelToken = undefined;
    }
  }
}

class EmptyTodoWorkbenchRepository implements TodoWorkbenchRepository {
  async assignedIssueItems(request: PageRequest): Promise<Page<TodoListItem>> {
    return Page.empty<TodoListItem>(request);
  }

  async createdIssueItems(request: PageRequest): Promise<Page<TodoListItem>> {
    return Page.empty<TodoListItem>(request);
  }

  async pullRequestItems(_scope: PullRequestTodoScope,
    request: PageRequest): Promise<Page<TodoListItem>> {
    return Page.empty<TodoListItem>(request);
  }

  async repositoryIssueItems(_owner: string, _repo: string,
    request: PageRequest): Promise<Page<TodoListItem>> {
    return Page.empty<TodoListItem>(request);
  }

  async repositoryPullRequestItems(_owner: string, _repo: string,
    request: PageRequest): Promise<Page<TodoListItem>> {
    return Page.empty<TodoListItem>(request);
  }
}

function errorText(error: Object): string {
  if (!(error instanceof ApiError)) {
    return 'The Todo list could not be loaded. Try again.';
  }
  switch (error.kind) {
    case ApiErrorKind.Unauthorized:
      return 'Your session has expired. Sign in again.';
    case ApiErrorKind.Forbidden:
      return 'You do not have permission to view this source.';
    case ApiErrorKind.NotFound:
      return 'This source is no longer available.';
    case ApiErrorKind.RateLimited:
      return 'Too many requests. Try again shortly.';
    case ApiErrorKind.ServerError:
      return 'AtomGit is temporarily unavailable.';
    case ApiErrorKind.Network:
      return 'The network connection is unavailable.';
    case ApiErrorKind.Parse:
      return 'The server returned data in an unexpected format.';
    default:
      return 'The Todo list could not be loaded. Try again.';
  }
}

@ObservedV2
export class TodoWorklistStore {
  readonly kind: TodoListKind;
  @Trace filter: TodoFilter = TodoFilter.All;
  @Trace items: TodoListItem[] = [];
  @Trace state: LoadState = LoadState.Idle;
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = false;
  @Trace errorMessage: string = '';
  @Trace partialErrorMessage: string = '';
  @Trace lastUpdatedAt: string = '';
  @Trace ownedRepoCount: number = 0;

  private readonly dataSource: TodoWorkbenchRepository;
  private readonly refreshCoalesceMs: number;
  private readonly now: () => number;
  private accountKey: string = '';
  private login: string = '';
  private repoSignature: string = '';
  private sources: TodoSourceState[] = [];
  private generation: number = 0;
  private refreshInFlight: Promise<boolean> | undefined = undefined;
  private lastRefreshAt: number = -1;
  private loadedOnce: boolean = false;

  constructor(dataSource: TodoWorkbenchRepository, kind: TodoListKind,
    refreshCoalesceMs: number = 2500, now: () => number = () => Date.now()) {
    this.dataSource = dataSource;
    this.kind = kind;
    this.refreshCoalesceMs = refreshCoalesceMs;
    this.now = now;
  }

  initialize(accountId: string, login: string, repos: RepoSummary[]): void {
    const nextAccount = accountId.trim();
    const nextLogin = login.trim();
    const ownedRepos = this.ownedRepositories(repos, nextLogin);
    const nextRepoSignature = this.repositorySignature(ownedRepos);
    if (nextAccount === this.accountKey && nextLogin === this.login
      && nextRepoSignature === this.repoSignature) {
      return;
    }
    this.cancelPending();
    this.accountKey = nextAccount;
    this.login = nextLogin;
    this.repoSignature = nextRepoSignature;
    this.filter = TodoFilter.All;
    this.items = [];
    this.state = LoadState.Idle;
    this.refreshing = false;
    this.loadingMore = false;
    this.hasMore = false;
    this.errorMessage = '';
    this.partialErrorMessage = '';
    this.lastUpdatedAt = '';
    this.loadedOnce = false;
    this.refreshInFlight = undefined;
    this.lastRefreshAt = -1;
    this.sources = this.createSources(ownedRepos);
    this.ownedRepoCount = ownedRepos.length;
  }

  async loadIfNeeded(): Promise<void> {
    if (this.loadedOnce || this.accountKey.length === 0) {
      return;
    }
    const active = this.activeSources();
    if (active.length === 0) {
      this.state = LoadState.Ready;
      this.loadedOnce = true;
      return;
    }
    this.state = LoadState.Loading;
    await this.loadSources(active, true);
    this.loadedOnce = this.hasSettled();
  }

  async selectFilter(filter: TodoFilter): Promise<void> {
    if (this.filter === filter) {
      return;
    }
    this.filter = filter;
    this.commitProjection();
    const missing = this.activeSources().filter((source: TodoSourceState) => !source.loaded);
    if (missing.length > 0 && !this.refreshing) {
      this.state = this.items.length > 0 ? LoadState.Ready : LoadState.Loading;
      await this.loadSources(missing, true);
      this.loadedOnce = this.hasSettled();
    }
  }

  async refresh(): Promise<void> {
    if (this.accountKey.length === 0) {
      return;
    }
    this.refreshing = true;
    this.errorMessage = '';
    this.partialErrorMessage = '';
    await this.loadSources(this.sources, true);
    this.refreshing = false;
    this.loadedOnce = true;
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || this.refreshing) {
      return;
    }
    const nextSources = this.activeSources().filter((source: TodoSourceState) => {
      return source.loaded && source.hasMore && !source.pending;
    });
    if (nextSources.length === 0) {
      this.recomputeHasMore();
      return;
    }
    this.loadingMore = true;
    await this.loadSources(nextSources, false, true);
    this.loadingMore = false;
    this.recomputeHasMore();
  }

  cancelPending(): void {
    this.generation++;
    for (const source of this.sources) {
      source.cancel();
      source.pending = false;
    }
    if (this.state === LoadState.Loading) {
      this.state = LoadState.Idle;
    }
    this.refreshing = false;
    this.loadingMore = false;
  }

  refreshForAccount(accountId: string): Promise<boolean> {
    const eventAccount = accountId.trim();
    if (eventAccount.length === 0 || this.accountKey.length === 0
      || eventAccount !== this.accountKey) {
      return Promise.resolve(false);
    }
    if (this.refreshInFlight !== undefined) {
      return this.refreshInFlight;
    }
    const current = this.now();
    if (this.lastRefreshAt >= 0 && current - this.lastRefreshAt < this.refreshCoalesceMs) {
      return Promise.resolve(false);
    }
    let task: Promise<boolean>;
    task = this.refresh().then(() => {
      this.lastRefreshAt = this.now();
      return true;
    }).finally(() => {
      if (this.refreshInFlight === task) {
        this.refreshInFlight = undefined;
      }
    });
    this.refreshInFlight = task;
    return task;
  }

  filterLabel(): string {
    return todoFilterLabel(this.filter);
  }

  private hasSettled(): boolean {
    return this.state !== LoadState.Idle;
  }

  failedSourceCount(): number {
    let count = 0;
    for (const source of this.activeSources()) {
      if (source.errorMessage.length > 0) {
        count++;
      }
    }
    return count;
  }

  private createSources(ownedRepos: RepoSummary[]): TodoSourceState[] {
    const sources: TodoSourceState[] = [];
    if (this.kind === TodoListKind.Issues) {
      sources.push(new TodoSourceState('assigned_issues', TodoSourceType.AssignedIssues,
        TodoRelation.Assigned));
      sources.push(new TodoSourceState('created_issues', TodoSourceType.CreatedIssues,
        TodoRelation.CreatedByMe));
      for (const repo of ownedRepos) {
        sources.push(new TodoSourceState('repo_issues:' + repo.fullName,
          TodoSourceType.RepositoryIssues, TodoRelation.OwnedProject, repo.owner, repo.name));
      }
    } else {
      sources.push(new TodoSourceState('assigned_pull_requests',
        TodoSourceType.AssignedPullRequests, TodoRelation.Assigned));
      sources.push(new TodoSourceState('review_pull_requests',
        TodoSourceType.ReviewPullRequests, TodoRelation.ReviewRequested));
      sources.push(new TodoSourceState('approval_pull_requests',
        TodoSourceType.ApprovalPullRequests, TodoRelation.ApprovalRequested));
      sources.push(new TodoSourceState('created_pull_requests',
        TodoSourceType.CreatedPullRequests, TodoRelation.CreatedByMe));
      for (const repo of ownedRepos) {
        sources.push(new TodoSourceState('repo_pulls:' + repo.fullName,
          TodoSourceType.RepositoryPullRequests, TodoRelation.OwnedProject, repo.owner, repo.name));
      }
    }
    return sources;
  }

  private ownedRepositories(repos: RepoSummary[], login: string): RepoSummary[] {
    const normalizedLogin = login.toLowerCase();
    const seen: Set<string> = new Set<string>();
    const owned: RepoSummary[] = [];
    if (normalizedLogin.length === 0) {
      return owned;
    }
    for (const repo of repos) {
      if (repo.owner.trim().toLowerCase() !== normalizedLogin || seen.has(repo.fullName)) {
        continue;
      }
      seen.add(repo.fullName);
      owned.push(repo);
    }
    owned.sort((left: RepoSummary, right: RepoSummary) => {
      return left.fullName.localeCompare(right.fullName);
    });
    return owned;
  }

  private repositorySignature(repos: RepoSummary[]): string {
    const names: string[] = [];
    for (const repo of repos) {
      names.push(repo.fullName);
    }
    return names.join('|');
  }

  private activeSources(): TodoSourceState[] {
    const result: TodoSourceState[] = [];
    for (const source of this.sources) {
      if (this.sourceMatchesFilter(source, this.filter)) {
        result.push(source);
      }
    }
    return result;
  }

  private sourceMatchesFilter(source: TodoSourceState, filter: TodoFilter): boolean {
    if (filter === TodoFilter.All) {
      return true;
    }
    if (filter === TodoFilter.Assigned) {
      return source.relation === TodoRelation.Assigned;
    }
    if (filter === TodoFilter.WaitingForYou) {
      return source.relation === TodoRelation.ReviewRequested
        || source.relation === TodoRelation.ApprovalRequested;
    }
    if (filter === TodoFilter.CreatedByMe) {
      return source.relation === TodoRelation.CreatedByMe;
    }
    return source.relation === TodoRelation.OwnedProject;
  }

  private async loadSources(sources: TodoSourceState[], reset: boolean,
    onlyMore: boolean = false): Promise<void> {
    const generation = this.generation;
    for (let index = 0; index < sources.length; index += TODOLIST_CONCURRENCY) {
      const batch: Promise<void>[] = [];
      for (let offset = 0; offset < TODOLIST_CONCURRENCY
        && index + offset < sources.length; offset++) {
        batch.push(this.loadSource(sources[index + offset], reset, onlyMore, generation));
      }
      await Promise.all(batch);
      if (generation !== this.generation) {
        return;
      }
      this.commitProjection();
    }
    this.commitState();
  }

  private async loadSource(source: TodoSourceState, reset: boolean, onlyMore: boolean,
    generation: number): Promise<void> {
    if (source.pending || (onlyMore && (!source.loaded || !source.hasMore))) {
      return;
    }
    if (reset) {
      source.cancel();
      source.request = new OffsetPageRequest(1, TODOLIST_PAGE_SIZE);
      source.hasMore = true;
      source.loaded = false;
    } else if (!source.loaded || !source.hasMore) {
      return;
    }
    source.pending = true;
    source.errorMessage = '';
    const token = new CancelToken();
    source.cancelToken = token;
    try {
      const page = await this.requestSource(source, source.request, token);
      if (generation !== this.generation || token.isCanceled()) {
        return;
      }
      const incoming = page.items.filter((item: TodoListItem) => this.includeItem(source, item));
      source.items = reset ? mergeTodoItems([], incoming)
        : mergeTodoItems(source.items, incoming);
      source.hasMore = page.hasMore;
      source.request = page.nextRequest instanceof OffsetPageRequest
        ? page.nextRequest : new OffsetPageRequest(source.request.page, TODOLIST_PAGE_SIZE);
      source.loaded = true;
      source.errorMessage = '';
    } catch (error) {
      if (generation !== this.generation || token.isCanceled()) {
        return;
      }
      if (error instanceof ApiError && error.kind === ApiErrorKind.Canceled) {
        return;
      }
      source.errorMessage = errorText(error as Object);
    } finally {
      if (generation === this.generation) {
        source.pending = false;
        source.cancelToken = undefined;
      }
    }
  }

  private requestSource(source: TodoSourceState, request: PageRequest,
    cancel: CancellationSignal): Promise<Page<TodoListItem>> {
    switch (source.type) {
      case TodoSourceType.AssignedIssues:
        return this.dataSource.assignedIssueItems(request, cancel);
      case TodoSourceType.CreatedIssues:
        return this.dataSource.createdIssueItems(request, cancel);
      case TodoSourceType.AssignedPullRequests:
        return this.dataSource.pullRequestItems(PullRequestTodoScope.AssignedToMe, request, cancel);
      case TodoSourceType.ReviewPullRequests:
        return this.dataSource.pullRequestItems(PullRequestTodoScope.NeedsReview, request, cancel);
      case TodoSourceType.ApprovalPullRequests:
        return this.dataSource.pullRequestItems(PullRequestTodoScope.NeedsApproval, request, cancel);
      case TodoSourceType.CreatedPullRequests:
        return this.dataSource.pullRequestItems(PullRequestTodoScope.CreatedByMe, request, cancel);
      case TodoSourceType.RepositoryIssues:
        return this.dataSource.repositoryIssueItems(source.owner, source.repo, request, cancel);
      default:
        return this.dataSource.repositoryPullRequestItems(source.owner, source.repo,
          request, cancel);
    }
  }

  private includeItem(source: TodoSourceState, item: TodoListItem): boolean {
    if (source.relation !== TodoRelation.OwnedProject || this.login.length === 0) {
      return true;
    }
    if (item.author.trim().length === 0) {
      return true;
    }
    return item.author.trim().toLowerCase() !== this.login.toLowerCase();
  }

  private commitProjection(): void {
    const mergedItems: TodoListItem[] = [];
    for (const source of this.sources) {
      for (const item of source.items) {
        mergedItems.push(item);
      }
    }
    this.items = projectTodoItems(mergeTodoItems([], mergedItems), this.filter);
    this.recomputeHasMore();
  }

  private recomputeHasMore(): void {
    let more = false;
    for (const source of this.activeSources()) {
      if (source.hasMore) {
        more = true;
        break;
      }
    }
    this.hasMore = more;
  }

  private commitState(): void {
    this.commitProjection();
    const active = this.activeSources();
    let failures = 0;
    let firstError = '';
    for (const source of active) {
      if (source.errorMessage.length > 0) {
        failures++;
        if (firstError.length === 0) {
          firstError = source.errorMessage;
        }
      }
    }
    if (active.length === 0) {
      this.state = LoadState.Ready;
      this.errorMessage = '';
      this.partialErrorMessage = '';
      this.lastUpdatedAt = this.clock();
      return;
    }
    if (this.items.length === 0 && failures === active.length) {
      this.state = LoadState.Error;
      this.errorMessage = firstError;
      this.partialErrorMessage = '';
      return;
    }
    this.state = LoadState.Ready;
    this.errorMessage = '';
    this.partialErrorMessage = failures > 0 ? firstError : '';
    this.lastUpdatedAt = this.clock();
  }

  private clock(): string {
    const value = new Date();
    const hours = value.getHours() < 10 ? '0' + value.getHours().toString()
      : value.getHours().toString();
    const minutes = value.getMinutes() < 10 ? '0' + value.getMinutes().toString()
      : value.getMinutes().toString();
    return hours + ':' + minutes;
  }
}

export class EmptyTodoWorklistStore extends TodoWorklistStore {
  constructor(kind: TodoListKind) {
    super(new EmptyTodoWorkbenchRepository(), kind);
  }
}
