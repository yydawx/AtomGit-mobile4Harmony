import { RepositoryItemKind } from '../model/CollaborationEntities';
import {
  emptyTodoListItem,
  TodoListItem,
  todoStatusSummary
} from '../model/TodoWorkbench';
import { Dimens, FontSize } from './DesignTokens';

/** One flat GitHub-style row shared by the Issue and Pull Request worklists. */
@ComponentV2
export struct TodoWorkItemRow {
  @Param item: TodoListItem = emptyTodoListItem();
  @Param onOpen: (item: TodoListItem) => void = (_item: TodoListItem): void => {};

  private icon(): Resource {
    return this.item.kind === RepositoryItemKind.Issue
      ? $r('sys.symbol.doc_text') : $r('sys.symbol.checkmark_square');
  }

  private iconColor(): ResourceColor {
    return this.item.kind === RepositoryItemKind.Issue
      ? $r('app.color.ag_success') : $r('app.color.ag_accent');
  }

  private repositoryLine(): string {
    const owner = this.item.ref.owner.trim();
    const repo = this.item.ref.repo.trim();
    const number = this.item.ref.number > 0 ? '#' + this.item.ref.number.toString() : '';
    if (owner.length === 0 || repo.length === 0) {
      return number;
    }
    return owner + '/' + repo + (number.length > 0 ? '  ' + number : '');
  }

  private titleLine(): string {
    return this.item.title.trim().length > 0 ? this.item.title : 'Untitled item';
  }

  private statusLine(): string {
    const summary = todoStatusSummary(this.item);
    return summary.length > 0 ? summary : 'No status available';
  }

  build() {
    Row({ space: Dimens.md }) {
      SymbolGlyph(this.icon())
        .fontSize(20)
        .fontColor([this.iconColor()])

      Column({ space: 3 }) {
        Text(this.repositoryLine())
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_tertiary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.titleLine())
          .fontSize(FontSize.bodyLarge)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ag_text_primary'))
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(EllipsisMode.MULTILINE_CENTER)

        Text(this.statusLine())
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_secondary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('app.color.ag_text_tertiary')])
    }
    .width('100%')
    .constraintSize({ minHeight: 72 })
    .padding({ left: Dimens.md, right: Dimens.lg, top: Dimens.sm, bottom: Dimens.sm })
    .backgroundColor($r('app.color.ag_surface'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.995 })
    .onClick(() => {
      this.onOpen(this.item);
    })
    .id('todo_row_' + this.item.kind + '_' + this.item.ref.key())
  }
}
