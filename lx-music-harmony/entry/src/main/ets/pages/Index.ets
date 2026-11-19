import { common } from '@kit.AbilityKit';
import { Library, LibraryData } from '../music/Library';
import { Player, PlayerEvents } from '../music/Player';
import { Playlist, Track, onlineUrl, timeLabel } from '../music/Tracks';
import { search } from '../music/Online';

const PAPER: string = '#F4F2E9';
const INK: string = '#172920';
const MUTED: string = '#526158';
const GREEN: string = '#315940';
const LIME: string = '#C5ED9F';
const SAMPLE_AUDIO_URL: string = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

@Entry
@Component
struct Index {
  @State private tab: number = 0;
  @State private keyword: string = '';
  @State private results: Track[] = [];
  @State private searchMessage: string = '输入歌名或歌手，搜索酷我曲库';
  @State private favorites: Track[] = [];
  @State private lists: Playlist[] = [];
  @State private selectedList: string = 'favorites';
  @State private queue: Track[] = [];
  @State private index: number = -1;
  @State private elapsed: number = 0;
  @State private duration: number = 0;
  @State private playing: string = '';
  @State private notice: string = '';
  @State private address: string = '';
  @State private resolver: string = '';
  @State private busy: boolean = false;
  @State private ready: boolean = false;
  @State private repeat: boolean = false;

  private readonly library: Library = new Library();
  private readonly player: Player = new Player();
  private data: LibraryData = new LibraryData();
  private searchId: number = 0;

  aboutToAppear(): void {
    try {
      this.data = this.library.open(this.context());
      this.favorites = this.data.favorites;
      this.lists = this.data.playlists;
      this.resolver = this.data.resolver;
      this.ready = true;
    } catch {
      this.notice = '读取本地歌单失败';
    }
  }

  aboutToDisappear(): void {
    this.searchId++;
    this.player.release();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private save(favorites: Track[], lists: Playlist[], resolver: string): boolean {
    if (!this.ready) {
      this.notice = '歌单存储不可用';
      return false;
    }
    const next = new LibraryData();
    next.favorites = favorites;
    next.playlists = lists;
    next.resolver = resolver;
    try {
      this.library.save(next);
      this.data = next;
      this.favorites = favorites;
      this.lists = lists;
      return true;
    } catch {
      this.notice = '保存失败，请检查存储空间';
      return false;
    }
  }

  private async runSearch(): Promise<void> {
    const value = this.keyword.trim();
    const id = ++this.searchId;
    this.results = [];
    if (!value) {
      this.searchMessage = '请输入歌名或歌手';
      return;
    }
    this.searchMessage = '搜索中…';
    try {
      const tracks = await search(value);
      if (id !== this.searchId) return;
      this.results = tracks;
      this.searchMessage = tracks.length ? '' : '没有找到匹配的歌曲';
    } catch {
      if (id === this.searchId) this.searchMessage = '搜索暂不可用，请检查网络后重试';
    }
  }

  private current(): Track | undefined {
    return this.queue[this.index];
  }

  private play(tracks: Track[], index: number): void {
    if (!tracks[index]) return;
    this.notice = '';
    this.queue = tracks;
    this.index = index;
    this.duration = 0;
    this.elapsed = 0;
    this.playing = '正在加载';
    const events: PlayerEvents = {
      state: state => { this.playing = state; },
      time: (position, duration) => {
        this.elapsed = position;
        this.duration = Math.max(0, duration);
      },
      ended: () => {
        if (this.repeat) this.play(this.queue, this.index);
        else this.skip(1);
      },
      error: message => {
        this.playing = '无法播放';
        this.notice = message;
      }
    };
    this.player.start(tracks[index], this.data.resolver, events);
  }

  private skip(step: number): void {
    const next = this.index + step;
    if (next >= 0 && next < this.queue.length) this.play(this.queue, next);
  }

  private async toggle(): Promise<void> {
    if (this.playing === '无法播放') {
      this.play(this.queue, this.index);
      return;
    }
    try {
      await this.player.toggle();
    } catch {
      this.notice = '播放控制失败';
    }
  }

  private seek(position: number): void {
    try {
      this.player.seek(position);
    } catch {
      this.notice = '这个音频无法跳转';
    }
  }

  private isFavorite(track: Track): boolean {
    return this.favorites.some(item => item.id === track.id);
  }

  private favorite(track: Track): void {
    if (track.source === 'local') return;
    const items = this.isFavorite(track) ? this.favorites.filter(item => item.id !== track.id) :
      [...this.favorites, track];
    this.save(items, this.lists, this.data.resolver);
  }

  private libraryTracks(): Track[] {
    if (this.selectedList === 'favorites') return this.favorites;
    return this.lists.find(list => list.id === this.selectedList)?.tracks ?? [];
  }

  private async importAudio(): Promise<void> {
    if (!this.ready || this.busy) return;
    this.busy = true;
    this.notice = '';
    try {
      const tracks = await this.library.pickAudio(this.context());
      if (!tracks.length) return;
      const before = this.lists.find(list => list.id === 'audio')?.tracks ?? [];
      const updated = new Playlist('audio', '本地音频', [...before, ...tracks]);
      const lists = [...this.lists.filter(list => list.id !== 'audio'), updated];
      if (this.save(this.favorites, lists, this.data.resolver)) {
        this.selectedList = 'audio';
      } else {
        this.library.removeCopies(tracks);
      }
    } catch (error) {
      this.notice = '导入音频失败：' + String(error);
    } finally {
      this.busy = false;
    }
  }

  private async importBackup(): Promise<void> {
    if (!this.ready || this.busy) return;
    this.busy = true;
    this.notice = '';
    try {
      const imported = await this.library.pickBackup(this.context());
      if (!imported.length) return;
      const lists = [...this.lists];
      for (const item of imported) {
        let id = item.id;
        let suffix = 2;
        while (lists.some(list => list.id === id)) {
          id = item.id + ':' + suffix;
          suffix++;
        }
        lists.push(new Playlist(id, id === item.id ? item.name : item.name + '（' + (suffix - 1) + '）', item.tracks));
      }
      if (this.save(this.favorites, lists, this.data.resolver)) {
        this.selectedList = lists[this.lists.length - imported.length].id;
        this.notice = '已导入 ' + imported.length + ' 个歌单';
      }
    } catch (error) {
      this.notice = '导入歌单失败：' + String(error);
    } finally {
      this.busy = false;
    }
  }

  private playLink(address: string, name?: string): void {
    const link = address.trim();
    if (!onlineUrl(link)) {
      this.notice = '请输入以 https:// 或 http:// 开头的音频地址';
      return;
    }
    const label = name ?? (link.split(/[?#]/)[0].split('/').pop() || '网络音频');
    this.play([new Track('url:' + link, label, '音频直链', 'url', '', link)], 0);
    this.tab = 2;
  }

  private saveResolver(): void {
    const value = this.resolver.trim();
    if (value && (!value.startsWith('https://') || !onlineUrl(value) || !value.includes('{id}'))) {
      this.notice = '地址接口须使用 HTTPS，并包含 {id}';
      return;
    }
    if (this.save(this.favorites, this.lists, value)) {
      this.notice = value ? '地址接口已保存' : '已清除地址接口';
    }
  }

  @Builder
  trackRow(track: Track, tracks: Track[], index: number) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(track.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(track.singer || track.source).fontSize(13).fontColor(MUTED)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding({ top: 9, bottom: 9 })
        .onClick(() => this.play(tracks, index))
      if (track.source !== 'local') {
        Button(this.isFavorite(track) ? '♥' : '♡').fontSize(21).fontColor(GREEN)
          .backgroundColor(Color.Transparent).width(45).height(40)
          .accessibilityText(this.isFavorite(track) ? '取消收藏' : '收藏')
          .onClick(() => this.favorite(track))
      }
    }.padding({ left: 14, right: 6 }).width('100%').backgroundColor('#FCFBF5').borderRadius(14)
  }

  @Builder
  searchPage() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索歌名 / 歌手', text: this.keyword })
          .layoutWeight(1).height(50).backgroundColor('#FCFBF5')
          .onChange(value => { this.keyword = value; }).onSubmit(() => { void this.runSearch(); })
        Button('搜索').height(48).backgroundColor(GREEN).onClick(() => { void this.runSearch(); })
      }
      if (this.searchMessage) {
        Text(this.searchMessage).fontSize(14).fontColor(MUTED).padding(10).width('100%')
      }
      List({ space: 8 }) {
        ForEach(this.results, (track: Track, index: number) => {
          ListItem() { this.trackRow(track, this.results, index) }
        }, (track: Track) => track.id)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%')
  }

  @Builder
  libraryPage() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('添加本地歌曲').layoutWeight(1).backgroundColor(GREEN).enabled(this.ready && !this.busy)
          .onClick(() => { void this.importAudio(); })
        Button('导入洛雪歌单').layoutWeight(1).backgroundColor(GREEN).enabled(this.ready && !this.busy)
          .onClick(() => { void this.importBackup(); })
      }.width('100%')
      Scroll() {
        Row({ space: 8 }) {
          Button('收藏 · ' + this.favorites.length).fontColor(INK)
            .backgroundColor(this.selectedList === 'favorites' ? LIME : '#FCFBF5')
            .onClick(() => { this.selectedList = 'favorites'; })
          ForEach(this.lists, (list: Playlist) => {
            Button(list.name + ' · ' + list.tracks.length).fontColor(INK)
              .backgroundColor(this.selectedList === list.id ? LIME : '#FCFBF5')
              .onClick(() => { this.selectedList = list.id; })
          }, (list: Playlist) => list.id + ':' + list.tracks.length)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      if (!this.libraryTracks().length) {
        Text('这张歌单还没有歌曲').fontSize(14).fontColor(MUTED).padding(10).width('100%')
      }
      List({ space: 8 }) {
        ForEach(this.libraryTracks(), (track: Track, index: number) => {
          ListItem() { this.trackRow(track, this.libraryTracks(), index) }
        }, (track: Track) => this.selectedList + ':' + track.id)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%')
  }

  @Builder
  controls() {
    Row({ space: 10 }) {
      Button('上一首').enabled(this.index > 0).backgroundColor(GREEN).onClick(() => this.skip(-1))
      Button(this.playing === '正在播放' ? '暂停' : (this.playing === '无法播放' ? '重试' : '播放'))
        .backgroundColor(LIME).fontColor(INK).enabled(this.index >= 0 && this.playing !== '正在加载')
        .onClick(() => { void this.toggle(); })
      Button('下一首').enabled(this.index >= 0 && this.index + 1 < this.queue.length)
        .backgroundColor(GREEN).onClick(() => this.skip(1))
    }.justifyContent(FlexAlign.Center).width('100%')
  }

  @Builder
  playerPage() {
    Column({ space: 10 }) {
      if (this.index >= 0) {
        Column({ space: 12 }) {
          Text('♫').fontSize(78).fontColor(LIME).width('100%').textAlign(TextAlign.Center)
          Text(this.current()?.name ?? '').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#FCFBF5')
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
          Text(this.current()?.singer ?? '').fontSize(14).fontColor('#C2D2C6')
          Text(this.playing).fontSize(13).fontColor('#C2D2C6')
          Slider({ value: this.elapsed, min: 0, max: Math.max(this.duration, 1), step: 1 })
            .selectedColor(LIME).blockColor(LIME).enabled(this.duration > 0)
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) this.seek(value);
            })
          Row() {
            Text(timeLabel(this.elapsed)).fontColor('#C2D2C6').fontSize(12)
            Blank()
            Text(timeLabel(this.duration)).fontColor('#C2D2C6').fontSize(12)
          }.width('100%')
          this.controls()
        }.backgroundColor(INK).padding(22).width('100%').borderRadius(25)
        Row() {
          Text('播放队列 · ' + this.queue.length).fontColor(INK)
          Blank()
          Button(this.repeat ? '单曲循环' : '顺序播放').backgroundColor('#FCFBF5').fontColor(INK)
            .onClick(() => { this.repeat = !this.repeat; })
        }.width('100%').padding({ top: 6 })
        List({ space: 8 }) {
          ForEach(this.queue, (track: Track, index: number) => {
            ListItem() { this.trackRow(track, this.queue, index) }
          }, (track: Track) => track.id)
        }.width('100%').layoutWeight(1)
      } else {
        Text('从搜索结果、歌单或音源页开始播放').fontSize(14).fontColor(MUTED)
          .padding(14).width('100%')
      }
    }.width('100%').height('100%')
  }

  @Builder
  sourcePage() {
    Scroll() {
      Column({ space: 14 }) {
        Text('音频直链').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK)
        TextInput({ placeholder: 'https://…', text: this.address }).backgroundColor('#FCFBF5')
          .onChange(value => { this.address = value; }).onSubmit(() => this.playLink(this.address))
        Row({ space: 8 }) {
          Button('播放链接').backgroundColor(GREEN).onClick(() => this.playLink(this.address))
          Button('播放测试音频').backgroundColor(LIME).fontColor(INK)
            .onClick(() => this.playLink(SAMPLE_AUDIO_URL, 'SoundHelix Song 1'))
        }.width('100%')
        Divider().color('#D6DBCE')
        Text('播放地址接口').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK)
        Text('填写你可用的 HTTPS 接口。用 {id} 表示歌曲 ID，{source} 表示音源。接口应返回音频直链或包含 url 的 JSON。')
          .fontSize(14).fontColor(MUTED).lineHeight(21)
        TextInput({ placeholder: 'https://…?source={source}&id={id}', text: this.resolver })
          .backgroundColor('#FCFBF5').onChange(value => { this.resolver = value; })
        Button('保存接口').backgroundColor(GREEN).enabled(this.ready).onClick(() => this.saveResolver())
      }.alignItems(HorizontalAlign.Start).width('100%')
    }.width('100%').height('100%')
  }

  @Builder
  nav(label: string, index: number) {
    Button(label).fontSize(14).fontColor(this.tab === index ? INK : MUTED)
      .backgroundColor(this.tab === index ? LIME : Color.Transparent).layoutWeight(1)
      .onClick(() => { this.tab = index; })
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(['搜索', '我的歌单', '正在播放', '音源'][this.tab]).fontSize(32)
          .fontWeight(FontWeight.Bold).fontColor(INK)
        Blank()
        Text('洛雪音乐').fontSize(14).fontColor(GREEN)
      }.width('100%').padding({ top: 10 })
      if (this.notice) {
        Text(this.notice).fontSize(13).fontColor(INK).padding(10).width('100%')
          .backgroundColor('#E3E8D8').borderRadius(10).onClick(() => { this.notice = ''; })
      }
      Column() {
        if (this.tab === 0) this.searchPage()
        else if (this.tab === 1) this.libraryPage()
        else if (this.tab === 2) this.playerPage()
        else this.sourcePage()
      }.width('100%').layoutWeight(1)
      if (this.tab !== 2 && this.index >= 0) {
        Row({ space: 10 }) {
          Text(this.current()?.name ?? '').fontColor('#FCFBF5').fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            .onClick(() => { this.tab = 2; })
          Button(this.playing === '正在播放' ? '暂停' : (this.playing === '无法播放' ? '重试' : '播放'))
            .backgroundColor(LIME).fontColor(INK).enabled(this.playing !== '正在加载')
            .onClick(() => { void this.toggle(); })
        }.padding({ left: 14, right: 8, top: 6, bottom: 6 }).backgroundColor(INK).borderRadius(17).width('100%')
      }
      Row({ space: 4 }) {
        this.nav('搜索', 0)
        this.nav('歌单', 1)
        this.nav('播放', 2)
        this.nav('音源', 3)
      }.width('100%').padding({ bottom: 6 })
    }.padding({ left: 18, right: 18 }).width('100%').height('100%').backgroundColor(PAPER)
  }
}
