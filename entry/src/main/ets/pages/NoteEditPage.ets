/**
 * 编辑页：新建 / 修改 / 删除笔记
 *
 * 参数：NoteRouteParam.noteId，0 表示新建，>0 表示编辑既有笔记。
 * 边界处理：
 *  - 参数类型非法或 id 不存在 → 进入「笔记不存在」态，不写库；
 *  - 标题或正文为空 → 本地校验拦截并提示；
 *  - 有未保存修改时返回 → 二次确认，避免误丢内容；
 *  - 保存 / 删除失败 → 友好提示，页面不崩溃。
 */
import { common } from '@kit.AbilityKit';
import { Note, joinTags, parseTags } from '../model/Note';
import { NoteRouteParam } from '../model/RouteParam';
import { NoteRepository } from '../data/NoteRepository';
import { Logger } from '../common/Logger';
import { bumpNotesVersion } from '../common/AppEvents';

@Builder
export function NoteEditBuilder() {
  NoteEditPage()
}

@Component
struct NoteEditPage {
  navPathStack: NavPathStack = new NavPathStack();
  @State noteId: number = 0;
  @State title: string = '';
  @State content: string = '';
  @State tagsInput: string = '';
  /** 摘要可手动填写：AI 不可用时的降级路径 */
  @State summaryInput: string = '';
  @State loading: boolean = true;
  @State notFound: boolean = false;
  @State saving: boolean = false;
  @State paramInvalid: boolean = false;
  private current: Note = new Note();

  private ctx(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  async load(noteId: number): Promise<void> {
    this.noteId = noteId;
    if (noteId <= 0) {
      // 新建模式
      this.current = new Note();
      this.title = '';
      this.content = '';
      this.tagsInput = '';
      this.loading = false;
      this.notFound = false;
      return;
    }
    try {
      const note: Note | null = await NoteRepository.queryById(this.ctx(), noteId);
      if (note === null) {
        this.loading = false;
        this.notFound = true;
        Logger.warn('NoteEditPage', '笔记不存在 id=' + noteId);
        return;
      }
      this.current = note;
      this.title = note.title;
      this.content = note.content;
      this.tagsInput = note.tagList().join('，');
      this.summaryInput = note.summary;
      this.loading = false;
    } catch (err) {
      this.loading = false;
      this.notFound = true;
      Logger.error('NoteEditPage', '加载笔记失败：' + JSON.stringify(err));
    }
  }

  private isDirty(): boolean {
    if (this.noteId <= 0) {
      return this.title.trim().length > 0 || this.content.trim().length > 0 ||
        this.tagsInput.trim().length > 0 || this.summaryInput.trim().length > 0;
    }
    return this.title.trim() !== this.current.title.trim() ||
      this.content.trim() !== this.current.content.trim() ||
      this.normalizedTags() !== this.current.tags ||
      this.summaryInput.trim() !== this.current.summary;
  }

  private normalizedTags(): string {
    // 允许中文逗号、英文逗号混用
    const unified: string = this.tagsInput.replace(/，/g, ',');
    return joinTags(parseTags(unified));
  }

  private toast(message: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    const t: string = this.title.trim();
    const c: string = this.content.trim();
    if (t.length === 0) {
      this.toast($r('app.string.edit_error_title_empty'));
      return;
    }
    if (c.length === 0) {
      this.toast($r('app.string.edit_error_content_empty'));
      return;
    }
    this.saving = true;
    try {
      const context: common.UIAbilityContext = this.ctx();
      this.current.title = t;
      this.current.content = c;
      this.current.tags = this.normalizedTags();
      this.current.summary = this.summaryInput.trim();
      if (this.current.isPersisted()) {
        await NoteRepository.update(context, this.current);
        Logger.info('NoteEditPage', '更新笔记 id=' + this.current.id);
      } else {
        const rowId: number = await NoteRepository.insert(context, this.current);
        this.current.id = rowId;
        Logger.info('NoteEditPage', '新增笔记 id=' + rowId);
      }
      this.saving = false;
      this.toast($r('app.string.toast_saved'));
      bumpNotesVersion();
      this.navPathStack.pop(new NoteRouteParam(this.current.id));
    } catch (err) {
      this.saving = false;
      this.toast($r('app.string.edit_error_save'));
      Logger.error('NoteEditPage', '保存失败：' + JSON.stringify(err));
    }
  }

  private confirmDelete(): void {
    AlertDialog.show({
      title: $r('app.string.edit_delete_title'),
      message: $r('app.string.edit_delete_msg'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.dialog_cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.action_delete'),
        fontColor: $r('app.color.danger_red'),
        action: () => {
          this.doDelete();
        }
      }
    });
  }

  private async doDelete(): Promise<void> {
    try {
      await NoteRepository.remove(this.ctx(), this.current.id);
      this.toast($r('app.string.toast_deleted'));
      bumpNotesVersion();
      Logger.info('NoteEditPage', '删除笔记 id=' + this.current.id);
      this.navPathStack.pop(new NoteRouteParam(-1));
    } catch (err) {
      this.toast($r('app.string.edit_error_delete'));
      Logger.error('NoteEditPage', '删除失败：' + JSON.stringify(err));
    }
  }

  private confirmLeave(): void {
    AlertDialog.show({
      title: $r('app.string.edit_unsaved_title'),
      message: $r('app.string.edit_unsaved_msg'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.edit_keep'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.edit_leave'),
        fontColor: $r('app.color.danger_red'),
        action: () => {
          this.navPathStack.pop(new NoteRouteParam(-2));
        }
      }
    });
  }

  private pageTitle(): Resource {
    if (this.noteId > 0) {
      return $r('app.string.edit_title_edit');
    }
    return $r('app.string.edit_title_new');
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
      } else if (this.notFound || this.paramInvalid) {
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
          TextInput({ text: $$this.title, placeholder: $r('app.string.edit_hint_title') })
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text'))
            .placeholderColor($r('app.color.text_hint'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .maxLength(60)

          Row({ space: 8 }) {
            Text($r('app.string.edit_label_tags'))
              .fontSize(13)
              .fontColor($r('app.color.secondary_text'))
            TextInput({ text: $$this.tagsInput, placeholder: $r('app.string.edit_hint_tags') })
              .fontSize(13)
              .fontColor($r('app.color.primary_text'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 0 })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 6 })

          Row({ space: 8 }) {
            Text($r('app.string.edit_label_summary'))
              .fontSize(13)
              .fontColor($r('app.color.secondary_text'))
            TextInput({ text: $$this.summaryInput, placeholder: $r('app.string.edit_hint_summary') })
              .fontSize(13)
              .fontColor($r('app.color.primary_text'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 0 })
              .maxLength(160)
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 2 })

          Divider()
            .color($r('app.color.divider'))
            .margin({ top: 8, bottom: 8 })

          TextArea({ text: $$this.content, placeholder: $r('app.string.edit_hint_content') })
            .fontSize(15)
            .lineHeight(24)
            .fontColor($r('app.color.primary_text'))
            .placeholderColor($r('app.color.text_hint'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .layoutWeight(1)

          Divider().color($r('app.color.divider'))

          Row({ space: 12 }) {
            if (this.noteId > 0) {
              Button($r('app.string.action_delete'))
                .fontSize(14)
                .height(40)
                .backgroundColor($r('app.color.tag_background'))
                .fontColor($r('app.color.danger_red'))
                .onClick(() => {
                  this.confirmDelete();
                })
            }
            Text($r('app.string.edit_char_count', this.content.length))
              .fontSize(12)
              .fontColor($r('app.color.text_hint'))
              .layoutWeight(1)
              .textAlign(TextAlign.End)
            Button($r('app.string.action_save'))
              .fontSize(15)
              .height(40)
              .width(96)
              .enabled(!this.saving)
              .backgroundColor($r('app.color.brand_primary'))
              .fontColor($r('app.color.white'))
              .onClick(() => {
                this.save();
              })
          }
          .width('100%')
          .margin({ top: 12, bottom: 8 })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 4 })
        .backgroundColor($r('app.color.page_background'))
      }
    }
    .title(this.pageTitle())
    .backgroundColor($r('app.color.page_background'))
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
      const param: Object = ctx.pathInfo.param as Object;
      if (param instanceof NoteRouteParam) {
        this.load((param as NoteRouteParam).noteId);
      } else {
        // 非法 / 缺失参数：不加载数据，展示友好提示
        this.paramInvalid = true;
        this.loading = false;
        Logger.warn('NoteEditPage', '路由参数非法，已进入空态');
      }
    })
    .onBackPressed(() => {
      if (this.isDirty()) {
        this.confirmLeave();
        return true;
      }
      return false;
    })
  }
}
