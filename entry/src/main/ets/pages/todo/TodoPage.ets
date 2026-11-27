import { DisplayMetrics } from '../../common/DisplayMetrics';
import { AppTopBar } from '../../components/AppTopBar';
import { Dimens, FontSize, Motion, Radius } from '../../components/DesignTokens';
import { TAB_BAR_CONTENT_INSET } from '../../components/NavigationMetrics';

@ComponentV2
export struct TodoPage {
  @Param onOpenIssues: () => void = () => {};
  @Param onOpenPullRequests: () => void = () => {};

  @Local metrics: DisplayMetrics = DisplayMetrics.instance();
  @Local appeared: boolean = false;

  aboutToAppear(): void {
    this.getUIContext().animateTo({ duration: Motion.normal, curve: Curve.EaseOut }, () => {
      this.appeared = true;
    });
  }

  @Builder
  entryRow(title: string, isPullRequest: boolean, action: () => void): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: Dimens.md }) {
        Stack({ alignContent: Alignment.Center }) {
          Rect()
            .width(38)
            .height(38)
            .radius(10)
            .fill(isPullRequest
              ? $r('app.color.ag_accent') : $r('app.color.ag_success'))
          SymbolGlyph(isPullRequest
            ? $r('sys.symbol.checkmark_square') : $r('sys.symbol.doc_text'))
            .fontSize(20)
            .fontColor([$r('app.color.ag_text_on_accent')])
        }
        .width(38)
        .height(38)

        Text(title)
          .fontSize(FontSize.title)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ag_text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([$r('app.color.ag_text_tertiary')])
      }
      .width('100%')
      .height(62)
      .padding({ left: Dimens.md, right: Dimens.md })
    }
    .width('100%')
    .height(62)
    .borderRadius(0)
    .backgroundColor($r('app.color.ag_surface'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.995 })
    .onClick(() => {
      action();
    })
    .id(isPullRequest ? 'todo_open_pull_requests' : 'todo_open_issues')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Blank()
          .width('100%')
          .height(this.metrics.topInsetVp + AppTopBar.totalHeight(false) + Dimens.lg)

        Text('与我有关')
          .fontSize(FontSize.body)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ag_text_secondary'))
          .width('100%')
          .padding({ left: Dimens.xs, bottom: Dimens.sm })

        Column() {
          this.entryRow('Issues', false, this.onOpenIssues)
          Divider()
            .color($r('app.color.ag_separator'))
            .margin({ left: 62 })
          this.entryRow('Pull Requests', true, this.onOpenPullRequests)
        }
        .width('100%')
        .borderRadius(Radius.card)
        .backgroundColor($r('app.color.ag_surface'))
        .border({ width: 1, color: $r('app.color.ag_card_border') })
        .clip(true)
        .opacity(this.appeared ? 1 : 0)
        .translate({ y: this.appeared ? 0 : 8 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .padding({
        left: Dimens.lg,
        right: Dimens.lg,
        bottom: TAB_BAR_CONTENT_INSET + this.metrics.bottomInsetVp
          + this.metrics.desktopDockInset() + Dimens.sm
      })

      AppTopBar({
        title: '待办',
        scrolled: false
      })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.ag_hero_start'), 0], [$r('app.color.ag_background'), 0.45]]
    })
    .id('todo_page')
  }
}
