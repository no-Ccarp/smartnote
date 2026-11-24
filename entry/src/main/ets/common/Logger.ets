/**
 * 日志封装
 * 统一 hilog 的 domain / tag 与格式，并提供敏感信息脱敏工具。
 * 规范：日志中不得出现完整 API Key、完整正文等敏感内容。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LOG_DOMAIN, LOG_TAG } from './Constants';

export class Logger {
  static info(scene: string, msg: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s | %{public}s', scene, msg);
  }

  static warn(scene: string, msg: string): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s | %{public}s', scene, msg);
  }

  static error(scene: string, msg: string): void {
    hilog.error(LOG_DOMAIN, LOG_TAG, '%{public}s | %{public}s', scene, msg);
  }

  /**
   * 密钥脱敏：仅保留前后 4 位，中间用 * 代替。
   * 空串返回「空」，短串整体打码，避免任何情况下完整密钥进入日志。
   */
  static maskKey(key: string): string {
    if (key.length === 0) {
      return '<empty>';
    }
    if (key.length <= 10) {
      return '***';
    }
    return key.substring(0, 4) + '****' + key.substring(key.length - 4);
  }

  /**
   * 文本脱敏：仅保留长度信息与首尾少量字符，用于记录正文相关日志。
   */
  static briefText(text: string): string {
    if (text.length <= 8) {
      return '<len=' + text.length + '>';
    }
    return text.substring(0, 4) + '...' + text.substring(text.length - 2) +
      '(len=' + text.length + ')';
  }
}
