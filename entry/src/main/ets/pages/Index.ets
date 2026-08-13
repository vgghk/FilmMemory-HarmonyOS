import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { dataSharePredicates } from '@kit.ArkData';
import { FilmStore } from '../store/FilmStore';
import {
  CAMERA_PRESETS, coverPresetIndex, FILM_PRESETS, FILM_TYPES, FilmPreset, LENS_PRESETS,
  presetCover, Roll, STATUS_FINISHED, STATUS_SHOOTING
} from '../model/Roll';
import { FilmColors, FilmRadii } from '../theme/FilmTheme';

const SCREEN_HOME: string = 'home';
const SCREEN_FORM: string = 'form';
const SCREEN_DETAIL: string = 'detail';
const SCREEN_PREVIEW: string = 'preview';
const SCREEN_DATE: string = 'date';
const SCREEN_GALLERY: string = 'gallery';

@Entry
@Component
struct Index {
  @State rolls: Roll[] = [];
  @State screen: string = SCREEN_HOME;
  @State selectedId: string = '';
  @State filter: string = '全部';
  @State editing: boolean = false;
  @State draft: Roll = Roll.create();
  @State previewUri: string = '';
  @State loaded: boolean = false;
  @State dateMode: string = 'single';
  @State dateStart: Date = new Date();
  @State dateEnd: Date = new Date();
  @State previewIndex: number = 0;
  @State previewScale: number = 1;
  @State previewBaseScale: number = 1;
  @State previewOffsetX: number = 0;
  @State previewOffsetY: number = 0;
  @State previewBaseX: number = 0;
  @State previewBaseY: number = 0;
  @State previewRotation: number = 0;
  @State previewControls: boolean = true;
  @State galleryBackScreen: string = SCREEN_DETAIL;
  @State formRevision: number = 0;
  @State dataRevision: number = 0;
  @State selectedStatus: string = STATUS_SHOOTING;
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    this.rolls = await FilmStore.load(this.context);
    const selected = this.rolls.find((roll: Roll) => roll.id === this.selectedId);
    if (selected) {
      this.selectedStatus = selected.status;
    }
    this.loaded = true;
  }

  onBackPress(): boolean {
    if (this.screen !== SCREEN_HOME) {
      this.goBack();
      return true;
    }
    return false;
  }

  private currentRoll(): Roll | undefined {
    // Custom-class fields are not observed deeply; this revision makes every persisted
    // replacement invalidate detail/gallery builders immediately.
    this.dataRevision;
    return this.rolls.find((roll: Roll) => roll.id === this.selectedId);
  }

  private visibleRolls(): Roll[] {
    if (this.filter === STATUS_SHOOTING || this.filter === STATUS_FINISHED) {
      return this.rolls.filter((roll: Roll) => roll.status === this.filter);
    }
    return this.rolls;
  }

  private async persist(next: Roll[]): Promise<void> {
    const snapshot = next.map((roll: Roll) => Roll.clone(roll));
    this.rolls = snapshot;
    this.dataRevision += 1;
    await FilmStore.save(this.context, snapshot);
  }

  private openNew(): void {
    this.draft = Roll.create();
    this.editing = false;
    this.formRevision += 1;
    this.screen = SCREEN_FORM;
  }

  private openEdit(roll: Roll): void {
    this.draft = Roll.clone(roll);
    this.editing = true;
    this.formRevision += 1;
    this.screen = SCREEN_FORM;
  }

  private openDetail(roll: Roll): void {
    this.selectedId = roll.id;
    this.selectedStatus = roll.status;
    this.screen = SCREEN_DETAIL;
  }

  private openGallery(roll: Roll, backScreen: string): void {
    this.selectedId = roll.id;
    this.selectedStatus = roll.status;
    if (roll.status !== STATUS_FINISHED) {
      this.getUIContext().getPromptAction().showToast({ message: '这卷仍在拍摄中，请先完成拍摄并标记为冲洗完' });
      this.screen = SCREEN_DETAIL;
      return;
    }
    if (roll.photos.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '这卷还没有照片，请先导入照片' });
      this.screen = SCREEN_DETAIL;
      return;
    }
    this.galleryBackScreen = backScreen;
    this.screen = SCREEN_GALLERY;
  }

  private deletePhotoFiles(uri: string): void {
    try {
      fileIo.unlinkSync(uri);
    } catch (_) {}
    try {
      fileIo.unlinkSync(`${uri}.name`);
    } catch (_) {}
    try {
      fileIo.unlinkSync(`${uri}.rotation`);
    } catch (_) {}
  }

  private async copySelectedPhoto(sourceUri: string, destination: string): Promise<string> {
    const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
    const predicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo(photoAccessHelper.PhotoKeys.URI, sourceUri);
    const fetchResult = await helper.getAssets({
      fetchColumns: [photoAccessHelper.PhotoKeys.DISPLAY_NAME],
      predicates: predicates
    });
    try {
      const asset = await fetchResult.getFirstObject();
      const sourceFile = fileIo.openSync(asset.uri, fileIo.OpenMode.READ_ONLY);
      const destinationFile = fileIo.openSync(destination,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.copyFile(sourceFile.fd, destinationFile.fd);
      } finally {
        fileIo.closeSync(sourceFile);
        fileIo.closeSync(destinationFile);
      }
      return asset.displayName;
    } finally {
      fetchResult.close();
    }
  }

  private async saveDraft(): Promise<void> {
    const name = this.draft.name.trim();
    if (name.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请填写胶片名称' });
      return;
    }
    this.draft.name = name;
    this.draft.updatedAt = Date.now();
    if (this.editing) {
      await this.persist(this.rolls.map((roll: Roll) => roll.id === this.draft.id ? this.draft : roll));
    } else {
      await this.persist([this.draft, ...this.rolls]);
    }
    this.selectedId = this.draft.id;
    this.selectedStatus = this.draft.status;
    this.screen = SCREEN_DETAIL;
  }

  private async updateRoll(updated: Roll): Promise<void> {
    updated.updatedAt = Date.now();
    await this.persist(this.rolls.map((roll: Roll) => roll.id === updated.id ? updated : roll));
  }

  private async deleteCurrentRoll(): Promise<void> {
    const roll = this.currentRoll();
    if (!roll) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除这卷胶片？',
      message: '胶卷记录会被永久删除，已导入到应用的照片副本也将不再显示。此操作无法撤销。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认删除',
        fontColor: FilmColors.danger,
        action: async () => {
          roll.photos.forEach((uri: string) => this.deletePhotoFiles(uri));
          if (roll.cover.length > 0 && !roll.cover.startsWith('preset:') && !roll.photos.includes(roll.cover)) {
            this.deletePhotoFiles(roll.cover);
          }
          await this.persist(this.rolls.filter((item: Roll) => item.id !== roll.id));
          this.screen = SCREEN_HOME;
        }
      }
    });
  }

  private async setStatus(status: string): Promise<void> {
    const roll = this.currentRoll();
    if (!roll || roll.status === status) {
      return;
    }
    const updated = Roll.clone(roll);
    updated.status = status;
    this.selectedStatus = status;
    await this.updateRoll(updated);
    if (status === STATUS_FINISHED && updated.photos.length === 0) {
      this.getUIContext().showAlertDialog({
        title: '胶卷已冲洗完成',
        message: '现在导入这卷胶片的照片吗？你也可以稍后再添加。',
        primaryButton: { value: '稍后再说', action: () => {} },
        secondaryButton: { value: '立即导入', action: () => { this.pickPhotos(); } }
      });
    }
  }

  private async pickPhotos(): Promise<void> {
    const roll = this.currentRoll();
    if (!roll) {
      return;
    }
    const remaining = Math.max(0, 50 - roll.photos.length);
    if (remaining === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '这卷胶片已达到 50 张照片上限' });
      return;
    }
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = remaining;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      const imported: string[] = [];
      let failed: number = 0;
      for (let index = 0; index < result.photoUris.length; index++) {
        const source = result.photoUris[index];
        const destination = `${this.context.filesDir}/film_${roll.id}_${Date.now()}_${index}.jpg`;
        try {
          const displayName = await this.copySelectedPhoto(source, destination);
          const meta = fileIo.openSync(`${destination}.name`,
            fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
          fileIo.writeSync(meta.fd, displayName);
          fileIo.closeSync(meta);
          imported.push(destination);
        } catch (_) {
          failed += 1;
          this.deletePhotoFiles(destination);
        }
      }
      if (imported.length > 0) {
        const updated = Roll.clone(roll);
        updated.photos = this.sortPhotoPaths([...updated.photos, ...imported]);
        if (updated.cover.length === 0) {
          updated.cover = imported[0];
        }
        await this.updateRoll(updated);
        this.getUIContext().getPromptAction().showToast({ message: `已导入 ${imported.length} 张照片` });
      } else if (failed > 0) {
        this.getUIContext().showAlertDialog({
          title: '照片导入失败',
          message: '已选照片无法复制到应用本地，请重新选择后再试。',
          primaryButton: { value: '知道了', action: () => {} }
        });
      }
    } catch (_) {
      this.getUIContext().showAlertDialog({
        title: '无法打开照片选择器',
        message: '系统照片服务暂时不可用，请稍后再试。',
        primaryButton: { value: '知道了', action: () => {} }
      });
    }
  }

  private async pickCover(): Promise<void> {
    const roll = this.currentRoll();
    if (!roll) {
      return;
    }
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      const destination = `${this.context.filesDir}/cover_${roll.id}_${Date.now()}.jpg`;
      await this.copySelectedPhoto(result.photoUris[0], destination);
      const updated = Roll.clone(roll);
      const oldCover = updated.cover;
      updated.cover = destination;
      await this.updateRoll(updated);
      if (oldCover.length > 0 && !oldCover.startsWith('preset:') && !updated.photos.includes(oldCover)) {
        try {
          fileIo.unlinkSync(oldCover);
        } catch (_) {}
      }
    } catch (_) {
      // Closing the system picker is a normal cancel operation.
    }
  }

  private async setCover(value: string): Promise<void> {
    const roll = this.currentRoll();
    if (!roll || roll.cover === value) {
      return;
    }
    const updated = Roll.clone(roll);
    const oldCover = updated.cover;
    updated.cover = value;
    await this.updateRoll(updated);
    if (oldCover.length > 0 && !oldCover.startsWith('preset:') && !updated.photos.includes(oldCover)) {
      try {
        fileIo.unlinkSync(oldCover);
      } catch (_) {}
    }
  }

  private async deletePhoto(uri: string): Promise<void> {
    const roll = this.currentRoll();
    if (!roll) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除这张照片？',
      message: '照片会从这卷胶片中移除，此操作无法撤销。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确认删除',
        fontColor: FilmColors.danger,
        action: async () => {
          const updated = Roll.clone(roll);
          updated.photos = updated.photos.filter((photo: string) => photo !== uri);
          if (updated.cover === uri) {
            updated.cover = updated.photos.length > 0 ? updated.photos[0] : '';
          }
          this.deletePhotoFiles(uri);
          await this.updateRoll(updated);
          if (updated.photos.length === 0) {
            this.previewUri = '';
            this.screen = SCREEN_DETAIL;
          } else {
            this.previewIndex = Math.min(this.previewIndex, updated.photos.length - 1);
            this.previewUri = updated.photos[this.previewIndex];
            this.previewRotation = this.photoRotation(this.previewUri);
          }
        }
      }
    });
  }

  private photoName(path: string): string {
    try {
      return fileIo.readTextSync(`${path}.name`).trim();
    } catch (_) {
      return path.substring(path.lastIndexOf('/') + 1);
    }
  }

  private sortPhotoPaths(paths: string[]): string[] {
    return paths.sort((left: string, right: string) =>
      this.photoName(left).localeCompare(this.photoName(right), 'zh-CN', { numeric: true, sensitivity: 'base' }));
  }

  private photoRotation(path: string): number {
    try {
      const value = Number(fileIo.readTextSync(`${path}.rotation`).trim());
      return Number.isFinite(value) ? value : 0;
    } catch (_) {
      return 0;
    }
  }

  private rotateCurrentPhoto(): void {
    const roll = this.currentRoll();
    const path = roll?.photos[this.previewIndex];
    if (!path) {
      return;
    }
    this.previewRotation = (this.previewRotation + 90) % 360;
    try {
      const meta = fileIo.openSync(`${path}.rotation`, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(meta.fd, `${this.previewRotation}`);
      fileIo.closeSync(meta);
    } catch (_) {}
  }

  private openPreview(index: number): void {
    const roll = this.currentRoll();
    if (!roll || index < 0 || index >= roll.photos.length) {
      return;
    }
    this.previewIndex = index;
    this.previewUri = roll.photos[index];
    this.previewRotation = this.photoRotation(this.previewUri);
    this.previewScale = 1;
    this.previewOffsetX = 0;
    this.previewOffsetY = 0;
    this.previewControls = true;
    this.screen = SCREEN_PREVIEW;
  }

  private goBack(): void {
    if (this.screen === SCREEN_PREVIEW) {
      this.screen = SCREEN_GALLERY;
    } else if (this.screen === SCREEN_GALLERY) {
      this.screen = this.galleryBackScreen;
    } else if (this.screen === SCREEN_DATE) {
      this.screen = SCREEN_FORM;
    } else if (this.screen === SCREEN_FORM && this.editing) {
      this.screen = SCREEN_DETAIL;
    } else {
      this.screen = SCREEN_HOME;
    }
  }

  private formatDate(value: Date): string {
    return `${value.getFullYear()}.${`${value.getMonth() + 1}`.padStart(2, '0')}.${`${value.getDate()}`.padStart(2, '0')}`;
  }

  private parseDate(value: string): Date | undefined {
    const match = value.trim().match(new RegExp('^(\\d{4})\\.(\\d{2})\\.(\\d{2})$'));
    if (!match) {
      return undefined;
    }
    const parsed = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
    return Number.isNaN(parsed.getTime()) ? undefined : parsed;
  }

  private openDatePicker(mode: string): void {
    this.getUIContext().getFocusController().clearFocus();
    const parts = this.draft.date.split(new RegExp('\\s+[–-]\\s+'));
    const fallback = new Date();
    this.dateMode = mode;
    this.dateStart = this.parseDate(parts[0] ?? '') ?? fallback;
    this.dateEnd = this.parseDate(parts[1] ?? '') ?? this.dateStart;
    this.screen = SCREEN_DATE;
  }

  private applyDateSelection(): void {
    if (this.dateMode === 'range') {
      const start = this.dateStart.getTime() <= this.dateEnd.getTime() ? this.dateStart : this.dateEnd;
      const end = this.dateStart.getTime() <= this.dateEnd.getTime() ? this.dateEnd : this.dateStart;
      this.draft.date = start.getTime() === end.getTime() ? this.formatDate(start) : `${this.formatDate(start)} – ${this.formatDate(end)}`;
    } else {
      this.draft.date = this.formatDate(this.dateStart);
    }
    this.draft = Roll.clone(this.draft);
    this.screen = SCREEN_FORM;
  }

  @Builder
  private PageHeader(title: string, back: boolean = false) {
    Row({ space: 10 }) {
      if (back) {
        Button() {
          this.AppIcon($r('sys.symbol.chevron_left'), '返回', FilmColors.primary, 26)
        }
          .width(48)
          .height(48)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.goBack())
      }
      Column({ space: 2 }) {
        Text(title)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(FilmColors.ink)
        if (!back) {
          Text('Film Memory')
            .fontSize(15)
            .fontColor(FilmColors.secondary)
            .letterSpacing(1.4)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private PrimaryButton(label: string, action: () => void, enabled: boolean = true) {
    Button() {
      Row({ space: 8 }) {
        if (label.includes('新增')) {
          this.AppIcon($r('sys.symbol.plus'), label, FilmColors.white, 19)
        } else if (label.includes('保存')) {
          this.AppIcon($r('sys.symbol.checkmark'), label, FilmColors.white, 19)
        }
        Text(label.startsWith('+ ') ? label.substring(2) : label)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(FilmColors.white)
      }
    }
      .width('100%')
      .height(56)
      .backgroundColor(enabled ? FilmColors.primary : '#BFCED8')
      .borderRadius(FilmRadii.control)
      .enabled(enabled)
      .onClick(action)
  }

  @Builder
  private StatusPill(status: string) {
    Text(status)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(status === STATUS_FINISHED ? FilmColors.finished : FilmColors.shooting)
      .backgroundColor(status === STATUS_FINISHED ? FilmColors.finishedSoft : FilmColors.shootingSoft)
      .borderRadius(FilmRadii.pill)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
  }

  @Builder
  private ChoicePill(label: string, selected: boolean, action: () => void) {
    Button(label)
      .fontSize(14)
      .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(selected ? FilmColors.ink : FilmColors.muted)
      .backgroundColor(selected ? FilmColors.primarySoft : FilmColors.surface)
      .border({ width: 1, color: selected ? FilmColors.primary : FilmColors.outline })
      .borderRadius(FilmRadii.control)
      .padding({ left: 16, right: 16, top: 11, bottom: 11 })
      .stateEffect(true)
      .onClick(action)
  }

  @Builder
  private AppIcon(symbol: Resource, label: string, color: ResourceColor = FilmColors.primary, size: number = 24) {
    SymbolGlyph(symbol)
      .fontColor([color])
      .fontSize(size)
      .accessibilityText(label)
  }

  @Builder
  private IconTextButton(symbol: Resource, label: string, action: () => void,
    color: ResourceColor = FilmColors.primary, background: ResourceColor = FilmColors.primarySoft) {
    Button() {
      Row({ space: 6 }) {
        this.AppIcon(symbol, label, color, 18)
        Text(label).fontSize(14).fontColor(color)
      }
    }
      .height(44)
      .backgroundColor(background)
      .borderRadius(FilmRadii.control)
      .stateEffect(true)
      .onClick(action)
  }

  @Builder
  private PresetCover(index: number, height: number) {
    if (index === 0) {
      Image($r('app.media.film_cover_0')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else if (index === 1) {
      Image($r('app.media.film_cover_1')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else if (index === 2) {
      Image($r('app.media.film_cover_2')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else if (index === 3) {
      Image($r('app.media.film_cover_3')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else if (index === 4) {
      Image($r('app.media.film_cover_4')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else if (index === 5) {
      Image($r('app.media.film_cover_5')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else if (index === 6) {
      Image($r('app.media.film_cover_6')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else if (index === 7) {
      Image($r('app.media.film_cover_7')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else if (index === 8) {
      Image($r('app.media.film_cover_8')).width('100%').height(height).objectFit(ImageFit.Contain)
    } else {
      Image($r('app.media.film_cover_9')).width('100%').height(height).objectFit(ImageFit.Contain)
    }
  }

  @Builder
  private FieldLabel(label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(FilmColors.muted)
  }

  @Builder
  private TextField(label: string, value: string, placeholder: string, change: (value: string) => void) {
    Column({ space: 8 }) {
      this.FieldLabel(label)
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(52)
        .fontSize(16)
        .fontColor(FilmColors.ink)
        .placeholderColor('#9AA8B4')
        .backgroundColor(FilmColors.surface)
        .border({ width: 1, color: FilmColors.outline })
        .borderRadius(FilmRadii.control)
        .padding({ left: 16, right: 16 })
        .onChange(change)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private HeroCard() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column({ space: 12 }) {
        Row() {
          Text('记录每一卷胶片')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(FilmColors.ink)
          Blank()
          this.AppIcon($r('sys.symbol.camera'), '相机', FilmColors.primary, 46)
        }
        Text('珍藏每一刻光影，让冲洗后的记忆有迹可循。')
          .fontSize(14)
          .fontColor(FilmColors.muted)
          .maxLines(2)
        Row({ space: 8 }) {
          Text(`${this.rolls.filter((roll: Roll) => roll.status === STATUS_FINISHED).length}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(FilmColors.finished)
          Text('卷已冲洗完成')
            .fontSize(13)
            .fontColor(FilmColors.muted)
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .backgroundColor(FilmColors.primarySoft)
    .borderRadius(FilmRadii.card)
    .border({ width: 1, color: FilmColors.outline })
  }

  @Builder
  private EmptyRolls() {
    Column({ space: 12 }) {
      this.AppIcon($r('sys.symbol.camera'), '胶卷档案', FilmColors.primary, 48)
      Text(this.filter === '全部' ? '还没有胶卷记录' : `没有“${this.filter}”的胶卷`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(FilmColors.ink)
      Text('从第一卷胶片开始，慢慢积累你的光影记忆。')
        .fontSize(14)
        .fontColor(FilmColors.muted)
        .textAlign(TextAlign.Center)
      Button() {
        Row({ space: 7 }) {
          this.AppIcon($r('sys.symbol.plus'), '新增胶卷', FilmColors.white, 18)
          Text('新增胶卷').fontColor(FilmColors.white)
        }
      }
        .height(48)
        .backgroundColor(FilmColors.primary)
        .borderRadius(FilmRadii.control)
        .onClick(() => this.openNew())
    }
    .width('100%')
    .padding({ top: 36, bottom: 36, left: 24, right: 24 })
    .backgroundColor(FilmColors.surface)
    .border({ width: 1, color: FilmColors.outline })
    .borderRadius(FilmRadii.card)
  }

  @Builder
  private RollCover(roll: Roll, height: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (coverPresetIndex(roll.cover) >= 0) {
        this.PresetCover(coverPresetIndex(roll.cover), height)
      } else if (roll.cover.length > 0) {
        Image(roll.cover)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column({ space: 8 }) {
          this.AppIcon($r('sys.symbol.camera'), '胶卷封面', FilmColors.primary, 48)
          Text(roll.type)
            .fontSize(13)
            .fontColor(FilmColors.muted)
        }
      }
    }
    .width('100%')
    .height(height)
    .backgroundColor(FilmColors.primarySoft)
  }

  @Builder
  private RollCard(roll: Roll) {
    Column() {
      Stack() {
        this.RollCover(roll, 168)
      }
      .width('100%')
      .height(168)
      .onClick(() => this.openGallery(roll, SCREEN_HOME))
      Row({ space: 12 }) {
        Column({ space: 7 }) {
          Text(roll.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(FilmColors.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${roll.type} · ${roll.date.length > 0 ? roll.date : '未填写日期'}`)
            .fontSize(13)
            .fontColor(FilmColors.muted)
            .maxLines(1)
          this.StatusPill(roll.status)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column({ space: 8 }) {
          Text(`${roll.photos.length} 张`)
            .fontSize(13)
            .fontColor(FilmColors.muted)
          this.AppIcon($r('sys.symbol.chevron_right'), '打开胶卷详情', FilmColors.primary, 22)
        }
      }
      .width('100%')
      .padding(16)
      .alignItems(VerticalAlign.Top)
      .onClick(() => this.openDetail(roll))
    }
    .width('100%')
    .backgroundColor(FilmColors.surface)
    .border({ width: 1, color: FilmColors.outline })
    .borderRadius(FilmRadii.card)
    .clip(true)
  }

  @Builder
  private HomePage() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          this.PageHeader('胶片记忆')
          Text('记录每卷胶片的慢时光')
            .fontSize(14)
            .fontColor(FilmColors.muted)
            .width('100%')
          this.PrimaryButton('+ 新增胶卷', () => this.openNew())
          this.HeroCard()
          Text('最近的胶卷')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(FilmColors.ink)
            .width('100%')
          Scroll() {
            Row({ space: 8 }) {
              ForEach(['全部', STATUS_SHOOTING, STATUS_FINISHED], (item: string) => {
                this.ChoicePill(item, this.filter === item, () => this.filter = item)
              })
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          if (this.visibleRolls().length === 0) {
            this.EmptyRolls()
          } else {
            ForEach(this.visibleRolls(), (roll: Roll) => {
              this.RollCard(roll)
            }, (roll: Roll) => roll.id)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 36 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private FormPage() {
    Column() {
      Scroll() {
        Column({ space: 18 }) {
          this.PageHeader(this.editing ? '编辑胶卷' : '新增胶卷', true)
          this.FieldLabel('常用胶卷')
          Scroll() {
            Row({ space: 10 }) {
              ForEach(FILM_PRESETS, (preset: FilmPreset) => {
                Column({ space: 6 }) {
                  this.PresetCover(preset.coverIndex, 86)
                  Text(preset.name)
                    .width('100%')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(FilmColors.ink)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(preset.type)
                    .width('100%')
                    .fontSize(11)
                    .fontColor(FilmColors.muted)
                    .maxLines(1)
                }
                .width(132)
                .padding(8)
                .backgroundColor(this.draft.cover === presetCover(preset.coverIndex) ? FilmColors.primarySoft : FilmColors.surface)
                .border({ width: 1, color: this.draft.cover === presetCover(preset.coverIndex) ? FilmColors.primary : FilmColors.outline })
                .borderRadius(FilmRadii.control)
                .onClick(() => {
                  this.draft.name = preset.name;
                  this.draft.type = preset.type;
                  this.draft.cover = presetCover(preset.coverIndex);
                  this.draft = Roll.clone(this.draft);
                })
              }, (preset: FilmPreset) => preset.name)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          Column({ space: 8 }) {
            this.FieldLabel('胶片名称 *')
            TextInput({ text: this.draft.name, placeholder: '例如 Kodak Portra 400' })
              .id(`roll_name_${this.formRevision}_${this.draft.cover}`)
              .width('100%')
              .height(52)
              .fontSize(16)
              .fontColor(FilmColors.ink)
              .placeholderColor('#9AA8B4')
              .backgroundColor(FilmColors.surface)
              .border({ width: 1, color: FilmColors.outline })
              .borderRadius(FilmRadii.control)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.draft.name = value;
                this.draft = Roll.clone(this.draft);
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          this.FieldLabel('胶片类型')
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Start }) {
            ForEach(FILM_TYPES, (item: string) => {
              this.ChoicePill(item, this.draft.type === item, () => {
                this.draft.type = item;
                this.draft = Roll.clone(this.draft);
              })
            })
          }
          this.TextField('拍摄日期', this.draft.date, '2026.08.13 或 2026.08.13 - 2026.08.20', (value: string) => {
            this.draft.date = value;
            this.draft = Roll.clone(this.draft);
          })
          Row({ space: 8 }) {
            this.ChoicePill('选择一天', this.draft.date.length > 0 && !this.draft.date.includes('–') && !this.draft.date.includes(' - '), () => this.openDatePicker('single'))
            this.ChoicePill('今天', this.draft.date === this.formatDate(new Date()), () => {
              const now = new Date();
              this.draft.date = this.formatDate(now);
              this.draft = Roll.clone(this.draft);
            })
            this.ChoicePill('日期范围', this.draft.date.includes('–') || this.draft.date.includes(' - '), () => this.openDatePicker('range'))
          }
          this.TextField('拍摄地点', this.draft.place, '例如 上海 · 武康路', (value: string) => {
            this.draft.place = value;
            this.draft = Roll.clone(this.draft);
          })
          this.TextField('使用的相机', this.draft.camera, '例如 Leica M6', (value: string) => {
            this.draft.camera = value;
            this.draft = Roll.clone(this.draft);
          })
          Scroll() {
            Row({ space: 8 }) {
              ForEach(CAMERA_PRESETS.slice(0, 6), (item: string) => {
                this.ChoicePill(item, this.draft.camera === item, () => {
                  this.draft.camera = item;
                  this.draft = Roll.clone(this.draft);
                })
              })
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          this.TextField('镜头', this.draft.lens, '例如 50mm f/1.8', (value: string) => {
            this.draft.lens = value;
            this.draft = Roll.clone(this.draft);
          })
          Scroll() {
            Row({ space: 8 }) {
              ForEach(LENS_PRESETS.slice(0, 6), (item: string) => {
                this.ChoicePill(item, this.draft.lens === item, () => {
                  this.draft.lens = item;
                  this.draft = Roll.clone(this.draft);
                })
              })
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          Column({ space: 8 }) {
            this.FieldLabel('备注')
            TextArea({ text: this.draft.note, placeholder: '记录天气、心情或这卷胶片的故事' })
              .width('100%')
              .height(112)
              .fontSize(16)
              .fontColor(FilmColors.ink)
              .backgroundColor(FilmColors.surface)
              .border({ width: 1, color: FilmColors.outline })
              .borderRadius(FilmRadii.control)
              .padding(14)
              .onChange((value: string) => {
                this.draft.note = value;
                this.draft = Roll.clone(this.draft);
              })
          }
          .alignItems(HorizontalAlign.Start)
          this.FieldLabel('状态')
          Row({ space: 8 }) {
            this.ChoicePill(STATUS_SHOOTING, this.draft.status === STATUS_SHOOTING, () => {
              this.draft.status = STATUS_SHOOTING;
              this.draft = Roll.clone(this.draft);
            })
            this.ChoicePill(STATUS_FINISHED, this.draft.status === STATUS_FINISHED, () => {
              this.draft.status = STATUS_FINISHED;
              this.draft = Roll.clone(this.draft);
            })
          }
          if (this.draft.status === STATUS_FINISHED) {
            Column({ space: 14 }) {
              this.FieldLabel('冲洗信息')
              this.TextField('冲洗店', this.draft.lab, '例如 某某冲洗店', (value: string) => {
                this.draft.lab = value;
                this.draft = Roll.clone(this.draft);
              })
              this.TextField('冲洗日期', this.draft.developedDate, '例如 2026.08.13', (value: string) => {
                this.draft.developedDate = value;
                this.draft = Roll.clone(this.draft);
              })
              this.TextField('扫描仪', this.draft.scanner, '例如 Noritsu HS-1800', (value: string) => {
                this.draft.scanner = value;
                this.draft = Roll.clone(this.draft);
              })
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(FilmColors.surface)
            .border({ width: 1, color: FilmColors.outline })
            .borderRadius(FilmRadii.card)
          }
          this.PrimaryButton('保存这卷胶片', () => this.saveDraft(), this.draft.name.trim().length > 0)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 40 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  private DateSelectionPage() {
    Column() {
      Scroll() {
        Column({ space: 18 }) {
          this.PageHeader('选择拍摄日期', true)
          Text('可记录某一天，也可记录一段拍摄时间。')
            .fontSize(14)
            .fontColor(FilmColors.muted)
            .width('100%')
          Row({ space: 8 }) {
            this.ChoicePill('某一天', this.dateMode === 'single', () => {
              this.dateMode = 'single';
            })
            this.ChoicePill('一段时间', this.dateMode === 'range', () => {
              this.dateMode = 'range';
            })
          }
          Column({ space: 10 }) {
            this.FieldLabel(this.dateMode === 'range' ? '开始日期' : '拍摄日期')
            DatePicker({
              start: new Date(1970, 0, 1),
              end: new Date(2100, 11, 31),
              selected: this.dateStart
            })
              .lunar(false)
              .onDateChange((value: Date) => {
                this.dateStart = value;
                if (this.dateMode === 'single') {
                  this.dateEnd = value;
                }
              })
          }
          .width('100%')
          .padding(18)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(FilmColors.surface)
          .border({ width: 1, color: FilmColors.outline })
          .borderRadius(FilmRadii.card)
          if (this.dateMode === 'range') {
            Column({ space: 10 }) {
              this.FieldLabel('结束日期')
              DatePicker({
                start: new Date(1970, 0, 1),
                end: new Date(2100, 11, 31),
                selected: this.dateEnd
              })
                .lunar(false)
                .onDateChange((value: Date) => {
                  this.dateEnd = value;
                })
            }
            .width('100%')
            .padding(18)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(FilmColors.surface)
            .border({ width: 1, color: FilmColors.outline })
            .borderRadius(FilmRadii.card)
          }
          Text(this.dateMode === 'range'
            ? `${this.formatDate(this.dateStart)} – ${this.formatDate(this.dateEnd)}`
            : this.formatDate(this.dateStart))
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(FilmColors.ink)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 18 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
      Column() {
        this.PrimaryButton('确定', () => this.applyDateSelection())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 20 })
      .backgroundColor(FilmColors.background)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private DetailLine(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(12)
        .fontColor(FilmColors.muted)
      Text(value.length > 0 ? value : '未填写')
        .fontSize(16)
        .fontColor(FilmColors.ink)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private PhotoGrid(roll: Roll) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('这一卷的照片')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(FilmColors.ink)
          Text(`${roll.photos.length} 张`)
            .fontSize(13)
            .fontColor(FilmColors.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (roll.photos.length > 0) {
          this.IconTextButton($r('sys.symbol.ohos_photo'), '查看图库', () => this.openGallery(roll, SCREEN_DETAIL))
        }
        if (roll.status === STATUS_FINISHED) {
          this.IconTextButton($r('sys.symbol.ohos_folder_badge_plus'), '添加照片', () => this.pickPhotos())
        }
      }
      .width('100%')
      if (roll.photos.length === 0) {
        Column({ space: 10 }) {
          this.AppIcon($r('sys.symbol.ohos_photo'), '照片为空', FilmColors.primary, 48)
          Text(roll.status === STATUS_FINISHED ? '还没有导入照片' : '冲洗完成后再来添加成片')
            .fontSize(15)
            .fontColor(FilmColors.muted)
          if (roll.status === STATUS_FINISHED) {
            this.IconTextButton($r('sys.symbol.ohos_folder_badge_plus'), '导入照片', () => this.pickPhotos(),
              FilmColors.white, FilmColors.primary)
          }
        }
        .width('100%')
        .padding({ top: 30, bottom: 30 })
        .backgroundColor(FilmColors.surface)
        .border({ width: 1, color: FilmColors.outline })
        .borderRadius(FilmRadii.card)
      } else {
        Grid() {
          ForEach(roll.photos, (uri: string) => {
            GridItem() {
              Image(uri)
                .width('100%')
                .height(164)
                .objectFit(ImageFit.Cover)
                .borderRadius(FilmRadii.image)
                .onClick(() => {
                  this.openPreview(roll.photos.indexOf(uri));
                })
            }
          }, (uri: string) => uri)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .height(Math.ceil(roll.photos.length / 2) * 174)
        .width('100%')
      }
      if (roll.status !== STATUS_FINISHED) {
        Text('拍摄中不可导入照片，完成冲洗后可随时添加。').fontSize(12).fontColor(FilmColors.muted)
      } else if (roll.photos.length >= 50) {
        Text('这卷胶片已达到 50 张照片上限。').fontSize(12).fontColor(FilmColors.muted)
      } else if (roll.photos.length > 0) {
        Text(`还可导入 ${50 - roll.photos.length} 张照片`).fontSize(12).fontColor(FilmColors.muted)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private GalleryPage() {
    if (this.currentRoll()) {
      Column() {
        Row({ space: 10 }) {
          Button() {
            this.AppIcon($r('sys.symbol.chevron_left'), '返回详情', FilmColors.primary, 26)
          }
          .width(48).height(48).backgroundColor(Color.Transparent)
          .onClick(() => this.goBack())
          Column({ space: 2 }) {
            Text((this.currentRoll() as Roll).name)
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(FilmColors.ink).maxLines(1)
            Text(`${(this.currentRoll() as Roll).date} · ${(this.currentRoll() as Roll).photos.length} 张`)
              .fontSize(12).fontColor(FilmColors.muted)
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .width('100%').padding({ left: 12, right: 16, top: 14, bottom: 8 })
        Scroll() {
          Column({ space: 14 }) {
            Text('连续胶片')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(FilmColors.ink).width('100%')
            Scroll() {
              Row() {
                Column({ space: 6 }) {
                  Text('FILM').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#1F140B')
                  Text('400').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1F140B')
                }
                .width(82).height(250).justifyContent(FlexAlign.Center)
                .backgroundColor('#B26B34').borderRadius({ topLeft: 16, bottomLeft: 16 })
                ForEach((this.currentRoll() as Roll).photos, (uri: string, index: number) => {
                  Column({ space: 4 }) {
                    Text('▰ ▰ ▰ ▰ ▰').fontSize(9).fontColor('#F1ECE3')
                    Row() {
                      Text(`${index + 1}`).fontSize(9).fontColor('#B26B34')
                      Blank()
                      Text('FILM 400').fontSize(9).fontColor('#B26B34')
                    }.width('100%')
                    Stack({ alignContent: Alignment.TopEnd }) {
                      Image(uri).width(218).height(146).objectFit(ImageFit.Cover)
                        .rotate({ angle: this.photoRotation(uri) })
                      if ((this.currentRoll() as Roll).cover === uri) {
                        this.AppIcon($r('sys.symbol.checkmark_circle_fill'), '封面', FilmColors.primary, 22)
                      }
                    }
                    .onClick(() => this.openPreview(index))
                    Row() {
                      Text('FM-400').fontSize(8).fontColor('#B26B34')
                      Blank()
                      Text(`${index + 1}A`).fontSize(8).fontColor('#B26B34')
                    }.width('100%')
                    Text('▰ ▰ ▰ ▰ ▰').fontSize(9).fontColor('#F1ECE3')
                  }
                  .width(232).height(250).padding({ left: 7, right: 7, top: 5, bottom: 5 })
                  .backgroundColor('#171917')
                }, (uri: string) => `film_${uri}`)
              }
            }
            .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            Text('缩略图')
              .fontSize(16).fontWeight(FontWeight.Medium).fontColor(FilmColors.ink).width('100%')
            Grid() {
              ForEach((this.currentRoll() as Roll).photos, (uri: string, index: number) => {
                GridItem() {
                  Image(uri).width('100%').height(94).objectFit(ImageFit.Cover).borderRadius(10)
                    .rotate({ angle: this.photoRotation(uri) })
                    .onClick(() => this.openPreview(index))
                }
              }, (uri: string) => `thumb_${uri}`)
            }
            .columnsTemplate('1fr 1fr 1fr').columnsGap(8).rowsGap(8)
            .height(Math.ceil((this.currentRoll() as Roll).photos.length / 3) * 102).width('100%')
          }
          .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 36 })
        }
        .scrollBar(BarState.Off).width('100%').layoutWeight(1)
      }
      .width('100%').height('100%')
    }
  }

  @Builder
  private DetailPage() {
    if (this.currentRoll()) {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            Row({ space: 8 }) {
              Button() {
                this.AppIcon($r('sys.symbol.chevron_left'), '返回首页', FilmColors.primary, 26)
              }
                .width(48).height(48).backgroundColor(Color.Transparent)
                .onClick(() => this.goBack())
              Text('胶卷详情')
                .fontSize(26).fontWeight(FontWeight.Bold).fontColor(FilmColors.ink)
                .layoutWeight(1)
              this.IconTextButton($r('sys.symbol.square_and_pencil'), '编辑',
                () => this.openEdit(this.currentRoll() as Roll))
              this.IconTextButton($r('sys.symbol.ohos_trash'), '删除', () => this.deleteCurrentRoll(),
                FilmColors.danger, FilmColors.dangerSoft)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            this.RollCover(this.currentRoll() as Roll, 220)
            Column({ space: 12 }) {
              this.FieldLabel('胶卷封面')
              Row({ space: 8 }) {
                this.IconTextButton($r('sys.symbol.ohos_photo'), '从相册选择', () => this.pickCover())
                if ((this.currentRoll() as Roll).cover.length > 0) {
                  this.IconTextButton($r('sys.symbol.xmark'), '取消当前封面', () => this.setCover(''),
                    FilmColors.danger, FilmColors.dangerSoft)
                }
              }
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(FILM_PRESETS, (preset: FilmPreset) => {
                    Stack({ alignContent: Alignment.Center }) {
                      this.PresetCover(preset.coverIndex, 88)
                      if ((this.currentRoll() as Roll).cover === presetCover(preset.coverIndex)) {
                        Row() {
                          this.AppIcon($r('sys.symbol.checkmark_circle_fill'), '已选择', FilmColors.white, 26)
                        }
                        .width('100%').height('100%')
                        .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
                        .backgroundColor('#33000000')
                      }
                    }
                    .width(68)
                    .height(92)
                    .border({ width: 2, color: (this.currentRoll() as Roll).cover === presetCover(preset.coverIndex) ? FilmColors.primary : FilmColors.outline })
                    .borderRadius(14)
                    .clip(true)
                    .onClick(() => this.setCover(presetCover(preset.coverIndex)))
                  }, (preset: FilmPreset) => `detail_${preset.name}`)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(FilmColors.surface)
            .border({ width: 1, color: FilmColors.outline })
            .borderRadius(FilmRadii.card)
            Column({ space: 10 }) {
              Text((this.currentRoll() as Roll).name)
                .fontSize(26).fontWeight(FontWeight.Bold).fontColor(FilmColors.ink)
              Text((this.currentRoll() as Roll).type)
                .fontSize(14).fontColor(FilmColors.muted)
              this.StatusPill(this.selectedStatus)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            this.FieldLabel('胶卷状态')
            Row({ space: 8 }) {
              this.ChoicePill(STATUS_SHOOTING, this.selectedStatus === STATUS_SHOOTING,
                () => this.setStatus(STATUS_SHOOTING))
              this.ChoicePill(STATUS_FINISHED, this.selectedStatus === STATUS_FINISHED,
                () => this.setStatus(STATUS_FINISHED))
            }
            Column({ space: 14 }) {
              this.FieldLabel('拍摄记录')
              this.DetailLine('拍摄日期', (this.currentRoll() as Roll).date)
              this.DetailLine('拍摄地点', (this.currentRoll() as Roll).place)
              this.DetailLine('相机', (this.currentRoll() as Roll).camera)
              this.DetailLine('镜头', (this.currentRoll() as Roll).lens)
              this.DetailLine('备注', (this.currentRoll() as Roll).note)
            }
            .width('100%')
            .padding(18)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(FilmColors.surface)
            .border({ width: 1, color: FilmColors.outline })
            .borderRadius(FilmRadii.card)
            if (this.selectedStatus === STATUS_FINISHED) {
              Column({ space: 14 }) {
                this.FieldLabel('冲洗信息')
                this.DetailLine('冲洗店', (this.currentRoll() as Roll).lab)
                this.DetailLine('冲洗日期', (this.currentRoll() as Roll).developedDate)
                this.DetailLine('扫描仪', (this.currentRoll() as Roll).scanner)
              }
              .width('100%')
              .padding(18)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor(FilmColors.surface)
              .border({ width: 1, color: FilmColors.outline })
              .borderRadius(FilmRadii.card)
            }
            this.PhotoGrid(this.currentRoll() as Roll)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 18, bottom: 40 })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .id(`detail_${this.selectedId}_${this.dataRevision}`)
    }
  }

  @Builder
  private PreviewPage() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.currentRoll()) {
        Swiper() {
          ForEach((this.currentRoll() as Roll).photos, (uri: string) => {
            Image(uri)
              .width('100%').height('100%').objectFit(ImageFit.Contain)
              .rotate({ angle: uri === this.previewUri ? this.previewRotation : this.photoRotation(uri) })
              .scale({ x: uri === this.previewUri ? this.previewScale : 1, y: uri === this.previewUri ? this.previewScale : 1 })
              .translate({ x: uri === this.previewUri ? this.previewOffsetX : 0, y: uri === this.previewUri ? this.previewOffsetY : 0 })
              .onClick(() => this.previewControls = !this.previewControls)
              .gesture(
                GestureGroup(GestureMode.Parallel,
                  PinchGesture({ fingers: 2 })
                    .onActionStart(() => this.previewBaseScale = this.previewScale)
                    .onActionUpdate((event: GestureEvent) => {
                      this.previewScale = Math.max(1, Math.min(4, this.previewBaseScale * event.scale));
                      if (this.previewScale === 1) {
                        this.previewOffsetX = 0;
                        this.previewOffsetY = 0;
                      }
                    }),
                  PanGesture({ fingers: 1, direction: PanDirection.All })
                    .onActionStart(() => {
                      this.previewBaseX = this.previewOffsetX;
                      this.previewBaseY = this.previewOffsetY;
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      if (this.previewScale > 1) {
                        this.previewOffsetX = this.previewBaseX + event.offsetX;
                        this.previewOffsetY = this.previewBaseY + event.offsetY;
                      }
                    })
                )
              )
          }, (uri: string) => `preview_${uri}`)
        }
        .index(this.previewIndex).loop(false).indicator(false)
        .disableSwipe(this.previewScale > 1.01).width('100%').height('100%')
        .onChange((index: number) => {
          const roll = this.currentRoll() as Roll;
          this.previewIndex = index;
          this.previewUri = roll.photos[index];
          this.previewRotation = this.photoRotation(this.previewUri);
          this.previewScale = 1;
          this.previewOffsetX = 0;
          this.previewOffsetY = 0;
        })
      }
      if (this.previewControls) {
        Row() {
          Button() {
            this.AppIcon($r('sys.symbol.chevron_left'), '返回图库', FilmColors.white, 23)
          }
            .width(46).height(46).backgroundColor('#66000000')
            .borderRadius(FilmRadii.control).onClick(() => this.goBack())
          Blank()
          Text(`${this.previewIndex + 1} / ${(this.currentRoll() as Roll).photos.length}`)
            .fontSize(16).fontColor(FilmColors.white)
          Blank()
          Button() {
            Row({ space: 5 }) {
              this.AppIcon($r('sys.symbol.arrow_clockwise'), '顺时针旋转', FilmColors.white, 20)
              Text('旋转').fontSize(14).fontColor(FilmColors.white)
            }
          }
            .height(46).backgroundColor('#66000000')
            .borderRadius(FilmRadii.control).onClick(() => this.rotateCurrentPhoto())
          Button() {
            Row({ space: 5 }) {
              this.AppIcon($r('sys.symbol.ohos_trash'), '删除照片', FilmColors.white, 19)
              Text('删除').fontSize(14).fontColor(FilmColors.white)
            }
          }
            .height(46).backgroundColor(FilmColors.danger)
            .borderRadius(FilmRadii.control).onClick(() => this.deletePhoto(this.previewUri))
        }
        .width('100%').padding({ left: 12, right: 12, top: 18 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111820')
  }

  build() {
    Stack() {
      if (!this.loaded) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(44)
            .height(44)
            .color(FilmColors.primary)
          Text('正在整理胶片记忆…')
            .fontSize(14)
            .fontColor(FilmColors.muted)
        }
      } else if (this.screen === SCREEN_HOME) {
        this.HomePage()
      } else if (this.screen === SCREEN_FORM) {
        this.FormPage()
      } else if (this.screen === SCREEN_DATE) {
        this.DateSelectionPage()
      } else if (this.screen === SCREEN_GALLERY) {
        this.GalleryPage()
      } else if (this.screen === SCREEN_DETAIL) {
        this.DetailPage()
      } else {
        this.PreviewPage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.screen === SCREEN_PREVIEW ? '#111820' : FilmColors.background)
  }
}
