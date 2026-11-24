/**
 * 本地私有配置（AI 服务地址、模型名与密钥）
 *
 * ⚠️ 安全约定：
 * 1. 本文件是本机私有的运行配置，已在 .gitignore 中排除，不进入版本库；
 * 2. 源码、README、报告、日志中均不得出现完整密钥；
 * 3. 提交包内的本文件已将 apiKey 置为空串，需要使用者自行填写后重新构建。
 *
 * 密钥缺失时的行为：AI 页面会进入「未配置密钥」的降级状态并给出明确提示，
 * 不会发起一次注定失败的请求；笔记的增删改查、检索、手动摘要等功能完全不受影响。
 */

/** AI 服务配置结构（ArkTS 不支持 as const，故用显式接口约束字面量） */
export interface AiConfig {
  /** 云端大模型对话接口地址（OpenAI 兼容格式） */
  baseUrl: string;
  /** 模型名 */
  model: string;
  /** 凭证（API Key）：请填入你自己的密钥 */
  apiKey: string;
  /** 是否启用（与设置页开关联合判断） */
  enabled: boolean;
}

export const AI_CONFIG: AiConfig = {
  baseUrl: 'https://api.deepseek.com/v1/chat/completions',
  model: 'deepseek-chat',
  /**
   * 在这里填入你的 API Key，例如 'sk-xxxxxxxxxxxxxxxxxxxxxxxx'。
   * 提交包中默认为空串，属于正常状态：未填写时 AI 功能会进入降级态。
   */
  apiKey: '',
  enabled: true
};

/**
 * 判断凭证是否已配置。
 * 同时拦截空串与占位符，防止把模板内容当成真凭证发请求。
 */
export function hasApiKey(): boolean {
  const k: string = AI_CONFIG.apiKey;
  if (k.length < 20) {
    return false;
  }
  if (k.indexOf('请填入') >= 0 || k.indexOf('xxxxxxxx') >= 0) {
    return false;
  }
  return true;
}
