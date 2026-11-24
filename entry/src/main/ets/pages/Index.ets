/**
 * 首页：笔记列表
 *
 * 承担的职责：
 *  - 展示全部笔记（置顶优先），支持关键词检索；
 *  - 首次启动写入演示数据；
 *  - 作为 Navigation 的根容器，统一发起页面跳转并在返回后刷新；
 *  - 覆盖加载中 / 空数据 / 搜索无结果 / 加载失败四种状态。
 */
import { common } from '@kit.AbilityKit';
import { Note } from '../model/Note';
import { NoteRouteParam } from '../model/RouteParam';
import { NoteRepository } from '../data/NoteRepository';
import { SettingsService } from '../service/SettingsService';
import { Logger } from '../common/Logger';
import { NoteCard } from '../views/NoteCard';
import { StateView } from '../views/StateView';
import {
  ROUTE_NOTE_EDIT, ROUTE_NOTE_DETAIL, ROUTE_SETTINGS, SORT_BY_UPDATED
} from '../common/Constants';

@Entry
@Component
struct Index {
  @State notes: Note[] = [];
  @State keyword: string = '';
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State total: number = 0;
  /** 监听全局数据版本号：任何页面写库后都会触发首页刷新 */
  @StorageLink('notesVersion') @Watch('onNotesVersionChange') notesVersion: number = 0;

  pathStack: NavPathStack = new NavPathStack();
  private sortMode: number = SORT_BY_UPDATED;
  /** 请求序号，避免连续输入搜索词时旧结果覆盖新结果 */
  private reqSeq: number = 0;

  aboutToAppear(): void {
    Logger.info('IndexPage', '首页出现，初始版本号=' + this.notesVersion);
    this.reload();
  }

  /** 版本号变化 → 数据被其他页面改动 → 重新查询 */
  onNotesVersionChange(): void {
    Logger.info('IndexPage', '收到数据变更通知，版本号=' + this.notesVersion);
    this.reload();
  }

  private ctx(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  /** 从数据库重新加载列表 */
  async reload(): Promise<void> {
    this.reqSeq = this.reqSeq + 1;
    const seq: number = this.reqSeq;
    this.loading = true;
    this.errorMsg = '';
    try {
      const context: common.UIAbilityContext = this.ctx();

      // 首次启动：写入演示数据（之后即使用户清空也不再自动恢复）
      const seeded: boolean = await SettingsService.isSeeded(context);
      if (!seeded) {
        await NoteRepository.seed(context);
        await SettingsService.markSeeded(context);
      }

      this.sortMode = await SettingsService.getSortMode(context);
      const list: Note[] = await NoteRepository.search(context, this.keyword, this.sortMode);
      const count: number = await NoteRepository.countAll(context);
      if (seq !== this.reqSeq) {
        return;
      }
      this.notes = list;
      this.total = count;
      this.loading = false;
      Logger.info('IndexPage', '列表加载完成 count=' + list.length + ' keyword.len=' + this.keyword.length);
    } catch (err) {
      if (seq !== this.reqSeq) {
        return;
      }
      this.loading = false;
      this.errorMsg = '数据加载失败，请重试';
      Logger.error('IndexPage', '列表加载失败：' + JSON.stringify(err));
    }
  }

  private openEditor(noteId: number): void {
    this.pathStack.pushPathByName(ROUTE_NOTE_EDIT, new NoteRouteParam(noteId), (info: PopInfo) => {
      Logger.info('IndexPage', '从编辑页返回');
      this.reload();
    });
  }

  private openDetail(noteId: number): void {
    this.pathStack.pushPathByName(ROUTE_NOTE_DETAIL, new NoteRouteParam(noteId), (info: PopInfo) => {
      Logger.info('IndexPage', '从详情页返回');
      this.reload();
    });
  }

  private openSettings(): void {
    this.pathStack.pushPathByName(ROUTE_SETTINGS, new NoteRouteParam(0), (info: PopInfo) => {
      this.reload();
    });
  }

  private emptyTitle(): Resource {
    if (this.keyword.length > 0) {
      return $r('app.string.list_search_empty_title');
    }
    return $r('app.string.list_empty_title');
  }

  private emptyDesc(): Resource {
    if (this.keyword.length > 0) {
      return $r('app.string.list_search_empty_desc');
    }
    return $r('app.string.list_empty_desc');
  }

  @Builder
  HeaderBar() {
    Row() {
      Column({ space: 2 }) {
        Text($r('app.string.page_list_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text'))
        Text($r('app.string.list_count', this.total))
          .fontSize(12)
          .fontColor($r('app.color.secondary_text'))
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Button($r('app.string.action_settings'))
        .fontSize(13)
        .height(32)
        .backgroundColor($r('app.color.tag_background'))
        .fontColor($r('app.color.primary_text'))
        .onClick(() => {
          this.openSettings();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 8 })
  }

  @Builder
  SearchBar() {
    Search({ value: this.keyword, placeholder: $r('app.string.list_search_hint') })
      .width('100%')
      .height(40)
      .margin({ left: 16, right: 16, bottom: 10 })
      .backgroundColor($r('app.color.card_background'))
      .placeholderColor($r('app.color.text_hint'))
      .onChange((value: string) => {
        this.keyword = value;
        this.reload();
      })
  }

  @Builder
  Fab() {
    Button() {
      Text('+')
        .fontSize(30)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.white'))
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor($r('app.color.brand_primary'))
    .margin({ right: 20, bottom: 28 })
    .onClick(() => {
      this.openEditor(0);
    })
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          this.HeaderBar()
          this.SearchBar()

          Column() {
            if (this.loading) {
              LoadingProgress()
                .width(36)
                .height(36)
                .color($r('app.color.brand_primary'))
            } else if (this.errorMsg.length > 0) {
              StateView({
                title: $r('app.string.state_error_title'),
                desc: this.errorMsg,
                showRetry: true,
                onRetry: () => {
                  this.reload();
                }
              })
            } else if (this.notes.length === 0) {
              StateView({
                title: this.emptyTitle(),
                desc: this.emptyDesc(),
                showRetry: false
              })
            } else {
              List({ space: 10 }) {
                ForEach(this.notes, (item: Note) => {
                  ListItem() {
                    NoteCard({
                      note: item,
                      onOpen: () => {
                        this.openDetail(item.id);
                      }
                    })
                  }
                }, (item: Note) => item.id + '_' + item.updatedAt + '_' + item.isPinned)
              }
              .width('100%')
              .layoutWeight(1)
              .padding({ left: 16, right: 16, bottom: 96 })
              .scrollBar(BarState.Off)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_background'))

        this.Fab()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }
}
