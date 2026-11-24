/**
 * 设置服务（Preferences）
 * 保存与业务无关但影响行为的轻量配置：AI 开关、默认排序、是否已写入演示数据。
 * 与 RDB 形成对照：结构化业务数据走 RDB，键值型配置走 Preferences。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  PREF_NAME, PREF_KEY_AI_ENABLED, PREF_KEY_SORT_MODE, PREF_KEY_SEEDED, SORT_BY_UPDATED
} from '../common/Constants';
import { Logger } from '../common/Logger';

export class SettingsService {
  private static pref: preferences.Preferences | null = null;

  private static async get(context: common.Context): Promise<preferences.Preferences> {
    if (SettingsService.pref !== null) {
      return SettingsService.pref;
    }
    const options: preferences.Options = { name: PREF_NAME };
    const p: preferences.Preferences = await preferences.getPreferences(context, options);
    SettingsService.pref = p;
    return p;
  }

  /** AI 总开关，默认开启 */
  static async isAiEnabled(context: common.Context): Promise<boolean> {
    try {
      const p: preferences.Preferences = await SettingsService.get(context);
      const v: preferences.ValueType = await p.get(PREF_KEY_AI_ENABLED, true);
      return v as boolean;
    } catch (e) {
      Logger.error('SettingsService', '读取 AI 开关失败，按默认值 true 处理');
      return true;
    }
  }

  static async setAiEnabled(context: common.Context, enabled: boolean): Promise<void> {
    const p: preferences.Preferences = await SettingsService.get(context);
    await p.put(PREF_KEY_AI_ENABLED, enabled);
    await p.flush();
    Logger.info('SettingsService', 'AI 开关已更新为 ' + enabled);
  }

  /** 默认排序：0 按更新时间，1 按创建时间 */
  static async getSortMode(context: common.Context): Promise<number> {
    try {
      const p: preferences.Preferences = await SettingsService.get(context);
      const v: preferences.ValueType = await p.get(PREF_KEY_SORT_MODE, SORT_BY_UPDATED);
      return v as number;
    } catch (e) {
      return SORT_BY_UPDATED;
    }
  }

  static async setSortMode(context: common.Context, mode: number): Promise<void> {
    const p: preferences.Preferences = await SettingsService.get(context);
    await p.put(PREF_KEY_SORT_MODE, mode);
    await p.flush();
    Logger.info('SettingsService', '默认排序已更新为 ' + mode);
  }

  /** 是否已经写入过演示数据，避免用户清空后又被动恢复 */
  static async isSeeded(context: common.Context): Promise<boolean> {
    try {
      const p: preferences.Preferences = await SettingsService.get(context);
      const v: preferences.ValueType = await p.get(PREF_KEY_SEEDED, false);
      return v as boolean;
    } catch (e) {
      return false;
    }
  }

  static async markSeeded(context: common.Context): Promise<void> {
    const p: preferences.Preferences = await SettingsService.get(context);
    await p.put(PREF_KEY_SEEDED, true);
    await p.flush();
  }
}
