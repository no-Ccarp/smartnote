/**
 * 详情页：展示笔记全文、摘要与标签，并提供进入编辑 / AI 助手的入口。
 *
 * 边界处理：
 *  - 参数缺失、类型非法或 id 不存在 → 「笔记不存在」态；
 *  - 从编辑页 / AI 页返回 → 自动重新加载，保证展示与数据库一致；
 *  - AI 在设置中关闭 → 隐藏 AI 入口并给出降级说明。
 */
import { common } from '@kit.AbilityKit';
import { Note, formatTime } from '../model/Note';
import { NoteRouteParam } from '../model/RouteParam';
import { NoteRepository } from '../data/NoteRepository';
import { SettingsService } from '../service/SettingsService';
import { Logger } from '../common/Logger';
import { TagChip } from '../views/TagChip';
import { AI_STATUS_OK, ROUTE_AI_ASSIST, ROUTE_NOTE_EDIT } from '../common/Constants';

@Builder
export function NoteDetailBuilder() {
  NoteDetailPage()
}

@Component
struct NoteDetailPage {
  navPathStack: NavPathStack = new NavPathStack();
  @State note: Note = new Note();
  @State hasNote: boolean = false;
  @State loading: boolean = true;
  @State notFound: boolean = false;
  @State aiEnabled: boolean = true;
  private noteId: number = 0;

  private ctx(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  async load(noteId: number): Promise<void> {
    this.noteId = noteId;
    this.loading = true;
    try {
      const context: common.UIAbilityContext = this.ctx();
      this.aiEnabled = await SettingsService.isAiEnabled(context);
      const note: Note | null = await NoteRepository.queryById(context, noteId);
      if (note === null) {
        this.hasNote = false;
        this.notFound = true;
        this.loading = false;
        return;
      }
      this.note = note;
      this.hasNote = true;
      this.notFound = false;
      this.loading = false;
      Logger.info('NoteDetailPage', '加载笔记成功 id=' + note.id + ' aiStatus=' + note.aiStatus);
    } catch (err) {
      this.hasNote = false;
      this.notFound = true;
      this.loading = false;
      Logger.error('NoteDetailPage', '加载笔记失败：' + JSON.stringify(err));
    }
  }

  private openEditor(): void {
    this.navPathStack.pushPathByName(ROUTE_NOTE_EDIT, new NoteRouteParam(this.noteId), (info: PopInfo) => {
      this.refreshFromChild();
    });
  }

  private openAi(): void {
    this.navPathStack.pushPathByName(ROUTE_AI_ASSIST, new NoteRouteParam(this.noteId), (info: PopInfo) => {
      this.refreshFromChild();
    });
  }

  /**
   * 从子页面返回时刷新。
   * 若笔记已被子页面删除，则直接退回列表，避免停留在「笔记不存在」的空态上。
   */
  private async refreshFromChild(): Promise<void> {
    try {
      const context: common.UIAbilityContext = this.ctx();
      const note: Note | null = await NoteRepository.queryById(context, this.noteId);
      if (note === null) {
        Logger.info('NoteDetailPage', '笔记已不存在，退回列表 id=' + this.noteId);
        this.navPathStack.pop(new NoteRouteParam(-1));
        return;
      }
      this.note = note;
      this.hasNote = true;
      this.notFound = false;
      this.loading = false;
      Logger.info('NoteDetailPage', '从子页面返回后刷新成功 id=' + note.id);
    } catch (err) {
      Logger.error('NoteDetailPage', '刷新失败：' + JSON.stringify(err));
    }
  }

  @Builder
  SummaryBlock() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text($r('app.string.detail_label_summary'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ai_accent'))
        if (this.note.aiStatus === AI_STATUS_OK) {
          Text('AI')
            .fontSize(10)
            .fontColor($r('app.color.ai_accent'))
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .backgroundColor($r('app.color.white'))
            .borderRadius(4)
        }
      }

      if (this.note.summary.length > 0) {
        Text(this.note.summary)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.primary_text'))
          .width('100%')
      } else {
        Text($r('app.string.detail_no_summary'))
          .fontSize(13)
          .lineHeight(20)
          .fontColor($r('app.color.secondary_text'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.ai_background'))
    .borderRadius(12)
  }

  build() {
    NavDestination() {
      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color($r('app.color.brand_primary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (!this.hasNote) {
        Column() {
          Text($r('app.string.detail_not_found'))
            .fontSize(15)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Scroll() {
            Column({ space: 12 }) {
              Text(this.note.title)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text'))
                .width('100%')

              Text($r('app.string.detail_label_updated', formatTime(this.note.updatedAt)))
                .fontSize(12)
                .fontColor($r('app.color.text_hint'))
                .width('100%')

              if (this.note.tagList().length > 0) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.note.tagList(), (t: string) => {
                    Row() {
                      TagChip({ text: t })
                    }
                    .margin({ right: 6, bottom: 6 })
                  }, (t: string) => t)
                }
                .width('100%')
              }

              this.SummaryBlock()

              Text(this.note.content)
                .fontSize(15)
                .lineHeight(25)
                .fontColor($r('app.color.primary_text'))
                .width('100%')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 16 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          Divider().color($r('app.color.divider'))

          Column({ space: 8 }) {
            Row({ space: 10 }) {
              Button($r('app.string.detail_action_edit'))
                .fontSize(15)
                .height(42)
                .layoutWeight(1)
                .backgroundColor($r('app.color.tag_background'))
                .fontColor($r('app.color.primary_text'))
                .onClick(() => {
                  this.openEditor();
                })

              if (this.aiEnabled) {
                Button($r('app.string.detail_action_ai'))
                  .fontSize(15)
                  .height(42)
                  .layoutWeight(1)
                  .backgroundColor($r('app.color.brand_primary'))
                  .fontColor($r('app.color.white'))
                  .onClick(() => {
                    this.openAi();
                  })
              }
            }
            .width('100%')

            if (!this.aiEnabled) {
              Text($r('app.string.ai_disabled'))
                .fontSize(12)
                .fontColor($r('app.color.text_hint'))
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 12 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_background'))
      }
    }
    .title($r('app.string.detail_title'))
    .backgroundColor($r('app.color.page_background'))
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
      const param: Object = ctx.pathInfo.param as Object;
      if (param instanceof NoteRouteParam) {
        this.load((param as NoteRouteParam).noteId);
      } else {
        this.loading = false;
        this.hasNote = false;
        this.notFound = true;
        Logger.warn('NoteDetailPage', '路由参数非法');
      }
    })
  }
}
