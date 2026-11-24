/**
 * 云端 AI 服务（DeepSeek / OpenAI 兼容接口）
 *
 * 职责边界：
 *  - 只负责「把笔记正文送出去，把结构化结果拿回来并校验」；
 *  - 不写数据库，不操作界面，结果交由页面确认后再落库；
 *  - 所有失败都归类为 AiFailure，由页面映射为友好文案与降级路径。
 *
 * 关键设计：
 *  1) 前置校验：密钥缺失、正文过短时不发请求，避免无意义计费；
 *  2) 宽松解析 + 严格校验：兼容模型返回 ```json 围栏或前后带解释文字的情况；
 *  3) 有限重试：仅对网络/超时/服务端/格式四类可重试错误重试 1 次；
 *  4) 日志脱敏：只记录密钥掩码、正文长度与耗时，不记录完整正文。
 */
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AI_CONFIG, hasApiKey } from '../common/LocalConfig';
import {
  AI_TIMEOUT_MS, AI_CONNECT_TIMEOUT_MS, AI_MAX_RETRY, AI_CONTENT_TRUNCATE,
  MIN_AI_CONTENT_LEN, MAX_SUMMARY_LEN, MAX_TAG_COUNT
} from '../common/Constants';
import { AiErrorCode, AiFailure, AiSuggestion } from '../model/AiSuggestion';
import { Note } from '../model/Note';
import { Logger } from '../common/Logger';

// ---------- 请求 / 响应结构（OpenAI 兼容格式） ----------

interface ChatMessage {
  role: string;
  content: string;
}

interface ChatRequestBody {
  model: string;
  messages: ChatMessage[];
  stream: boolean;
  temperature: number;
}

interface ChatRespMessage {
  content?: string;
}

interface ChatChoice {
  message?: ChatRespMessage;
}

interface ChatUsage {
  prompt_tokens?: number;
  completion_tokens?: number;
  total_tokens?: number;
}

interface ChatErrorBody {
  message?: string;
  type?: string;
  code?: string;
}

interface ChatResponse {
  model?: string;
  choices?: ChatChoice[];
  usage?: ChatUsage;
  error?: ChatErrorBody;
}

/** 模型应返回的结构化载荷 */
interface AiPayload {
  summary?: string;
  tags?: string[];
}

const SYSTEM_PROMPT: string =
  '你是一个中文笔记助手。请阅读用户提供的笔记，输出严格的 JSON 对象，' +
  '不要输出任何解释文字、Markdown 代码块或额外说明。\n' +
  'JSON 结构固定为：{"summary":"摘要文本","tags":["标签1","标签2"]}\n' +
  '要求：\n' +
  '1. summary 是不超过 60 字的中文摘要，概括笔记核心内容，不要复述原文；\n' +
  '2. tags 是 2 到 5 个中文关键词，每个不超过 8 个字，不要带标点；\n' +
  '3. 只输出 JSON 本身。';

export class AiService {

  /**
   * 为一条笔记生成摘要与标签。
   * 成功返回 AiSuggestion；失败抛出 AiFailure（调用方用 instanceof 判定）。
   */
  static async generate(note: Note): Promise<AiSuggestion> {
    if (!AI_CONFIG.enabled) {
      throw new AiFailure(AiErrorCode.DISABLED, 'ai disabled by config');
    }
    if (!hasApiKey()) {
      throw new AiFailure(AiErrorCode.NO_KEY, 'api key not configured');
    }
    const content: string = note.content.trim();
    if (content.length < MIN_AI_CONTENT_LEN) {
      throw new AiFailure(AiErrorCode.CONTENT_TOO_SHORT, 'content too short');
    }

    const messages: ChatMessage[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: AiService.buildUserPrompt(note) }
    ];

    Logger.info('AiService', '发起云端调用 model=' + AI_CONFIG.model +
      ' key=' + Logger.maskKey(AI_CONFIG.apiKey) +
      ' contentLen=' + content.length);

    let lastFailure: AiFailure | null = null;
    for (let attempt = 0; attempt <= AI_MAX_RETRY; attempt++) {
      try {
        const suggestion: AiSuggestion = await AiService.requestOnce(messages);
        Logger.info('AiService', '调用成功 elapsed=' + suggestion.elapsedMs +
          'ms tokens=' + suggestion.totalTokens + ' tags=' + suggestion.tags.length);
        return suggestion;
      } catch (err) {
        if (!(err instanceof AiFailure)) {
          Logger.error('AiService', '未归类的异常：' + JSON.stringify(err));
          throw new AiFailure(AiErrorCode.UNKNOWN, 'unknown error');
        }
        const failure: AiFailure = err;
        lastFailure = failure;
        Logger.warn('AiService', '第 ' + (attempt + 1) + ' 次尝试失败 code=' + failure.code +
          ' detail=' + failure.detail);
        if (!AiService.isRetryable(failure.code)) {
          break;
        }
      }
    }

    if (lastFailure !== null) {
      throw lastFailure;
    }
    throw new AiFailure(AiErrorCode.UNKNOWN, 'no attempt executed');
  }

  // ---------- 单次请求 ----------

  private static async requestOnce(messages: ChatMessage[]): Promise<AiSuggestion> {
    const req: http.HttpRequest = http.createHttp();
    const startedAt: number = Date.now();
    const body: ChatRequestBody = {
      model: AI_CONFIG.model,
      messages: messages,
      stream: false,
      temperature: 0.3
    };
    try {
      const resp: http.HttpResponse = await req.request(AI_CONFIG.baseUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + AI_CONFIG.apiKey
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: AI_CONNECT_TIMEOUT_MS,
        readTimeout: AI_TIMEOUT_MS
      });

      const elapsed: number = Date.now() - startedAt;
      const code: number = resp.responseCode;
      if (code !== http.ResponseCode.OK) {
        const raw: string = resp.result as string;
        Logger.error('AiService', 'HTTP 非 200，code=' + code + ' body=' + AiService.brief(raw));
        throw AiService.mapHttpError(code, raw);
      }
      const raw: string = resp.result as string;
      Logger.info('AiService', '收到响应 elapsed=' + elapsed + 'ms，响应长度=' + raw.length);
      return AiService.parseResult(raw, elapsed);
    } catch (err) {
      if (err instanceof AiFailure) {
        throw err;
      }
      const be: BusinessError = err as BusinessError;
      throw AiService.mapNetworkError(be);
    } finally {
      // 无论成功失败都释放请求对象，防止内存泄漏
      req.destroy();
    }
  }

  // ---------- 响应解析 ----------

  private static parseResult(raw: string, elapsed: number): AiSuggestion {
    let outer: ChatResponse;
    try {
      outer = JSON.parse(raw) as ChatResponse;
    } catch (e) {
      throw new AiFailure(AiErrorCode.FORMAT, 'response is not json');
    }

    if (outer.error !== undefined && outer.error.message !== undefined) {
      throw new AiFailure(AiErrorCode.SERVER, 'provider error: ' + outer.error.message);
    }
    if (outer.choices === undefined || outer.choices.length === 0) {
      throw new AiFailure(AiErrorCode.FORMAT, 'choices empty');
    }
    const first: ChatChoice = outer.choices[0];
    if (first.message === undefined || first.message.content === undefined) {
      throw new AiFailure(AiErrorCode.FORMAT, 'message content missing');
    }

    const content: string = first.message.content;
    const jsonText: string = AiService.extractJson(content);
    if (jsonText.length === 0) {
      throw new AiFailure(AiErrorCode.FORMAT, 'no json object found in content');
    }

    let payload: AiPayload;
    try {
      payload = JSON.parse(jsonText) as AiPayload;
    } catch (e) {
      throw new AiFailure(AiErrorCode.FORMAT, 'inner json invalid');
    }

    let summary: string = '';
    let tags: string[] = [];
    try {
      summary = AiService.normalizeSummary(payload.summary);
      tags = AiService.normalizeTags(payload.tags);
    } catch (e) {
      throw new AiFailure(AiErrorCode.FORMAT, 'normalize failed');
    }

    if (summary.length === 0) {
      throw new AiFailure(AiErrorCode.FORMAT, 'summary empty');
    }

    const result: AiSuggestion = new AiSuggestion();
    result.summary = summary;
    result.tags = tags;
    result.elapsedMs = elapsed;
    result.totalTokens = AiService.readTokens(outer.usage);
    result.model = outer.model !== undefined ? outer.model : AI_CONFIG.model;
    return result;
  }

  /** 从模型输出里截出 JSON 主体，兼容 ```json 围栏与前后多余文字 */
  private static extractJson(content: string): string {
    const text: string = content.trim();
    const start: number = text.indexOf('{');
    const end: number = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return '';
    }
    return text.substring(start, end + 1).trim();
  }

  private static normalizeSummary(raw: string | undefined): string {
    if (raw === undefined) {
      return '';
    }
    let s: string = raw.trim().replace(/\s+/g, ' ');
    if (s.length > MAX_SUMMARY_LEN) {
      s = s.substring(0, MAX_SUMMARY_LEN);
    }
    return s;
  }

  private static normalizeTags(raw: string[] | undefined): string[] {
    const out: string[] = [];
    if (raw === undefined) {
      return out;
    }
    for (let i = 0; i < raw.length; i++) {
      const item: string = raw[i];
      const t: string = item.trim().replace(/^#/, '');
      if (t.length === 0 || out.indexOf(t) >= 0) {
        continue;
      }
      if (out.length >= MAX_TAG_COUNT) {
        break;
      }
      out.push(t);
    }
    return out;
  }

  private static readTokens(usage: ChatUsage | undefined): number {
    if (usage === undefined) {
      return 0;
    }
    if (usage.total_tokens !== undefined) {
      return usage.total_tokens;
    }
    const p: number = usage.prompt_tokens !== undefined ? usage.prompt_tokens : 0;
    const c: number = usage.completion_tokens !== undefined ? usage.completion_tokens : 0;
    return p + c;
  }

  // ---------- 提示词 ----------

  private static buildUserPrompt(note: Note): string {
    const title: string = note.title.trim().length > 0 ? note.title.trim() : '（无标题）';
    let body: string = note.content.trim();
    if (body.length > AI_CONTENT_TRUNCATE) {
      body = body.substring(0, AI_CONTENT_TRUNCATE) + '…';
    }
    return '标题：' + title + '\n正文：' + body;
  }

  // ---------- 错误归类 ----------

  private static isRetryable(code: AiErrorCode): boolean {
    return code === AiErrorCode.NETWORK || code === AiErrorCode.TIMEOUT ||
      code === AiErrorCode.SERVER || code === AiErrorCode.FORMAT;
  }

  private static mapHttpError(code: number, raw: string): AiFailure {
    if (code === 401 || code === 403) {
      return new AiFailure(AiErrorCode.AUTH, 'http ' + code);
    }
    if (code === 402 || code === 429) {
      return new AiFailure(AiErrorCode.QUOTA, 'http ' + code);
    }
    if (code >= 500) {
      return new AiFailure(AiErrorCode.SERVER, 'http ' + code);
    }
    return new AiFailure(AiErrorCode.UNKNOWN, 'http ' + code + ' body=' + AiService.brief(raw));
  }

  private static mapNetworkError(be: BusinessError): AiFailure {
    const code: number = be.code as number;
    const msg: string = '' + (be.message as string);
    Logger.error('AiService', '网络异常 code=' + code + ' msg=' + msg);
    if (code === 2300028) {
      return new AiFailure(AiErrorCode.TIMEOUT, 'timeout');
    }
    if (code === 2300006 || code === 2300007 || code === 201) {
      return new AiFailure(AiErrorCode.NETWORK, 'network code=' + code);
    }
    if (msg.toLowerCase().indexOf('timeout') >= 0) {
      return new AiFailure(AiErrorCode.TIMEOUT, 'timeout by message');
    }
    if (msg.toLowerCase().indexOf('resolve') >= 0 || msg.toLowerCase().indexOf('connection') >= 0) {
      return new AiFailure(AiErrorCode.NETWORK, 'network by message');
    }
    return new AiFailure(AiErrorCode.UNKNOWN, 'code=' + code + ' msg=' + msg);
  }

  private static brief(text: string): string {
    if (text.length <= 120) {
      return text;
    }
    return text.substring(0, 120) + '…';
  }
}
