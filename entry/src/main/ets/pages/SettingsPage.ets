/**
 * 设置页
 *
 * 承担的真实业务作用（不是装饰页）：
 *  - AI 总开关：关闭后详情页隐藏 AI 入口，形成明确的降级路径；
 *  - 默认排序：影响首页列表的查询顺序（Preferences 持久化）；
 *  - 数据统计与一键清空：直接操作 RDB，并展示当前数据规模；
 *  - 版本与技术栈说明。
 */
import { common } from '@kit.AbilityKit';
import { NoteRepository } from '../data/NoteRepository';
import { SettingsService } from '../service/SettingsService';
import { Logger } from '../common/Logger';
import { bumpNotesVersion } from '../common/AppEvents';
import { SORT_BY_CREATED, SORT_BY_UPDATED } from '../common/Constants';

@Builder
export function SettingsBuilder() {
  SettingsPage()
}

@Component
struct SettingsPage {
  navPathStack: NavPathStack = new NavPathStack();
  @State aiEnabled: boolean = true;
  @State sortMode: number = SORT_BY_UPDATED;
  @State total: number = 0;
  @State aiCount: number = 0;
  @State loading: boolean = true;

  private ctx(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private toast(message: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const context: common.UIAbilityContext = this.ctx();
      this.aiEnabled = await SettingsService.isAiEnabled(context);
      this.sortMode = await SettingsService.getSortMode(context);
      this.total = await NoteRepository.countAll(context);
      this.aiCount = await NoteRepository.countWithSummary(context);
      this.loading = false;
    } catch (err) {
      this.loading = false;
      Logger.error('SettingsPage', '加载设置失败：' + JSON.stringify(err));
    }
  }

  private async onToggleAi(isOn: boolean): Promise<void> {
    this.aiEnabled = isOn;
    try {
      await SettingsService.setAiEnabled(this.ctx(), isOn);
    } catch (err) {
      Logger.error('SettingsPage', '保存 AI 开关失败：' + JSON.stringify(err));
    }
  }

  private async changeSort(mode: number): Promise<void> {
    this.sortMode = mode;
    try {
      await SettingsService.setSortMode(this.ctx(), mode);
    } catch (err) {
      Logger.error('SettingsPage', '保存排序设置失败：' + JSON.stringify(err));
    }
  }

  private confirmClear(): void {
    AlertDialog.show({
      title: $r('app.string.settings_clear_title'),
      message: $r('app.string.settings_clear_msg'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.dialog_cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.dialog_confirm'),
        fontColor: $r('app.color.danger_red'),
        action: () => {
          this.doClear();
        }
      }
    });
  }

  private async doClear(): Promise<void> {
    try {
      await NoteRepository.clearAll(this.ctx());
      this.toast($r('app.string.toast_cleared'));
      bumpNotesVersion();
      await this.load();
    } catch (err) {
      Logger.error('SettingsPage', '清空数据失败：' + JSON.stringify(err));
    }
  }

  @Builder
  SectionTitle(title: ResourceStr) {
    Text(title)
      .fontSize(12)
      .fontColor($r('app.color.secondary_text'))
      .width('100%')
      .padding({ left: 4, top: 6, bottom: 6 })
  }

  @Builder
  SortChip(label: ResourceStr, mode: number) {
    Button(label)
      .fontSize(13)
      .height(32)
      .backgroundColor(this.sortMode === mode ? $r('app.color.brand_light') : $r('app.color.tag_background'))
      .fontColor(this.sortMode === mode ? $r('app.color.brand_primary') : $r('app.color.primary_text'))
      .onClick(() => {
        this.changeSort(mode);
      })
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
      } else {
        Scroll() {
          Column({ space: 14 }) {
            // ---------- AI ----------
            this.SectionTitle($r('app.string.settings_section_ai'))
            Column({ space: 10 }) {
              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text($r('app.string.settings_ai_switch'))
                    .fontSize(15)
                    .fontColor($r('app.color.primary_text'))
                    .width('100%')
                  Text($r('app.string.settings_ai_switch_desc'))
                    .fontSize(12)
                    .lineHeight(18)
                    .fontColor($r('app.color.secondary_text'))
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: this.aiEnabled })
                  .selectedColor($r('app.color.brand_primary'))
                  .onChange((isOn: boolean) => {
                    this.onToggleAi(isOn);
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)

            // ---------- 排序 ----------
            this.SectionTitle($r('app.string.settings_section_sort'))
            Row({ space: 10 }) {
              this.SortChip($r('app.string.settings_sort_updated'), SORT_BY_UPDATED)
              this.SortChip($r('app.string.settings_sort_created'), SORT_BY_CREATED)
            }
            .width('100%')
            .padding(14)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)

            // ---------- 数据 ----------
            this.SectionTitle($r('app.string.settings_section_data'))
            Column({ space: 12 }) {
              Text($r('app.string.settings_stats', this.total, this.aiCount))
                .fontSize(13)
                .fontColor($r('app.color.secondary_text'))
                .width('100%')
              Button($r('app.string.settings_clear_all'))
                .fontSize(14)
                .height(40)
                .width('100%')
                .backgroundColor($r('app.color.tag_background'))
                .fontColor($r('app.color.danger_red'))
                .onClick(() => {
                  this.confirmClear();
                })
            }
            .width('100%')
            .padding(14)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)

            // ---------- 关于 ----------
            this.SectionTitle($r('app.string.settings_section_about'))
            Column({ space: 6 }) {
              Row() {
                Text('智记 SmartNote')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.primary_text'))
                Blank()
                Text($r('app.string.settings_about_version'))
                  .fontSize(12)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')

              Text($r('app.string.settings_about_desc'))
                .fontSize(12)
                .lineHeight(19)
                .fontColor($r('app.color.secondary_text'))
                .width('100%')
            }
            .width('100%')
            .padding(14)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 4, bottom: 24 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
    }
    .title($r('app.string.settings_title'))
    .backgroundColor($r('app.color.page_background'))
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
      this.load();
    })
  }
}
