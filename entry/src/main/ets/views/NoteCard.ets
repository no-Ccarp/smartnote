/**
 * 笔记卡片（列表项）
 */
import { Note, previewText, formatTime } from '../model/Note';
import { TagChip } from './TagChip';
import { AI_STATUS_OK } from '../common/Constants';

@Component
export struct NoteCard {
  note: Note = new Note();
  onOpen: () => void = () => {
  };

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(this.note.title.length > 0 ? this.note.title : '无标题')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (this.note.isPinned === 1) {
          Text('置顶')
            .fontSize(10)
            .fontColor($r('app.color.brand_primary'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor($r('app.color.brand_light'))
            .borderRadius(4)
        }
      }
      .width('100%')

      Text(previewText(this.note))
        .fontSize(13)
        .fontColor($r('app.color.secondary_text'))
        .lineHeight(19)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 6 }) {
        if (this.note.tagList().length > 0) {
          ForEach(this.note.tagList(), (t: string) => {
            TagChip({ text: t })
          }, (t: string) => t)
        }
        Blank()
        if (this.note.aiStatus === AI_STATUS_OK) {
          Text('AI')
            .fontSize(10)
            .fontColor($r('app.color.ai_accent'))
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .backgroundColor($r('app.color.ai_background'))
            .borderRadius(4)
        }
        Text(formatTime(this.note.updatedAt))
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .onClick(() => {
      this.onOpen();
    })
  }
}
