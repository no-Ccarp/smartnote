/**
 * 全局常量
 * 集中管理数据库表结构、Preferences 键名、AI 服务参数与业务限制，
 * 避免魔法字符串散落在各层代码中。
 */

// ---------- 日志 ----------
export const LOG_DOMAIN: number = 0x1A01;
export const LOG_TAG: string = 'SmartNote';

// ---------- 关系型数据库 ----------
export const DB_NAME: string = 'smartnote.db';
export const TABLE_NOTE: string = 'notes';

export const COL_ID: string = 'id';
export const COL_TITLE: string = 'title';
export const COL_CONTENT: string = 'content';
export const COL_TAGS: string = 'tags';
export const COL_SUMMARY: string = 'summary';
export const COL_AI_STATUS: string = 'ai_status';
export const COL_IS_PINNED: string = 'is_pinned';
export const COL_CREATED_AT: string = 'created_at';
export const COL_UPDATED_AT: string = 'updated_at';

export const NOTE_COLUMNS: string[] = [
  COL_ID, COL_TITLE, COL_CONTENT, COL_TAGS, COL_SUMMARY,
  COL_AI_STATUS, COL_IS_PINNED, COL_CREATED_AT, COL_UPDATED_AT
];

export const SQL_CREATE_NOTE: string =
  'CREATE TABLE IF NOT EXISTS ' + TABLE_NOTE + ' (' +
  COL_ID + ' INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  COL_TITLE + ' TEXT NOT NULL DEFAULT \'\', ' +
  COL_CONTENT + ' TEXT NOT NULL DEFAULT \'\', ' +
  COL_TAGS + ' TEXT NOT NULL DEFAULT \'\', ' +
  COL_SUMMARY + ' TEXT NOT NULL DEFAULT \'\', ' +
  COL_AI_STATUS + ' INTEGER NOT NULL DEFAULT 0, ' +
  COL_IS_PINNED + ' INTEGER NOT NULL DEFAULT 0, ' +
  COL_CREATED_AT + ' INTEGER NOT NULL DEFAULT 0, ' +
  COL_UPDATED_AT + ' INTEGER NOT NULL DEFAULT 0)';

// ---------- 首选项（设置） ----------
export const PREF_NAME: string = 'smartnote_settings';
export const PREF_KEY_AI_ENABLED: string = 'ai_enabled';
export const PREF_KEY_SORT_MODE: string = 'sort_mode';
export const PREF_KEY_SEEDED: string = 'seeded';

// ---------- 跨页面状态 ----------
export const KEY_NOTES_VERSION: string = 'notesVersion';

// ---------- 业务限制 ----------
export const MAX_TITLE_LEN: number = 60;
export const MAX_TAG_COUNT: number = 5;
export const MAX_SUMMARY_LEN: number = 160;
export const MIN_AI_CONTENT_LEN: number = 20;
export const AI_CONTENT_TRUNCATE: number = 1500;

// ---------- AI 服务 ----------
export const AI_TIMEOUT_MS: number = 20000;
export const AI_CONNECT_TIMEOUT_MS: number = 12000;
export const AI_MAX_RETRY: number = 1;

// ---------- 路由（Navigation） ----------
export const ROUTE_NOTE_EDIT: string = 'NoteEdit';
export const ROUTE_NOTE_DETAIL: string = 'NoteDetail';
export const ROUTE_AI_ASSIST: string = 'AiAssist';
export const ROUTE_SETTINGS: string = 'Settings';

// ---------- 排序 ----------
export const SORT_BY_UPDATED: number = 0;
export const SORT_BY_CREATED: number = 1;

// ---------- AI 状态 ----------
export const AI_STATUS_NONE: number = 0;
export const AI_STATUS_OK: number = 1;
export const AI_STATUS_FAILED: number = 2;
