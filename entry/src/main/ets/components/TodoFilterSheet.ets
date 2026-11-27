import {
  TodoFilter,
  TodoFilterOption,
  TodoListKind,
  todoFilterLabel,
  todoFilterOptions
} from '../model/TodoWorkbench';
import { Dimens, FontSize, Radius } from './DesignTokens';

/** Reusable filter panel intended to be mounted in an ArkUI sheet. */
@ComponentV2
export struct TodoFilterSheet {
  @Param kind: TodoListKind = TodoListKind.Issues;
  @Param selected: TodoFilter = TodoFilter.All;
  @Param onSelect: (filter: TodoFilter) => void = (_filter: TodoFilter): void => {};
  @Param onClose: () => void = (): void => {};

  private options(): TodoFilterOption[] {
    return todoFilterOptions(this.kind);
  }

  @Builder
  filterOption(option: TodoFilterOption): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: Dimens.sm }) {
        Text(option.label)
          .fontSize(FontSize.body)
          .fontWeight(this.selected === option.value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.selected === option.value
            ? $r('app.color.ag_accent') : $r('app.color.ag_text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        if (this.selected === option.value) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([$r('app.color.ag_accent')])
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: Dimens.md, right: Dimens.md })
    }
    .width('100%')
    .height(48)
    .borderRadius(Radius.chip)
    .backgroundColor(this.selected === option.value
      ? $r('app.color.ag_accent_soft') : Color.Transparent)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.99 })
    .onClick(() => {
      this.onSelect(option.value);
    })
    .id('todo_filter_' + option.value)
  }

  build() {
    Column({ space: Dimens.xs }) {
      Row({ space: Dimens.sm }) {
        Text('筛选')
          .fontSize(FontSize.title)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ag_text_primary'))
          .layoutWeight(1)
        Text(todoFilterLabel(this.selected))
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_tertiary'))
        Button('完成')
          .fontSize(FontSize.caption)
          .height(44)
          .borderRadius(Radius.chip)
          .backgroundColor($r('app.color.ag_accent_soft'))
          .fontColor($r('app.color.ag_accent'))
          .onClick(() => {
            this.onClose();
          })
          .id('todo_filter_done')
      }
      .width('100%')
      .padding({ left: Dimens.xs, right: Dimens.xs, bottom: Dimens.sm })

      ForEach(this.options(), (option: TodoFilterOption) => {
        this.filterOption(option)
      }, (option: TodoFilterOption) => option.value)

      Blank()
        .height(Dimens.sm)
    }
    .width('100%')
    .padding({ left: Dimens.lg, right: Dimens.lg, top: Dimens.lg, bottom: Dimens.xl })
    .backgroundColor($r('app.color.ag_surface'))
    .id('todo_filter_sheet')
  }
}
