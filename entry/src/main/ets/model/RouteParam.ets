/**
 * 路由参数
 * Navigation 的参数统一用「强类型类实例」传递，避免裸 number/string 在
 * @kit.ArkUI 的类型约束下丢失语义，也便于页面侧做非法参数判定。
 */

export class NoteRouteParam {
  /** 笔记主键：0 或负数表示新建 */
  noteId: number = 0;

  constructor(noteId: number) {
    this.noteId = noteId;
  }
}
