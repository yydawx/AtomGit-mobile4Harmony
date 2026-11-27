import { LengthMetrics } from '@kit.ArkUI';
import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationMenuContentOptions,
  HdsNavigationMenuItemOptions,
  ScrollEffectType
} from '@kit.UIDesignKit';

import { DisplayMetrics } from '../../common/DisplayMetrics';
import { Dimens, FontSize, Radius } from '../../components/DesignTokens';
import { EmptyView, ErrorView } from '../../components/StatusViews';
import { TodoFilterSheet } from '../../components/TodoFilterSheet';
import { TodoWorkItemRow } from '../../components/TodoWorkItemRow';
import {
  TodoFilter,
  TodoListItem,
  TodoListKind,
  todoListTitle
} from '../../model/TodoWorkbench';
import { EmptySessionStore } from '../../viewmodel/EmptySessionStore';
import { LoadState, SessionStore } from '../../viewmodel/SessionStore';
import { EmptyTodoWorklistStore, TodoWorklistStore } from '../../viewmodel/TodoWorklistStore';

@ComponentV2
export struct TodoWorklistPage {
  @Param kind: TodoListKind = TodoListKind.Issues;
  @Param store: TodoWorklistStore = new EmptyTodoWorklistStore(TodoListKind.Issues);
  @Param session: SessionStore = new EmptySessionStore();
  @Param onBack: () => void = (): void => {};
  @Param onOpenItem: (item: TodoListItem) => void = (_item: TodoListItem): void => {};

  @Local showFilter: boolean = false;
  @Local metrics: DisplayMetrics = DisplayMetrics.instance();

  private readonly contentScroller: Scroller = new Scroller();
  private initializing: boolean = false;

  aboutToAppear(): void {
    this.initialize();
  }

  aboutToDisappear(): void {
    this.store.cancelPending();
  }

  @Monitor('session.user')
  onAccountChanged(): void {
    this.initialize();
  }

  @Monitor('session.repos.length')
  onReposChanged(): void {
    this.initialize();
  }

  private async initialize(): Promise<void> {
    if (this.initializing) {
      return;
    }
    this.initializing = true;
    try {
      const user = this.session.user;
      if (user === undefined) {
        return;
      }
      while (this.session.hasMoreRepos) {
        const before = this.session.repos.length;
        await this.session.loadRepos();
        if (this.session.repos.length === before) {
          break;
        }
      }
      this.store.initialize(user.accountId, user.login, this.session.repos);
      await this.store.loadIfNeeded();
    } finally {
      this.initializing = false;
    }
  }

  private filterMenu(): HdsNavigationMenuContentOptions | undefined {
    const item: HdsNavigationMenuItemOptions = {
      content: {
        icon: $r('sys.symbol.slider_horizontal_2'),
        componentId: 'todo_filter_menu',
        action: (): void => {
          this.showFilter = true;
        }
      }
    };
    const items: HdsNavigationMenuItemOptions[] = [item];
    return { value: items, maxCount: 1 };
  }

  private emptyText(): string {
    if (this.store.filter === TodoFilter.OwnedProjects && this.store.ownedRepoCount === 0) {
      return '没有找到你拥有的项目';
    }
    return '这个筛选下暂时没有事项';
  }

  private async selectFilter(filter: TodoFilter): Promise<void> {
    await this.store.selectFilter(filter);
  }

  @Builder
  filterOverlay(): void {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(0.28)
        .onClick(() => {
          this.showFilter = false;
        })

      TodoFilterSheet({
        kind: this.kind,
        selected: this.store.filter,
        onSelect: (filter: TodoFilter) => {
          this.selectFilter(filter);
        },
        onClose: () => {
          this.showFilter = false;
        }
      })
        .padding({ bottom: this.metrics.bottomInsetVp })
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 24 })))
    }
    .width('100%')
    .height('100%')
    .id('todo_filter_overlay')
  }

  @Builder
  partialFailure(): void {
    if (this.store.partialErrorMessage.length > 0) {
      Row({ space: Dimens.sm }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
          .fontSize(16)
          .fontColor([$r('app.color.ag_warning')])
        Text(this.store.partialErrorMessage)
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_secondary'))
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button('重试')
          .fontSize(FontSize.caption)
          .height(32)
          .backgroundColor($r('app.color.ag_background'))
          .fontColor($r('app.color.ag_accent'))
          .onClick(() => {
            this.store.refresh();
          })
      }
      .width('100%')
      .padding(Dimens.md)
      .borderRadius(Radius.chip)
      .backgroundColor($r('app.color.ag_surface'))
      .border({ width: 1, color: $r('app.color.ag_warning') })
    }
  }

  @Builder
  listContent(): void {
    Refresh({ refreshing: this.store.refreshing }) {
      List({ space: 0, scroller: this.contentScroller }) {
        ListItem() {
          this.partialFailure()
        }
        .padding({ bottom: Dimens.xs })

        ForEach(this.store.items, (item: TodoListItem, index: number) => {
          ListItem() {
            Column() {
              TodoWorkItemRow({
                item: item,
                onOpen: (selected: TodoListItem) => {
                  this.onOpenItem(selected);
                }
              })
              if (index < this.store.items.length - 1) {
                Divider()
                  .color($r('app.color.ag_separator'))
                  .margin({ left: 42, right: Dimens.lg })
              }
            }
            .width('100%')
            .backgroundColor($r('app.color.ag_surface'))
          }
        }, (item: TodoListItem) => item.key())

        if (this.store.loadingMore) {
          ListItem() {
            Row({ space: Dimens.sm }) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color($r('app.color.ag_accent'))
              Text('加载更多')
                .fontSize(FontSize.caption)
                .fontColor($r('app.color.ag_text_tertiary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(Dimens.lg)
          }
        } else if (this.store.hasMore) {
          ListItem() {
            Button('加载更多')
              .fontSize(FontSize.caption)
              .height(38)
              .backgroundColor($r('app.color.ag_accent_soft'))
              .fontColor($r('app.color.ag_accent'))
              .onClick(() => {
                this.store.loadMore();
              })
          }
          .width('100%')
          .padding(Dimens.md)
        } else if (this.store.items.length > 0) {
          ListItem() {
            Text('已显示全部已加载事项')
              .fontSize(10)
              .fontColor($r('app.color.ag_text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(Dimens.lg)
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: Dimens.lg, right: Dimens.lg, bottom: Dimens.xl })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        this.store.loadMore();
      })
      .id('todo_worklist_' + this.kind)
    }
    .layoutWeight(1)
    .width('100%')
    .onRefreshing(() => {
      this.store.refresh();
    })
    .id('todo_worklist_refresh_' + this.kind)
  }

  @Builder
  pageContent(): void {
    if ((this.store.state === LoadState.Idle || this.store.state === LoadState.Loading)
      && this.store.items.length === 0) {
      Column({ space: Dimens.sm }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('app.color.ag_accent'))
        Text('正在加载')
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_secondary'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .id('todo_worklist_loading_' + this.kind)
    } else if (this.store.state === LoadState.Error && this.store.items.length === 0) {
      Column({ space: Dimens.md }) {
        ErrorView({
          message: this.store.errorMessage,
          retryable: false,
          viewId: 'todo_worklist_error_' + this.kind
        })
        Button('重试')
          .fontSize(FontSize.body)
          .height(40)
          .backgroundColor($r('app.color.ag_accent'))
          .fontColor($r('app.color.ag_text_on_accent'))
          .onClick(() => {
            this.store.refresh();
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(Dimens.lg)
    } else if (this.store.items.length === 0) {
      EmptyView({
        text: this.emptyText(),
        symbol: this.kind === TodoListKind.Issues
          ? $r('sys.symbol.doc_text') : $r('sys.symbol.checkmark_square'),
        viewId: 'todo_worklist_empty_' + this.kind
      })
    } else {
      this.listContent()
    }
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Column() {
          Blank()
            .width('100%')
            .height(this.metrics.topInsetVp + 88)
          this.pageContent()
        }
        .width('100%')
        .height('100%')

        if (this.showFilter) {
          this.filterOverlay()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.ag_background'))
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(0)
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: {
          mainTitle: todoListTitle(this.kind),
          subTitle: this.store.filterLabel(),
          mainTitleId: 'todo_worklist_title_' + this.kind
        },
        menu: this.filterMenu()
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.contentScroller])
    .onBackPressed(() => {
      if (this.showFilter) {
        this.showFilter = false;
        return true;
      }
      this.onBack();
      return true;
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .id('todo_worklist_page_' + this.kind)
  }
}
