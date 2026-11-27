import { RepositoryItemKind, RepositoryItemRef } from './CollaborationEntities';

export enum TodoListKind {
  Issues = 'issues',
  PullRequests = 'pull_requests'
}

/** Why an item belongs in the Todo workbench. */
export enum TodoRelation {
  Assigned = 'assigned',
  ReviewRequested = 'review_requested',
  ApprovalRequested = 'approval_requested',
  OwnedProject = 'owned_project',
  CreatedByMe = 'created_by_me'
}

/** User-visible projection over a kind's relation set. */
export enum TodoFilter {
  All = 'all',
  Assigned = 'assigned',
  WaitingForYou = 'waiting_for_you',
  CreatedByMe = 'created_by_me',
  OwnedProjects = 'owned_projects'
}

export class TodoFilterOption {
  readonly value: TodoFilter;
  readonly label: string;

  constructor(value: TodoFilter, label: string) {
    this.value = value;
    this.label = label;
  }
}

/**
 * App-facing row model for the Issue and Pull Request worklists. Relation is
 * deliberately separate from state so one item can explain every reason it is
 * present without being repeated in the list.
 */
export class TodoListItem {
  readonly kind: RepositoryItemKind;
  readonly ref: RepositoryItemRef;
  readonly title: string;
  readonly state: string;
  readonly updatedAt: string;
  readonly relations: TodoRelation[];
  readonly author: string;
  readonly assignees: string[];
  readonly reviewers: string[];
  readonly comments: number;
  readonly labels: string[];
  readonly reviewState: string;
  readonly draft: boolean;
  readonly htmlUrl: string;

  constructor(kind: RepositoryItemKind, ref: RepositoryItemRef, title: string,
    state: string, updatedAt: string, relations: TodoRelation[] = [], author: string = '',
    assignees: string[] = [], reviewers: string[] = [], comments: number = 0,
    labels: string[] = [], reviewState: string = '', draft: boolean = false,
    htmlUrl: string = '') {
    this.kind = kind;
    this.ref = ref;
    this.title = title;
    this.state = state;
    this.updatedAt = updatedAt;
    this.relations = relations.slice();
    this.author = author;
    this.assignees = assignees.slice();
    this.reviewers = reviewers.slice();
    this.comments = comments;
    this.labels = labels.slice();
    this.reviewState = reviewState;
    this.draft = draft;
    this.htmlUrl = htmlUrl;
  }

  key(): string {
    return this.kind + '|' + this.ref.key();
  }
}

export function emptyTodoListItem(): TodoListItem {
  return new TodoListItem(RepositoryItemKind.Issue, new RepositoryItemRef('', '', 0), '', '', '');
}

export function todoListTitle(kind: TodoListKind): string {
  return kind === TodoListKind.Issues ? 'Issues' : 'Pull Requests';
}

export function todoFilterOptions(kind: TodoListKind): TodoFilterOption[] {
  const options: TodoFilterOption[] = [
    new TodoFilterOption(TodoFilter.All, '全部'),
    new TodoFilterOption(TodoFilter.Assigned, '交给你')
  ];
  if (kind === TodoListKind.PullRequests) {
    options.push(new TodoFilterOption(TodoFilter.WaitingForYou, '等你确认'));
  }
  options.push(new TodoFilterOption(TodoFilter.CreatedByMe, '你发起的'));
  options.push(new TodoFilterOption(TodoFilter.OwnedProjects, '你的项目'));
  return options;
}

export function todoFilterLabel(filter: TodoFilter): string {
  switch (filter) {
    case TodoFilter.Assigned:
      return '交给你';
    case TodoFilter.WaitingForYou:
      return '等你确认';
    case TodoFilter.CreatedByMe:
      return '你发起的';
    case TodoFilter.OwnedProjects:
      return '你的项目';
    default:
      return '全部';
  }
}

export function todoRelationLabel(relation: TodoRelation): string {
  switch (relation) {
    case TodoRelation.Assigned:
      return '交给你';
    case TodoRelation.ReviewRequested:
      return '待评审';
    case TodoRelation.ApprovalRequested:
      return '待审批';
    case TodoRelation.OwnedProject:
      return '项目动态';
    default:
      return '你发起的';
  }
}

export function todoRelationSummary(item: TodoListItem): string {
  const ordered: TodoRelation[] = sortRelations(item.relations);
  const labels: string[] = [];
  for (let index = 0; index < ordered.length && index < 2; index++) {
    labels.push(todoRelationLabel(ordered[index]));
  }
  return labels.join(' · ');
}

export function todoStatusSummary(item: TodoListItem, now: Date = new Date()): string {
  const parts: string[] = [];
  if (item.relations.length > 0) {
    parts.push(todoRelationSummary(item));
  }
  if (item.draft) {
    parts.push('草稿');
  } else if (item.reviewState.length > 0) {
    parts.push(item.reviewState);
  } else if (item.state.length > 0) {
    parts.push(item.state);
  }
  if (item.comments > 0) {
    parts.push(item.comments.toString() + ' 条评论');
  }
  const relative = relativeTodoTime(item.updatedAt, now);
  if (relative.length > 0) {
    parts.push(relative);
  }
  return parts.join(' · ');
}

export function relativeTodoTime(value: string, now: Date = new Date()): string {
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    return '';
  }
  const difference = Math.max(0, now.getTime() - timestamp);
  const minute = 60 * 1000;
  const hour = 60 * minute;
  const day = 24 * hour;
  if (difference < minute) {
    return '刚刚';
  }
  if (difference < hour) {
    return Math.floor(difference / minute).toString() + ' 分钟前';
  }
  if (difference < day) {
    return Math.floor(difference / hour).toString() + ' 小时前';
  }
  if (difference < 7 * day) {
    return Math.floor(difference / day).toString() + ' 天前';
  }
  const date = new Date(timestamp);
  if (date.getFullYear() === now.getFullYear()) {
    return (date.getMonth() + 1).toString() + ' 月 ' + date.getDate().toString() + ' 日';
  }
  return date.getFullYear().toString() + ' 年 ' + (date.getMonth() + 1).toString()
    + ' 月 ' + date.getDate().toString() + ' 日';
}

/** Merge independently paged sources, combine reasons, then return a stable order. */
export function mergeTodoItems(previous: TodoListItem[], incoming: TodoListItem[]): TodoListItem[] {
  const byKey: Map<string, TodoListItem> = new Map<string, TodoListItem>();
  for (const item of previous) {
    byKey.set(item.key(), item);
  }
  for (const item of incoming) {
    const existing = byKey.get(item.key());
    byKey.set(item.key(), existing === undefined ? item : mergeTodoItem(existing, item));
  }
  const merged: TodoListItem[] = [];
  byKey.forEach((item: TodoListItem) => {
    merged.push(item);
  });
  return sortTodoItems(merged);
}

export function projectTodoItems(items: TodoListItem[], filter: TodoFilter): TodoListItem[] {
  const projected: TodoListItem[] = [];
  for (const item of items) {
    if (matchesFilter(item, filter)) {
      projected.push(item);
    }
  }
  return sortTodoItems(projected);
}

export function sortTodoItems(items: TodoListItem[]): TodoListItem[] {
  const sorted = items.slice();
  sorted.sort((left: TodoListItem, right: TodoListItem) => {
    const relationDifference = itemPriority(left) - itemPriority(right);
    if (relationDifference !== 0) {
      return relationDifference;
    }
    const timeDifference = timestamp(right.updatedAt) - timestamp(left.updatedAt);
    return timeDifference === 0 ? left.key().localeCompare(right.key()) : timeDifference;
  });
  return sorted;
}

export function relationPriority(relation: TodoRelation): number {
  switch (relation) {
    case TodoRelation.Assigned:
      return 0;
    case TodoRelation.ReviewRequested:
      return 1;
    case TodoRelation.ApprovalRequested:
      return 1;
    case TodoRelation.OwnedProject:
      return 2;
    default:
      return 3;
  }
}

function itemPriority(item: TodoListItem): number {
  let priority = 4;
  for (const relation of item.relations) {
    priority = Math.min(priority, relationPriority(relation));
  }
  return priority;
}

function matchesFilter(item: TodoListItem, filter: TodoFilter): boolean {
  if (filter === TodoFilter.All) {
    return true;
  }
  if (filter === TodoFilter.Assigned) {
    return hasRelation(item, TodoRelation.Assigned);
  }
  if (filter === TodoFilter.WaitingForYou) {
    return hasRelation(item, TodoRelation.ReviewRequested)
      || hasRelation(item, TodoRelation.ApprovalRequested);
  }
  if (filter === TodoFilter.CreatedByMe) {
    return hasRelation(item, TodoRelation.CreatedByMe);
  }
  return hasRelation(item, TodoRelation.OwnedProject);
}

function hasRelation(item: TodoListItem, relation: TodoRelation): boolean {
  return item.relations.indexOf(relation) >= 0;
}

function mergeTodoItem(previous: TodoListItem, incoming: TodoListItem): TodoListItem {
  const newer = timestamp(incoming.updatedAt) >= timestamp(previous.updatedAt) ? incoming : previous;
  const older = newer === incoming ? previous : incoming;
  return new TodoListItem(
    previous.kind,
    previous.ref,
    newer.title.length > 0 ? newer.title : older.title,
    newer.state.length > 0 ? newer.state : older.state,
    newer.updatedAt.length > 0 ? newer.updatedAt : older.updatedAt,
    mergeRelations(previous.relations, incoming.relations),
    newer.author.length > 0 ? newer.author : older.author,
    mergeStrings(previous.assignees, incoming.assignees),
    mergeStrings(previous.reviewers, incoming.reviewers),
    Math.max(previous.comments, incoming.comments),
    mergeStrings(previous.labels, incoming.labels),
    newer.reviewState.length > 0 ? newer.reviewState : older.reviewState,
    previous.draft || incoming.draft,
    newer.htmlUrl.length > 0 ? newer.htmlUrl : older.htmlUrl
  );
}

function mergeRelations(left: TodoRelation[], right: TodoRelation[]): TodoRelation[] {
  const seen: Set<TodoRelation> = new Set<TodoRelation>();
  for (const relation of left.concat(right)) {
    seen.add(relation);
  }
  const merged: TodoRelation[] = [];
  seen.forEach((relation: TodoRelation) => {
    merged.push(relation);
  });
  return sortRelations(merged);
}

function sortRelations(relations: TodoRelation[]): TodoRelation[] {
  const sorted = relations.slice();
  sorted.sort((left: TodoRelation, right: TodoRelation) => {
    return relationPriority(left) - relationPriority(right);
  });
  return sorted;
}

function mergeStrings(left: string[], right: string[]): string[] {
  const seen: Set<string> = new Set<string>();
  const merged: string[] = [];
  for (const value of left.concat(right)) {
    const trimmed = value.trim();
    if (trimmed.length > 0 && !seen.has(trimmed)) {
      seen.add(trimmed);
      merged.push(trimmed);
    }
  }
  return merged;
}

function timestamp(value: string): number {
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}
