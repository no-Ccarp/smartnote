/**
 * RDB 数据库入口
 * 负责建库、建表，并提供全局唯一的 RdbStore 实例。
 * 采用「惰性初始化 + 并发去重」：多个页面同时触发时只会真正初始化一次。
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DB_NAME, SQL_CREATE_NOTE, TABLE_NOTE, COL_UPDATED_AT } from '../common/Constants';
import { Logger } from '../common/Logger';

const SQL_CREATE_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_note_updated ON ' + TABLE_NOTE + ' (' + COL_UPDATED_AT + ')';

export class DbHelper {
  private static store: relationalStore.RdbStore | null = null;
  private static pending: Promise<relationalStore.RdbStore> | null = null;

  /** 获取（必要时创建）数据库实例 */
  static async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    if (DbHelper.store !== null) {
      return DbHelper.store;
    }
    if (DbHelper.pending !== null) {
      return DbHelper.pending;
    }
    DbHelper.pending = DbHelper.open(context);
    try {
      const s: relationalStore.RdbStore = await DbHelper.pending;
      DbHelper.store = s;
      return s;
    } finally {
      DbHelper.pending = null;
    }
  }

  private static async open(context: common.Context): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    Logger.info('DbHelper', '正在打开数据库：' + DB_NAME);
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    await store.executeSql(SQL_CREATE_NOTE);
    await store.executeSql(SQL_CREATE_INDEX);
    Logger.info('DbHelper', '数据表就绪：' + TABLE_NOTE);
    return store;
  }

  /** 仅供设置页「清空数据」后重置缓存使用 */
  static reset(): void {
    DbHelper.store = null;
    DbHelper.pending = null;
  }
}
