/**
 * AI 领域模型与错误分类
 */

/** AI 生成结果（尚未写库，需用户确认） */
export class AiSuggestion {
  summary: string = '';
  tags: string[] = [];
  /** 本次调用耗时（毫秒），用于页面展示与报告取证 */
  elapsedMs: number = 0;
  /** 本次调用消耗 token 总数，用于费用说明 */
  totalTokens: number = 0;
  /** 实际使用的模型名，便于核对 */
  model: string = '';
}

/** AI 失败原因分类，决定用户看到的提示文案与降级路径 */
export enum AiErrorCode {
  /** 未配置密钥 */
  NO_KEY = 0,
  /** 网络不可用 / DNS / 连接失败 */
  NETWORK = 1,
  /** 请求超时 */
  TIMEOUT = 2,
  /** 401 / 403 凭证问题 */
  AUTH = 3,
  /** 402 / 429 额度或频率限制 */
  QUOTA = 4,
  /** 5xx 服务端异常 */
  SERVER = 5,
  /** 返回体不是合法 JSON，或字段不符合约定 */
  FORMAT = 6,
  /** 正文过短等前置校验不通过 */
  CONTENT_TOO_SHORT = 7,
  /** AI 在设置中被关闭 */
  DISABLED = 8,
  /** 其他未知异常 */
  UNKNOWN = 9
}

/**
 * 业务异常载体。
 * ArkTS 的 throw 只能抛出 Error 及其子类（arkts-limited-throw 规则），
 * 因此这里继承 Error，同时用 code 表达失败分类、detail 承载排查细节。
 */
export class AiFailure extends Error {
  code: AiErrorCode = AiErrorCode.UNKNOWN;
  detail: string = '';

  constructor(code: AiErrorCode, detail: string) {
    super(detail);
    this.code = code;
    this.detail = detail;
    this.name = 'AiFailure';
  }
}

/** 把失败原因映射为资源字符串名，页面据此展示友好文案 */
export function aiErrorStringRes(code: AiErrorCode): Resource {
  if (code === AiErrorCode.NO_KEY) {
    return $r('app.string.ai_error_no_key');
  }
  if (code === AiErrorCode.NETWORK) {
    return $r('app.string.ai_error_network');
  }
  if (code === AiErrorCode.TIMEOUT) {
    return $r('app.string.ai_error_timeout');
  }
  if (code === AiErrorCode.AUTH) {
    return $r('app.string.ai_error_auth');
  }
  if (code === AiErrorCode.QUOTA) {
    return $r('app.string.ai_error_quota');
  }
  if (code === AiErrorCode.SERVER) {
    return $r('app.string.ai_error_server');
  }
  if (code === AiErrorCode.FORMAT) {
    return $r('app.string.ai_error_format');
  }
  if (code === AiErrorCode.CONTENT_TOO_SHORT) {
    return $r('app.string.ai_content_too_short');
  }
  if (code === AiErrorCode.DISABLED) {
    return $r('app.string.ai_disabled');
  }
  return $r('app.string.ai_error_unknown');
}
