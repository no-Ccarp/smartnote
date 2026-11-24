/**
 * 跨页面数据变更通知
 *
 * 背景：从设置页「清空数据」返回首页时，仅靠 Navigation 的 onPop 回调刷新列表
 * 在某些时序下拿到的仍是旧快照。这里用 AppStorage 维护一个「数据版本号」，
 * 任何会改变笔记数据的页面在写库成功后把版本号 +1，首页通过
 * @StorageLink + @Watch 监听版本号变化并重新查询，保证列表与数据库一致。
 */
import { KEY_NOTES_VERSION } from './Constants';

/** 初始化版本号（应用启动时调用一次） */
export function initNotesVersion(): void {
  AppStorage.setOrCreate<number>(KEY_NOTES_VERSION, 0);
}

/** 数据发生变更后调用，通知首页重新加载 */
export function bumpNotesVersion(): void {
  const current: number | undefined = AppStorage.get<number>(KEY_NOTES_VERSION);
  const next: number = (current === undefined ? 0 : current) + 1;
  AppStorage.setOrCreate<number>(KEY_NOTES_VERSION, next);
}
