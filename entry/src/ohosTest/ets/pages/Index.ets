import { HdsNavigation } from '@kit.UIDesignKit';

import { ActivityPage } from '../../../main/ets/pages/activity/ActivityPage';
import { LoginPage } from '../../../main/ets/pages/login/LoginPage';
import { TodoPage } from '../../../main/ets/pages/todo/TodoPage';
import { TodoWorklistPage } from '../../../main/ets/pages/todo/TodoWorklistPage';
import { AppRouteName, TodoListParams } from '../../../main/ets/navigation/AppRoute';
import { RepositoryItemKind, RepositoryItemRef } from '../../../main/ets/model/CollaborationEntities';
import { TodoListItem, TodoListKind } from '../../../main/ets/model/TodoWorkbench';
import { AccountGuard } from '../../../main/ets/security/TokenEnvelope';
import { ActivityStore } from '../../../main/ets/viewmodel/ActivityStore';
import { SessionStore } from '../../../main/ets/viewmodel/SessionStore';
import { TodoWorklistStore } from '../../../main/ets/viewmodel/TodoWorklistStore';
import {
  E2EActivityRepository,
  E2ECacheCleaner,
  E2ECredentialStore,
  E2ESessionRepository,
  E2ESettingsCleaner,
  E2ETodoWorkbenchRepository
} from '../testability/E2EFakes';

@Entry
@ComponentV2
struct Index {
  @Local session: SessionStore = new SessionStore(
    new E2ESessionRepository(),
    new E2ECredentialStore(),
    new E2ECacheCleaner(),
    new E2ESettingsCleaner(),
    new AccountGuard()
  );
  @Local activity: ActivityStore = new ActivityStore(new E2EActivityRepository());
  @Local todoIssues: TodoWorklistStore =
    new TodoWorklistStore(new E2ETodoWorkbenchRepository(), TodoListKind.Issues);
  @Local todoPullRequests: TodoWorklistStore =
    new TodoWorklistStore(new E2ETodoWorkbenchRepository(), TodoListKind.PullRequests);
  @Local showTodoRoot: boolean = false;

  private readonly pathStack: NavPathStack = new NavPathStack();

  private todoKind(name: string): TodoListKind {
    return name === AppRouteName.TodoIssues ? TodoListKind.Issues : TodoListKind.PullRequests;
  }

  private todoStore(name: string): TodoWorklistStore {
    return this.todoKind(name) === TodoListKind.Issues ? this.todoIssues : this.todoPullRequests;
  }

  private openTodo(kind: TodoListKind): void {
    const name = kind === TodoListKind.Issues
      ? AppRouteName.TodoIssues : AppRouteName.TodoPullRequests;
    this.pathStack.pushPathByName(name, new TodoListParams(kind));
  }

  @Builder
  pageMap(name: string, _param: object): void {
    if (name === AppRouteName.TodoIssues || name === AppRouteName.TodoPullRequests) {
      TodoWorklistPage({
        kind: this.todoKind(name),
        store: this.todoStore(name),
        session: this.session,
        onBack: () => {
          this.pathStack.pop();
        },
        onOpenItem: (_item: TodoListItem) => {
        }
      })
    }
  }

  build() {
    HdsNavigation(this.pathStack) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.session.loggedIn) {
          if (this.showTodoRoot) {
            TodoPage({
              onOpenIssues: () => {
                this.openTodo(TodoListKind.Issues);
              },
              onOpenPullRequests: () => {
                this.openTodo(TodoListKind.PullRequests);
              }
            })
          } else {
            ActivityPage({
              store: this.activity,
              session: this.session,
              onOpenTarget: (_target: RepositoryItemRef | undefined,
                _kind: RepositoryItemKind | undefined, _repository: string) => {
              }
            })
            Button('Todo E2E')
              .height(40)
              .margin({ right: 16, bottom: 120 })
              .onClick(() => {
                this.showTodoRoot = true;
              })
              .id('e2e_open_todo_root')
          }
        } else {
          LoginPage({
            session: this.session,
            onLoggedIn: () => {
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
    .width('100%')
    .height('100%')
    .id('e2e_host')
  }
}
