/**
 * 数据模型：笔记
 */
import { AI_STATUS_NONE, MAX_TAG_COUNT } from '../common/Constants';

export class Note {
  id: number = 0;
  title: string = '';
  content: string = '';
  /** 标签以英文逗号分隔存储，便于单表查询与 LIKE 检索 */
  tags: string = '';
  summary: string = '';
  /** 0 未生成 1 成功 2 失败 */
  aiStatus: number = AI_STATUS_NONE;
  isPinned: number = 0;
  createdAt: number = 0;
  updatedAt: number = 0;

  /** 是否为已存在（可更新）的笔记 */
  isPersisted(): boolean {
    return this.id > 0;
  }

  /** 标签数组视图 */
  tagList(): string[] {
    return parseTags(this.tags);
  }
}

/** 把「标签字符串」解析为数组，自动去空、去重、限长 */
export function parseTags(raw: string): string[] {
  const result: string[] = [];
  if (raw.length === 0) {
    return result;
  }
  const parts: string[] = raw.split(',');
  for (let i = 0; i < parts.length; i++) {
    const t: string = parts[i].trim();
    if (t.length === 0) {
      continue;
    }
    if (result.indexOf(t) >= 0) {
      continue;
    }
    if (result.length >= MAX_TAG_COUNT) {
      break;
    }
    result.push(t);
  }
  return result;
}

/** 把标签数组规范化回存储字符串 */
export function joinTags(list: string[]): string {
  const cleaned: string[] = [];
  for (let i = 0; i < list.length; i++) {
    const t: string = list[i].trim();
    if (t.length === 0 || cleaned.indexOf(t) >= 0) {
      continue;
    }
    if (cleaned.length >= MAX_TAG_COUNT) {
      break;
    }
    cleaned.push(t);
  }
  return cleaned.join(',');
}

/** 时间戳格式化：yyyy-MM-dd HH:mm */
export function formatTime(ts: number): string {
  if (ts <= 0) {
    return '—';
  }
  const d: Date = new Date(ts);
  const y: string = d.getFullYear().toString();
  const m: string = pad2(d.getMonth() + 1);
  const day: string = pad2(d.getDate());
  const hh: string = pad2(d.getHours());
  const mm: string = pad2(d.getMinutes());
  return y + '-' + m + '-' + day + ' ' + hh + ':' + mm;
}

function pad2(v: number): string {
  return v < 10 ? '0' + v.toString() : v.toString();
}

/** 列表页摘要用的单行预览：优先摘要，其次正文，压缩空白 */
export function previewText(note: Note): string {
  const source: string = note.summary.length > 0 ? note.summary : note.content;
  const flat: string = source.replace(/\s+/g, ' ').trim();
  if (flat.length <= 60) {
    return flat;
  }
  return flat.substring(0, 60) + '…';
}
