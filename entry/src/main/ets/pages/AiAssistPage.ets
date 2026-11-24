/**
 * AI 助手页：调用云端大模型为当前笔记生成摘要与标签。
 *
 * 交互闭环：
 *   点击生成 → 请求中（可取消返回） → 结果预览 → 用户「应用」后才写库
 *   → 返回详情页并刷新。
 *
 * 失败处理：所有失败归类为 AiErrorCode，映射为友好文案；
 * 同时保留「手动填写」的降级说明，符合赛道 B 对降级路径的要求。
 */
import { common } from '@kit.AbilityKit';
import { Note, joinTags, parseTags } from '../model/Note';
import { NoteRouteParam } from '../model/RouteParam';
import { AiSuggestion, AiErrorCode, AiFailure, aiErrorStringRes } from '../model/AiSuggestion';
import { AiService } from '../service/AiService';
import { NoteRepository } from '../data/NoteRepository';
import { SettingsService } from '../service/SettingsService';
import { Logger } from '../common/Logger';
import { bumpNotesVersion } from '../common/AppEvents';
import { TagChip } from '../views/TagChip';
import { AI_STATUS_FAILED, AI_STATUS_OK, MAX_TAG_COUNT } from '../common/Constants';

/** 页面阶段：0 待生成 1 请求中 2 成功 3 失败 */
const PHASE_IDLE: number = 0;
const PHASE_LOADING: number = 1;
const PHASE_SUCCESS: number = 2;
const PHASE_ERROR: number = 3;

@Builder
export function AiAssistBuilder() {
  AiAssistPage()
}

@Component
struct AiAssistPage {
  navPathStack: NavPathStack = new NavPathStack();
  @State note: Note = new Note();
  @State hasNote: boolean = false;
  @State loading: boolean = true;
  @State phase: number = PHASE_IDLE;
  @State suggestion: AiSuggestion = new AiSuggestion();
  @State errCode: AiErrorCode = AiErrorCode.UNKNOWN;
  @State errDetail: string = '';
  @State applying: boolean = false;

  private noteId: number = 0;

  private ctx(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private toast(message: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  async load(noteId: number): Promise<void> {
    this.noteId = noteId;
    this.loading = true;
    try {
      const context: common.UIAbilityContext = this.ctx();
      const enabled: boolean = await SettingsService.isAiEnabled(context);
      if (!enabled) {
        this.loading = false;
        this.hasNote = false;
        this.phase = PHASE_ERROR;
        this.errCode = AiErrorCode.DISABLED;
        Logger.warn('AiAssistPage', 'AI 已在设置中关闭');
        return;
      }
      const note: Note | null = await NoteRepository.queryById(context, noteId);
      if (note === null) {
        this.loading = false;
        this.hasNote = false;
        Logger.warn('AiAssistPage', '笔记不存在 id=' + noteId);
        return;
      }
      this.note = note;
      this.hasNote = true;
      this.loading = false;
      this.phase = PHASE_IDLE;
      Logger.info('AiAssistPage', '准备为 id=' + note.id + ' 生成摘要');
    } catch (err) {
      this.loading = false;
      this.hasNote = false;
      this.phase = PHASE_ERROR;
      this.errCode = AiErrorCode.UNKNOWN;
      Logger.error('AiAssistPage', '加载笔记失败：' + JSON.stringify(err));
    }
  }

  private async generate(): Promise<void> {
    this.phase = PHASE_LOADING;
    this.errDetail = '';
    try {
      const result: AiSuggestion = await AiService.generate(this.note);
      this.suggestion = result;
      this.phase = PHASE_SUCCESS;
    } catch (err) {
      if (err instanceof AiFailure) {
        const failure: AiFailure = err;
        this.errCode = failure.code;
        this.errDetail = failure.detail;
      } else {
        this.errCode = AiErrorCode.UNKNOWN;
        this.errDetail = '';
      }
      this.phase = PHASE_ERROR;
      Logger.warn('AiAssistPage', '生成失败 code=' + this.errCode);
    }
  }

  /** 用户确认后，把摘要与标签写回数据库 */
  private async apply(): Promise<void> {
    if (this.applying) {
      return;
    }
    this.applying = true;
    try {
      const context: common.UIAbilityContext = this.ctx();
      const merged: string[] = parseTags(this.note.tags);
      for (let i = 0; i < this.suggestion.tags.length; i++) {
        const t: string = this.suggestion.tags[i];
        if (merged.indexOf(t) < 0 && merged.length < MAX_TAG_COUNT) {
          merged.push(t);
        }
      }
      this.note.summary = this.suggestion.summary;
      this.note.tags = joinTags(merged);
      this.note.aiStatus = AI_STATUS_OK;
      await NoteRepository.update(context, this.note);
      this.applying = false;
      this.toast($r('app.string.ai_applied'));
      bumpNotesVersion();
      Logger.info('AiAssistPage', '已应用 AI 结果 id=' + this.note.id);
      this.navPathStack.pop(new NoteRouteParam(this.note.id));
    } catch (err) {
      this.applying = false;
      this.toast($r('app.string.edit_error_save'));
      Logger.error('AiAssistPage', '写入 AI 结果失败：' + JSON.stringify(err));
    }
  }

  private discard(): void {
    this.phase = PHASE_IDLE;
    this.suggestion = new AiSuggestion();
    this.errDetail = '';
  }

  @Builder
  IdleBlock() {
    Column({ space: 12 }) {
      Text($r('app.string.ai_intro'))
        .fontSize(13)
        .lineHeight(21)
        .fontColor($r('app.color.secondary_text'))
        .width('100%')

      Row() {
        Text(this.note.title.length > 0 ? this.note.title : '无标题')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.tag_background'))
      .borderRadius(10)

      Text($r('app.string.ai_fallback_hint'))
        .fontSize(12)
        .fontColor($r('app.color.text_hint'))
        .width('100%')

      Button($r('app.string.ai_action_generate'))
        .fontSize(15)
        .height(44)
        .width('100%')
        .backgroundColor($r('app.color.brand_primary'))
        .fontColor($r('app.color.white'))
        .onClick(() => {
          this.generate();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
  }

  @Builder
  LoadingBlock() {
    Column({ space: 14 }) {
      LoadingProgress()
        .width(40)
        .height(40)
        .color($r('app.color.brand_primary'))
      Text($r('app.string.ai_loading'))
        .fontSize(14)
        .fontColor($r('app.color.secondary_text'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SuccessBlock() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Text($r('app.string.ai_section_summary'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ai_accent'))
          .width('100%')
        Text(this.suggestion.summary)
          .fontSize(15)
          .lineHeight(24)
          .fontColor($r('app.color.primary_text'))
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.ai_background'))
      .borderRadius(12)

      Column({ space: 8 }) {
        Text($r('app.string.ai_section_tags'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.secondary_text'))
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.suggestion.tags, (t: string) => {
            Row() {
              TagChip({ text: t })
            }
            .margin({ right: 6, bottom: 6 })
          }, (t: string) => t)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Text($r('app.string.ai_elapsed', this.suggestion.elapsedMs, this.suggestion.totalTokens))
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
        .width('100%')

      Row({ space: 10 }) {
        Button($r('app.string.ai_action_discard'))
          .fontSize(14)
          .height(42)
          .layoutWeight(1)
          .backgroundColor($r('app.color.tag_background'))
          .fontColor($r('app.color.primary_text'))
          .onClick(() => {
            this.discard();
          })
        Button($r('app.string.ai_action_apply'))
          .fontSize(14)
          .height(42)
          .layoutWeight(1)
          .enabled(!this.applying)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor($r('app.color.white'))
          .onClick(() => {
            this.apply();
          })
      }
      .width('100%')

      Button($r('app.string.ai_action_regenerate'))
        .fontSize(13)
        .height(36)
        .width('100%')
        .backgroundColor($r('app.color.card_background'))
        .fontColor($r('app.color.secondary_text'))
        .onClick(() => {
          this.generate();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
  }

  @Builder
  ErrorBlock() {
    Column({ space: 12 }) {
      Text(aiErrorStringRes(this.errCode))
        .fontSize(15)
        .lineHeight(23)
        .fontColor($r('app.color.danger_red'))
        .width('100%')

      if (this.errDetail.length > 0) {
        Text('技术细节：' + this.errDetail)
          .fontSize(11)
          .lineHeight(17)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
      }

      Text($r('app.string.ai_fallback_hint'))
        .fontSize(12)
        .lineHeight(19)
        .fontColor($r('app.color.secondary_text'))
        .width('100%')

      Button($r('app.string.action_retry'))
        .fontSize(15)
        .height(44)
        .width('100%')
        .backgroundColor($r('app.color.brand_primary'))
        .fontColor($r('app.color.white'))
        .onClick(() => {
          this.generate();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
  }

  build() {
    NavDestination() {
      Column() {
        if (this.loading) {
          this.LoadingBlock()
        } else if (!this.hasNote && this.phase !== PHASE_ERROR) {
          Column() {
            Text($r('app.string.detail_not_found'))
              .fontSize(15)
              .fontColor($r('app.color.secondary_text'))
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.phase === PHASE_LOADING) {
          this.LoadingBlock()
        } else if (this.phase === PHASE_SUCCESS) {
          Scroll() {
            this.SuccessBlock()
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        } else if (this.phase === PHASE_ERROR) {
          Scroll() {
            this.ErrorBlock()
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        } else {
          Scroll() {
            this.IdleBlock()
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
    }
    .title($r('app.string.ai_title'))
    .backgroundColor($r('app.color.page_background'))
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
      const param: Object = ctx.pathInfo.param as Object;
      if (param instanceof NoteRouteParam) {
        this.load((param as NoteRouteParam).noteId);
      } else {
        this.loading = false;
        this.hasNote = false;
        this.phase = PHASE_ERROR;
        this.errCode = AiErrorCode.UNKNOWN;
        Logger.warn('AiAssistPage', '路由参数非法');
      }
    })
  }
}
