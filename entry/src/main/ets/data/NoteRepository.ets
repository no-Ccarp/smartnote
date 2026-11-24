/**
 * 笔记数据仓库
 * 封装 notes 表的全部增删改查，是页面层唯一允许访问数据库的入口。
 * 所有方法均保证：ResultSet 关闭、异常向上抛出前记录日志。
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DbHelper } from './DbHelper';
import { Note } from '../model/Note';
import {
  TABLE_NOTE, NOTE_COLUMNS, COL_ID, COL_TITLE, COL_CONTENT, COL_TAGS, COL_SUMMARY,
  COL_AI_STATUS, COL_IS_PINNED, COL_CREATED_AT, COL_UPDATED_AT,
  AI_STATUS_OK, SORT_BY_CREATED, SORT_BY_UPDATED
} from '../common/Constants';
import { Logger } from '../common/Logger';

export class NoteRepository {

  /** 新增笔记，返回自增主键 */
  static async insert(context: common.Context, note: Note): Promise<number> {
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    const now: number = Date.now();
    note.createdAt = note.createdAt > 0 ? note.createdAt : now;
    note.updatedAt = now;
    const bucket: relationalStore.ValuesBucket = NoteRepository.toBucket(note, false);
    const rowId: number = await store.insert(TABLE_NOTE, bucket);
    Logger.info('NoteRepository', '新增笔记成功，rowId=' + rowId);
    return rowId;
  }

  /** 按主键更新笔记 */
  static async update(context: common.Context, note: Note): Promise<number> {
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    note.updatedAt = Date.now();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NOTE);
    predicates.equalTo(COL_ID, note.id);
    const rows: number = await store.update(NoteRepository.toBucket(note, true), predicates);
    Logger.info('NoteRepository', '更新笔记 id=' + note.id + '，影响行数=' + rows);
    return rows;
  }

  /** 按主键删除 */
  static async remove(context: common.Context, id: number): Promise<number> {
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NOTE);
    predicates.equalTo(COL_ID, id);
    const rows: number = await store.delete(predicates);
    Logger.info('NoteRepository', '删除笔记 id=' + id + '，影响行数=' + rows);
    return rows;
  }

  /** 查询全部（置顶优先） */
  static async queryAll(context: common.Context, sortMode: number): Promise<Note[]> {
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NOTE);
    predicates.orderByDesc(COL_IS_PINNED);
    if (sortMode === SORT_BY_CREATED) {
      predicates.orderByDesc(COL_CREATED_AT);
    } else {
      predicates.orderByDesc(COL_UPDATED_AT);
    }
    const rs: relationalStore.ResultSet = await store.query(predicates, NOTE_COLUMNS);
    return NoteRepository.mapRows(rs);
  }

  /** 关键词检索：标题 / 正文 / 标签 三字段 LIKE 匹配 */
  static async search(context: common.Context, keyword: string, sortMode: number): Promise<Note[]> {
    const kw: string = keyword.trim();
    if (kw.length === 0) {
      return NoteRepository.queryAll(context, sortMode);
    }
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    const like: string = '%' + kw + '%';
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NOTE);
    predicates.beginWrap()
      .like(COL_TITLE, like)
      .or().like(COL_CONTENT, like)
      .or().like(COL_TAGS, like)
      .endWrap();
    predicates.orderByDesc(COL_IS_PINNED);
    if (sortMode === SORT_BY_CREATED) {
      predicates.orderByDesc(COL_CREATED_AT);
    } else {
      predicates.orderByDesc(COL_UPDATED_AT);
    }
    const rs: relationalStore.ResultSet = await store.query(predicates, NOTE_COLUMNS);
    return NoteRepository.mapRows(rs);
  }

  /** 按主键查询单条，不存在返回 null（供详情页处理非法参数） */
  static async queryById(context: common.Context, id: number): Promise<Note | null> {
    if (id <= 0) {
      return null;
    }
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NOTE);
    predicates.equalTo(COL_ID, id);
    const rs: relationalStore.ResultSet = await store.query(predicates, NOTE_COLUMNS);
    const list: Note[] = NoteRepository.mapRows(rs);
    if (list.length === 0) {
      return null;
    }
    return list[0];
  }

  /** 总数 */
  static async countAll(context: common.Context): Promise<number> {
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NOTE);
    const rs: relationalStore.ResultSet = await store.query(predicates, [COL_ID]);
    const total: number = rs.rowCount;
    rs.close();
    return total < 0 ? 0 : total;
  }

  /** 已生成摘要的条数 */
  static async countWithSummary(context: common.Context): Promise<number> {
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NOTE);
    predicates.equalTo(COL_AI_STATUS, AI_STATUS_OK);
    const rs: relationalStore.ResultSet = await store.query(predicates, [COL_ID]);
    const total: number = rs.rowCount;
    rs.close();
    return total < 0 ? 0 : total;
  }

  /** 清空全部数据 */
  static async clearAll(context: common.Context): Promise<void> {
    const store: relationalStore.RdbStore = await DbHelper.getStore(context);
    await store.executeSql('DELETE FROM ' + TABLE_NOTE);
    Logger.warn('NoteRepository', '已清空全部笔记');
  }

  /** 写入演示用初始数据，方便首次打开即有内容 */
  static async seed(context: common.Context): Promise<void> {
    const now: number = Date.now();
    const samples: Note[] = NoteRepository.buildSamples(now);
    for (let i = 0; i < samples.length; i++) {
      await NoteRepository.insert(context, samples[i]);
    }
    Logger.info('NoteRepository', '写入演示数据 ' + samples.length + ' 条');
  }

  private static buildSamples(now: number): Note[] {
    const a: Note = new Note();
    a.title = '鸿蒙课程大作业选题';
    a.content = '今天把大作业的选题定下来了，做一款智能笔记应用。传统的笔记功能包括新建、编辑、' +
      '删除、搜索和标签管理，这些都能脱离 AI 独立完成；AI 增强的部分是让云端大模型阅读正文，' +
      '自动生成一段摘要和若干标签，用户确认之后再写入数据库。这样既符合赛道 B 的思路，' +
      '也避免了为了用 AI 而用 AI。下周要先把数据持久化和页面闭环跑通，再接入 AI。';
    a.tags = '课程,选题,鸿蒙';
    a.createdAt = now - 7200000;
    a.updatedAt = now - 3600000;

    const b: Note = new Note();
    b.title = '周四组会要准备的内容';
    b.content = '组会需要汇报三件事：第一是数据持久化方案，决定用关系型数据库存笔记，' +
      '用首选项存设置；第二是页面结构，目前规划了列表、编辑、详情、AI 助手和设置五个页面；' +
      '第三是 AI 服务的选型与费用，用的是 DeepSeek 的免费额度，需要说明失败时的降级路径。' +
      '另外要把自测清单补齐，至少覆盖主流程、一次成功的云端调用和一种失败状态。';
    b.tags = '组会,汇报,计划';
    b.createdAt = now - 90000000;
    b.updatedAt = now - 86400000;

    const c: Note = new Note();
    c.title = '读《人类简史》第五章';
    c.content = '这一章讲的是认知革命之后，智人如何依靠虚构的故事形成大规模协作。' +
      '作者认为，国家、货币、公司这些概念本质上都是共同想象的产物，' +
      '因为足够多的人相信，它们才具有真实的约束力。这个观点放在软件项目里也成立：' +
      '需求文档、接口约定、排期，本质上也是一种共识，共识一旦破裂，项目就会出问题。';
    c.tags = '读书,历史';
    c.createdAt = now - 260000000;
    c.updatedAt = now - 260000000;

    const list: Note[] = [a, b, c];
    return list;
  }

  // ---------- 内部工具 ----------

  private static toBucket(note: Note, includeId: boolean): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'title': note.title,
      'content': note.content,
      'tags': note.tags,
      'summary': note.summary,
      'ai_status': note.aiStatus,
      'is_pinned': note.isPinned,
      'created_at': note.createdAt,
      'updated_at': note.updatedAt
    };
    return bucket;
  }

  private static mapRows(rs: relationalStore.ResultSet): Note[] {
    const list: Note[] = [];
    try {
      while (rs.goToNextRow()) {
        const n: Note = new Note();
        n.id = rs.getLong(rs.getColumnIndex(COL_ID));
        n.title = rs.getString(rs.getColumnIndex(COL_TITLE));
        n.content = rs.getString(rs.getColumnIndex(COL_CONTENT));
        n.tags = rs.getString(rs.getColumnIndex(COL_TAGS));
        n.summary = rs.getString(rs.getColumnIndex(COL_SUMMARY));
        n.aiStatus = rs.getLong(rs.getColumnIndex(COL_AI_STATUS));
        n.isPinned = rs.getLong(rs.getColumnIndex(COL_IS_PINNED));
        n.createdAt = rs.getLong(rs.getColumnIndex(COL_CREATED_AT));
        n.updatedAt = rs.getLong(rs.getColumnIndex(COL_UPDATED_AT));
        list.push(n);
      }
    } finally {
      rs.close();
    }
    return list;
  }
}
