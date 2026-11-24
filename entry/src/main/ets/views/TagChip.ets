/**
 * 标签小胶囊
 */
@Component
export struct TagChip {
  text: string = '';
  onRemove: () => void = () => {
  };
  removable: boolean = false;

  build() {
    Row({ space: 4 }) {
      Text(this.text)
        .fontSize(11)
        .fontColor($r('app.color.tag_text'))
      if (this.removable) {
        Text('×')
          .fontSize(13)
          .fontColor($r('app.color.secondary_text'))
          .onClick(() => {
            this.onRemove();
          })
      }
    }
    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
    .backgroundColor($r('app.color.tag_background'))
    .borderRadius(6)
  }
}
