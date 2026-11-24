/**
 * 通用状态占位视图
 * 用于「空数据 / 搜索无结果 / 加载失败」三类状态，保证各页面提示样式一致。
 */
@Component
export struct StateView {
  title: ResourceStr = '';
  desc: ResourceStr = '';
  showRetry: boolean = false;
  onRetry: () => void = () => {
  };

  build() {
    Column({ space: 10 }) {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
        .textAlign(TextAlign.Center)

      Text(this.desc)
        .fontSize(13)
        .fontColor($r('app.color.secondary_text'))
        .textAlign(TextAlign.Center)
        .lineHeight(20)

      if (this.showRetry) {
        Button($r('app.string.action_retry'))
          .fontSize(14)
          .height(36)
          .width(120)
          .margin({ top: 8 })
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor($r('app.color.white'))
          .onClick(() => {
            this.onRetry();
          })
      }
    }
    .width('100%')
    .padding({ left: 32, right: 32, top: 64, bottom: 64 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }
}
