import { common } from '@kit.AbilityKit';
import { ScriptSources } from '../music/ScriptSources';
import { PRESET_SOURCES, PresetSource } from '../music/SourceCatalog';
import { Chart, ChartPlatform, CHART_PLATFORMS, SODA_CLASSICS_ID } from '../music/ChartCatalog';
import { avSession } from '@kit.AVSessionKit';
import { SystemPlayback } from '../music/SystemPlayback';
import { PlaybackSnapshot, PlaybackStore, rememberPlayed } from '../music/PlaybackStore';
import { Library, LibraryData, ResolverProfile } from '../music/Library';
import { Player, PlayerEvents } from '../music/Player';
import { Playlist, Track, onlineUrl, parseBackup, timeLabel } from '../music/Tracks';
import { util } from '@kit.ArkTS';
import { decodeBackup, encodeBackup, LibraryBackup, mergePlaylists, mergeTracks, replaceOnlinePlaylists } from '../music/Backup';
import { WebDav } from '../music/WebDav';
import { loadChart, search } from '../music/Online';
import { nextIndex, PlaybackMode, shuffleOrder } from '../music/PlaybackOrder';

const PAPER: string = '#F4F5F2';
const INK: string = '#233D32';
const MUTED: string = '#5C7065';
const GREEN: string = '#287661';
const SELECTED: string = '#DCEEE6';
const CARD: string = '#FFFFFF';
const SAMPLE_AUDIO_URL: string = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

@Entry
@Component
struct Index {
  @State private tab: number = 0;
  @State private keyword: string = '';
  @State private results: Track[] = [];
  @State private searching: boolean = false;
  @State private chartId: string = '16';
  @State private chartPlatform: number = 0;
  @State private chartSongs: Track[] = [];
  @State private chartMessage: string = '';
  private chartRequest: number = 0;
  @State private searchMessage: string = '';
  @State private favorites: Track[] = [];
  @State private lists: Playlist[] = [];
  @State private selectedList: string = 'favorites';
  @State private queue: Track[] = [];
  @State private history: Track[] = [];
  @State private historyOpen: boolean = false;
  @State private index: number = -1;
  @State private elapsed: number = 0;
  @State private duration: number = 0;
  @State private playing: string = '';
  @State private notice: string = '';
  @State private address: string = '';
  @State private resolver: string = '';
  @State private resolverName: string = '';
  @State private resolverForm: boolean = false;
  @State private activeResolver: string = '';
  @State private lastSource: string = '';
  @State private showPresets: boolean = false;
  @State private showAudioLink: boolean = false;
  @State private preferScriptSources: boolean = false;
  @State private resolvers: ResolverProfile[] = [];
  private editedResolverId: string = '';
  @State private busy: boolean = false;
  @State private ready: boolean = false;
  @State private mode: PlaybackMode = PlaybackMode.Sequential;
  @State private shuffled: number[] = [];
  @State private queueAction: boolean = false;

  @State private listName: string = '';
  @State private naming: boolean = false;
  @State private renameId: string = '';
  @State private editing: boolean = false;
  @State private checked: string[] = [];
  @State private addTrack?: Track = undefined;
  @State private backupOpen: boolean = false;
  @State private aboutOpen: boolean = false;
  @State private davUrl: string = '';
  @State private davAccount: string = '';
  @State private davPassword: string = '';

  private readonly library: Library = new Library();
  private readonly player: Player = new Player();
  private readonly scriptSources: ScriptSources = new ScriptSources();
  private readonly systemPlayer: SystemPlayback = new SystemPlayback();
  private readonly playbackStore: PlaybackStore = new PlaybackStore();
  private lastCheckpoint: number = 0;
  private lastSystemUpdate: number = 0;
  private data: LibraryData = new LibraryData();
  private searchId: number = 0;

  aboutToAppear(): void {
    void this.showChart(this.chartId);
    this.systemPlayer.bind(this.context(), {
      play: () => { void this.resumePlayback(); },
      pause: () => { void this.pausePlayback(); },
      next: () => this.skip(1),
      previous: () => this.skip(-1),
      seek: position => this.seek(position)
    });
    try {
      const saved = this.playbackStore.open(this.context());
      if (saved) {
        this.queue = saved.queue;
        this.index = saved.index;
        this.elapsed = saved.elapsed;
        this.duration = saved.duration;
        this.mode = saved.mode;
        this.shuffled = this.mode === PlaybackMode.Shuffle ?
          this.restoredShuffle(saved.shuffled, saved.queue.length, saved.index) : [];
        this.playing = '待续播';
      }
    } catch {
      // A missing or damaged snapshot must not prevent the library from loading.
    }
    try {
      this.history = this.playbackStore.openHistory();
    } catch {
      // An unreadable history must not prevent playback.
    }
    try {
      this.data = this.library.open(this.context());
      this.favorites = this.data.favorites;
      this.lists = this.data.playlists;
      this.activeResolver = this.data.resolver;
      this.resolvers = this.data.resolvers;
      this.preferScriptSources = this.data.preferScriptSources;
      this.ready = true;
    } catch {
      this.notice = '读取本地歌单失败';
    }
  }

  onBackPress(): boolean {
    if (this.aboutOpen) {
      this.aboutOpen = false;
      return true;
    }
    if (this.tab === 2 && this.historyOpen && !this.addTrack) {
      this.historyOpen = false;
      return true;
    }
    return false;
  }

  onPageHide(): void {
    this.checkpoint();
  }

  aboutToDisappear(): void {
    this.checkpoint();
    this.systemPlayer.dispose();
    this.searchId++;
    this.chartRequest++;
    this.player.release();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private save(favorites: Track[], lists: Playlist[], resolver: string,
    resolvers: ResolverProfile[] = this.data.resolvers, preferScripts: boolean = this.data.preferScriptSources): boolean {
    if (!this.ready) {
      this.notice = '歌单存储不可用';
      return false;
    }
    const next = new LibraryData();
    next.favorites = favorites;
    next.playlists = lists;
    next.resolver = resolver;
    next.resolvers = resolvers;
    next.preferScriptSources = preferScripts;
    try {
      this.library.save(next);
      this.data = next;
      this.favorites = favorites;
      this.lists = lists;
      this.activeResolver = resolver;
      this.resolvers = resolvers;
      this.preferScriptSources = preferScripts;
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
      this.clearSearch();
      return;
    }
    this.searching = true;
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

  private async showChart(id: string): Promise<void> {
    const request = ++this.chartRequest;
    this.chartId = id;
    this.chartSongs = [];
    this.chartMessage = '正在加载榜单…';
    try {
      const songs = await loadChart(CHART_PLATFORMS[this.chartPlatform].id, id);
      if (request !== this.chartRequest) return;
      this.chartSongs = songs;
      this.chartMessage = songs.length ? '' : '这个榜单暂无歌曲';
    } catch {
      if (request === this.chartRequest) this.chartMessage = '榜单加载失败，请重试';
    }
  }

  private clearSearch(): void {
    this.searchId++;
    this.keyword = '';
    this.results = [];
    this.searchMessage = '';
    this.searching = false;
  }

  private current(): Track | undefined {
    return this.queue[this.index];
  }

  private restoredShuffle(order: number[], length: number, active: number): number[] {
    const valid = Array.isArray(order) && order.length === length && new Set(order).size === length &&
      order.every(index => Number.isInteger(index) && index >= 0 && index < length);
    return valid ? order : shuffleOrder(length, active);
  }

  private checkpoint(): void {
    if (!this.current() || (this.playing !== '正在播放' && this.playing !== '已暂停' &&
      this.playing !== '播放完成' && this.playing !== '待续播')) return;
    const state = new PlaybackSnapshot();
    state.queue = this.queue;
    state.index = this.index;
    state.elapsed = this.playing === '播放完成' ? 0 : this.elapsed;
    state.duration = this.duration;
    state.mode = this.mode;
    state.shuffled = this.shuffled;
    try {
      this.playbackStore.save(state);
      this.lastCheckpoint = Date.now();
    } catch {
      // Foreground playback remains available when progress cannot be saved.
      this.lastCheckpoint = Date.now();
    }
  }

  private publishPlayback(state: avSession.PlaybackState): void {
    const track = this.current();
    if (track) this.systemPlayer.publish(track, state, this.elapsed, this.duration);
    this.lastSystemUpdate = Date.now();
  }

  private playbackChanged(state: string): void {
    this.playing = state;
    switch (state) {
      case '正在播放':
        this.publishPlayback(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
        this.checkpoint();
        break;
      case '已暂停':
        this.publishPlayback(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
        this.checkpoint();
        break;
      case '播放完成':
        if (this.queueIndex(1, true) < 0) {
          this.publishPlayback(avSession.PlaybackState.PLAYBACK_STATE_COMPLETED);
          this.checkpoint();
        }
        break;
    }
  }

  private play(tracks: Track[], index: number): void {
    if (!tracks[index]) return;
    this.queue = [...tracks];
    this.shuffled = this.mode === PlaybackMode.Shuffle ? shuffleOrder(this.queue.length, index) : [];
    this.playAt(index);
  }

  private playAt(index: number, position: number = 0): void {
    const track = this.queue[index];
    if (!track) return;
    this.notice = '';
    this.index = index;
    this.duration = 0;
    this.elapsed = position;
    this.playing = '正在加载';
    this.publishPlayback(avSession.PlaybackState.PLAYBACK_STATE_PREPARE);
    let recorded = false;
    const events: PlayerEvents = {
      state: state => {
        if (state === '正在播放' && !recorded) {
          recorded = true;
          this.history = rememberPlayed(this.history, track);
          try {
            this.playbackStore.saveHistory(this.history);
          } catch {
            // Keep the current session's history available when storage fails.
          }
        }
        this.playbackChanged(state);
      },
      time: (position, duration) => {
        this.elapsed = position;
        this.duration = Math.max(0, duration);
        const now = Date.now();
        if (this.playing === '正在播放' && now - this.lastSystemUpdate >= 2000) {
          this.publishPlayback(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
        }
        if (now - this.lastCheckpoint >= 5000) this.checkpoint();
      },
      ended: () => this.skip(1, true),
      sourceReady: source => {
        this.lastSource = source.name;
        this.scriptSources.remember(source.id);
      },
      resumeFailed: () => { this.notice = '音频无法跳转，已尝试从头播放'; },
      error: message => {
        this.playing = '无法播放';
        this.publishPlayback(avSession.PlaybackState.PLAYBACK_STATE_ERROR);
        this.notice = message;
      }
    };
    const preferred = this.data.resolver;
    const templates = this.data.resolvers.map(item => item.address);
    const preferScripts = this.data.preferScriptSources;
    this.player.start(track, (alive, excluded) =>
      this.scriptSources.resolve(track, preferred, templates, alive, excluded, preferScripts), events, position);
  }

  private displayedQueue(): Track[] {
    return this.mode === PlaybackMode.Shuffle ? this.shuffled.map(index => this.queue[index]) : this.queue;
  }

  private queueIndex(step: number, finished: boolean = false): number {
    return nextIndex(this.mode, this.shuffled, this.queue.length, this.index, step, finished);
  }

  private skip(step: number, finished: boolean = false): void {
    const next = this.queueIndex(step, finished);
    if (next >= 0) this.playAt(next);
  }

  private changeMode(): void {
    this.mode = (this.mode + 1) % 4 as PlaybackMode;
    this.shuffled = this.mode === PlaybackMode.Shuffle ? shuffleOrder(this.queue.length, this.index) : [];
    this.checkpoint();
  }

  private playNext(track: Track): void {
    const active = this.current();
    if (!active) {
      this.play([track], 0);
    } else if (active.id !== track.id) {
      const oldIndex = this.queue.findIndex(item => item.id === track.id);
      const updated = [...this.queue];
      const oldOrder = [...this.shuffled];
      if (oldIndex >= 0) updated.splice(oldIndex, 1);
      const current = this.index - (oldIndex >= 0 && oldIndex < this.index ? 1 : 0);
      const insertAt = current + 1;
      updated.splice(insertAt, 0, track);
      this.index = current;
      if (this.mode === PlaybackMode.Shuffle) {
        const order = oldOrder.filter(value => value !== oldIndex).map(value => {
          const afterRemoval = oldIndex >= 0 && value > oldIndex ? value - 1 : value;
          return afterRemoval >= insertAt ? afterRemoval + 1 : afterRemoval;
        });
        order.splice(order.indexOf(current) + 1, 0, insertAt);
        this.shuffled = order;
      }
      this.queue = updated;
      this.checkpoint();
      this.notice = '已设为下一首播放';
    } else {
      this.notice = '这首歌正在播放';
    }
    this.addTrack = undefined;
    this.naming = false;
  }

  private removeFromQueue(track: Track): void {
    const position = this.queue.findIndex(item => item.id === track.id);
    if (position < 0 || position === this.index) return;
    this.queue = this.queue.filter((item, index) => index !== position);
    if (position < this.index) this.index--;
    if (this.mode === PlaybackMode.Shuffle) {
      this.shuffled = this.shuffled.filter(value => value !== position)
        .map(value => value > position ? value - 1 : value);
    }
    this.addTrack = undefined;
    this.naming = false;
    this.checkpoint();
    this.notice = '已移出播放队列';
  }

  private async resumePlayback(): Promise<void> {
    if (this.playing === '待续播' || this.playing === '无法播放') {
      this.playAt(this.index, this.elapsed);
      return;
    }
    try {
      await this.player.resume();
    } catch {
      this.notice = '播放控制失败';
    }
  }

  private async pausePlayback(): Promise<void> {
    try {
      await this.player.pause();
    } catch {
      this.notice = '播放控制失败';
    }
  }

  private async toggle(): Promise<void> {
    if (this.playing === '正在播放') await this.pausePlayback();
    else await this.resumePlayback();
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
    const items = this.isFavorite(track) ? this.favorites.filter(item => item.id !== track.id) :
      [...this.favorites, track];
    this.save(items, this.lists, this.data.resolver);
  }

  private libraryTracks(): Track[] {
    if (this.selectedList === 'favorites') return this.favorites;
    return this.lists.find(list => list.id === this.selectedList)?.tracks ?? [];
  }

  private selectList(id: string): void {
    this.selectedList = id;
    this.editing = false;
    this.checked = [];
    this.naming = false;
  }

  private editName(rename: boolean): void {
    const list = this.lists.find(item => item.id === this.selectedList);
    this.renameId = rename && list ? list.id : '';
    this.listName = rename && list ? list.name : '';
    this.naming = true;
  }

  private submitName(): void {
    const name = this.listName.trim();
    if (!name || name.length > 60) {
      this.notice = '歌单名称需为 1–60 个字符';
      return;
    }
    const id = this.renameId || util.generateRandomUUID();
    const lists = this.renameId ?
      this.lists.map(list => list.id === id ? new Playlist(id, name, list.tracks) : list) :
      [...this.lists, new Playlist(id, name, this.addTrack ? [this.addTrack] : [])];
    if (this.save(this.favorites, lists, this.data.resolver)) {
      this.addTrack = undefined;
      this.tab = 1;
      this.selectList(id);
      this.notice = '';
    }
  }

  private addToList(track: Track, id: string): void {
    const target = this.lists.find(list => list.id === id);
    if (!target) return;
    if (target.tracks.some(item => item.id === track.id)) {
      this.notice = '这首歌已在「' + target.name + '」中';
      return;
    }
    const lists = this.lists.map(list =>
      list.id === id ? new Playlist(id, list.name, [...list.tracks, track]) : list);
    if (this.save(this.favorites, lists, this.data.resolver)) {
      this.addTrack = undefined;
      this.notice = '已加入「' + target.name + '」';
    }
  }

  private saveListTracks(tracks: Track[]): boolean {
    const id = this.selectedList;
    if (id === 'favorites') return this.save(tracks, this.lists, this.data.resolver);
    const lists = this.lists.map(list => list.id === id ? new Playlist(id, list.name, tracks) : list);
    return this.save(this.favorites, lists, this.data.resolver);
  }

  private moveTrack(id: string, step: number): void {
    const tracks = [...this.libraryTracks()];
    const index = tracks.findIndex(track => track.id === id);
    const target = index + step;
    if (index < 0 || target < 0 || target >= tracks.length) return;
    const track = tracks.splice(index, 1)[0];
    tracks.splice(target, 0, track);
    this.saveListTracks(tracks);
  }

  private checkTrack(id: string, selected: boolean): void {
    if (this.checked.includes(id) === selected) return;
    this.checked = selected ? [...this.checked, id] : this.checked.filter(item => item !== id);
  }

  private removeChecked(): void {
    if (this.saveListTracks(this.libraryTracks().filter(track => !this.checked.includes(track.id)))) {
      this.checked = [];
    }
  }

  private async confirmAction(message: string, action: string): Promise<boolean> {
    try {
      const choice = await this.getUIContext().getPromptAction().showDialog({
        message: message,
        buttons: [{ text: '取消', color: MUTED }, { text: action, color: GREEN }]
      });
      return choice.index === 1;
    } catch {
      return false;
    }
  }

  private async clearHistory(): Promise<void> {
    if (!await this.confirmAction('清空本机播放历史？', '清空')) return;
    try {
      this.playbackStore.saveHistory([]);
      this.history = [];
    } catch {
      this.notice = '清空播放历史失败';
    }
  }

  private async deleteList(): Promise<void> {
    const id = this.selectedList;
    const list = this.lists.find(item => item.id === id);
    if (!list || id === 'audio') return;
    if (!await this.confirmAction('删除歌单「' + list.name + '」？', '删除')) return;
    if (this.save(this.favorites, this.lists.filter(item => item.id !== id), this.data.resolver) &&
      this.selectedList === id) {
      this.selectList('favorites');
    }
  }

  private mergeBackup(backup: LibraryBackup): void {
    const favorites = mergeTracks(this.favorites, backup.favorites);
    const playlists = mergePlaylists(this.lists, backup.playlists);
    if (this.save(favorites, playlists, this.data.resolver)) {
      this.checked = [];
      this.notice = '已合并歌单和收藏';
    }
  }

  private async exportBackup(): Promise<void> {
    if (this.busy || !this.ready) return;
    this.busy = true;
    try {
      const body = encodeBackup(this.favorites, this.lists);
      if (await this.library.exportBackup(this.context(), body)) this.notice = '备份已导出';
    } catch (error) {
      this.notice = '导出失败：' + String(error);
    } finally {
      this.busy = false;
    }
  }

  private async syncBackup(upload: boolean, replace: boolean = false): Promise<void> {
    if (this.busy || !this.ready) return;
    this.busy = true;
    try {
      const dav = new WebDav(this.davUrl.trim(), this.davAccount.trim(), this.davPassword);
      if (upload) {
        if (!await this.confirmAction('用本机歌单和收藏覆盖该地址的远端备份？', '上传')) return;
        const body = encodeBackup(this.favorites, this.lists);
        await dav.upload(body);
        this.notice = '已上传到 WebDAV';
      } else {
        const backup = decodeBackup(await dav.download());
        if (!backup) throw new Error('该地址没有洛雪鸿蒙版备份');
        if (replace) {
          if (!await this.confirmAction('应用远端的歌单名称、顺序及删除记录？本地音频会保留。', '应用远端')) return;
          const favorites = mergeTracks(backup.favorites, this.favorites.filter(track => track.source === 'local'));
          const playlists = replaceOnlinePlaylists(this.lists, backup.playlists);
          if (this.save(favorites, playlists, this.data.resolver)) {
            this.selectList('favorites');
            this.notice = '已应用远端歌单和收藏';
          }
        } else {
          this.mergeBackup(backup);
        }
      }
    } catch (error) {
      this.notice = '同步失败：' + String(error);
    } finally {
      this.busy = false;
    }
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
        this.selectList('audio');
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
      const raw = await this.library.pickBackup(this.context());
      if (raw === undefined) return;
      const backup = decodeBackup(raw);
      if (backup) {
        this.mergeBackup(backup);
        return;
      }
      const imported = parseBackup(raw);
      if (!imported.length) throw new Error('歌单文件内容无效');
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
        this.selectList(lists[this.lists.length - imported.length].id);
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

  private editResolver(id: string = ''): void {
    const profile = this.resolvers.find(item => item.id === id);
    this.editedResolverId = profile?.id ?? '';
    this.resolverName = profile?.name ?? '';
    this.resolver = profile?.address ?? '';
    this.resolverForm = true;
  }

  private saveResolver(): void {
    const address = this.resolver.trim();
    if (!address.startsWith('https://') || !onlineUrl(address) || !address.includes('{id}')) {
      this.notice = '地址接口须使用 HTTPS，并包含 {id}';
      return;
    }
    if (this.resolvers.some(profile => profile.address === address && profile.id !== this.editedResolverId)) {
      this.notice = '这个音源地址已经保存';
      return;
    }
    const existing = this.resolvers.find(profile => profile.id === this.editedResolverId);
    const id = existing?.id ?? util.generateRandomUUID();
    const host = address.slice(8).split(/[/?#]/)[0].split('@').pop() ?? '自定义音源';
    const name = this.resolverName.trim() || host;
    const profile = new ResolverProfile(id, name, address);
    const profiles = existing ? this.resolvers.map(item => item.id === id ? profile : item) :
      [...this.resolvers, profile];
    const active = !this.activeResolver || this.activeResolver === existing?.address ? address : this.activeResolver;
    if (this.save(this.favorites, this.lists, active, profiles)) {
      this.resolver = '';
      this.resolverForm = false;
      this.notice = '已保存「' + name + '」';
    }
  }

  private isActiveResolver(id: string): boolean {
    return this.resolvers.find(item => item.id === id)?.address === this.activeResolver;
  }

  private useResolver(id: string): void {
    const profile = this.resolvers.find(item => item.id === id);
    if (!profile) return;
    if (this.activeResolver === profile.address) return;
    if (this.save(this.favorites, this.lists, profile.address)) this.notice = '已切换到「' + profile.name + '」';
  }

  private async deleteResolver(id: string): Promise<void> {
    const profile = this.resolvers.find(item => item.id === id);
    if (!profile) return;
    if (!await this.confirmAction('删除音源「' + profile.name + '」？', '删除')) return;
    const remaining = this.resolvers.filter(item => item.id !== profile.id);
    const active = this.activeResolver === profile.address ? (remaining[0]?.address ?? '') : this.activeResolver;
    if (this.save(this.favorites, this.lists, active, remaining)) {
      if (this.editedResolverId === profile.id) {
        this.resolverForm = false;
        this.resolver = '';
      }
      this.notice = '音源已删除';
    }
  }

  @Builder
  trackRow(track: Track, tracks: Track[], index: number, inQueue: boolean = false, rank: number = 0, compact: boolean = false) {
    Row({ space: 12 }) {
      if (rank > 0) {
        Text(String(rank)).fontSize(rank <= 3 ? 20 : 14)
          .fontWeight(rank <= 3 ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(rank <= 3 ? GREEN : MUTED).width(28).textAlign(TextAlign.Center)
      }
      Column({ space: 4 }) {
        Text(track.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(track.singer || track.source).fontSize(13).fontColor(MUTED)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding({ top: 9, bottom: 9 })
        .onClick(() => {
          if (inQueue) this.playAt(this.queue.findIndex(item => item.id === track.id));
          else this.play(tracks, index);
        })
      Button(this.isFavorite(track) ? '♥' : '♡').fontSize(21).fontColor(GREEN)
        .backgroundColor(Color.Transparent).width(45).height(40).enabled(this.ready)
        .accessibilityText(this.isFavorite(track) ? '取消收藏' : '收藏')
        .onClick(() => this.favorite(track))
      Button('+').fontSize(23).fontColor(GREEN).backgroundColor(Color.Transparent).width(42).height(40)
        .enabled(this.ready).accessibilityText('歌曲操作')
        .onClick(() => {
          this.naming = false;
          this.queueAction = inQueue;
          this.addTrack = track;
        })
    }.padding({ left: compact ? 9 : 14, right: 6 }).width('100%')
      .backgroundColor(compact ? Color.Transparent : CARD).borderRadius(compact ? 0 : 14)
  }

  @Builder
  chartButton(label: string, id: string) {
    Button(label).height(34).width('100%').fontSize(13).fontWeight(FontWeight.Medium)
      .fontColor(this.chartId === id ? CARD : INK)
      .backgroundColor(this.chartId === id ? GREEN : '#EAF2ED')
      .accessibilityDescription(this.chartId === id ? '当前榜单' : '')
      .onClick(() => {
        if (this.chartId !== id) void this.showChart(id);
      })
  }

  @Builder
  chartHeader() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('排行榜').fontSize(25).fontWeight(FontWeight.Bold).fontColor(INK)
          if (this.chartId === SODA_CLASSICS_ID) {
            Text('汽水公开歌单 · 90后回忆歌单').fontSize(12).fontColor(MUTED)
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button('播放全部').fontSize(13).fontWeight(FontWeight.Medium).height(38)
          .fontColor(CARD).backgroundColor(GREEN).enabled(this.chartSongs.length > 0)
          .onClick(() => this.play(this.chartSongs, 0))
      }.width('100%')
      Row({ space: 8 }) {
        ForEach(CHART_PLATFORMS, (platform: ChartPlatform, index: number) => {
          Button(platform.name).layoutWeight(1).height(36).padding(0).fontSize(12)
            .fontColor(this.chartPlatform === index ? GREEN : INK)
            .backgroundColor(this.chartPlatform === index ? SELECTED : PAPER)
            .accessibilityDescription(this.chartPlatform === index ? '当前榜单平台' : '')
            .onClick(() => {
              if (this.chartPlatform === index) return;
              this.chartPlatform = index;
              void this.showChart(platform.charts[0].id);
            })
        }, (platform: ChartPlatform) => platform.id)
      }.width('100%')
      GridRow({ columns: 3, gutter: { x: 8, y: 8 } }) {
        ForEach(CHART_PLATFORMS[this.chartPlatform].charts, (chart: Chart) => {
          GridCol() { this.chartButton(chart.name, chart.id) }
        }, (chart: Chart) => CHART_PLATFORMS[this.chartPlatform].id + ':' + chart.id)
      }.width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%').padding(16)
      .backgroundColor(CARD)
      .borderRadius(20)
  }

  @Builder
  resultList(tracks: Track[], ranked: boolean) {
    List() {
      ForEach(tracks, (track: Track, index: number) => {
        ListItem() { this.trackRow(track, tracks, index, false, ranked ? index + 1 : 0, true) }
      }, (track: Track, index: number) => (ranked ? CHART_PLATFORMS[this.chartPlatform].id + ':' + this.chartId :
        String(this.searchId)) + ':' + track.id + ':' + index)
    }.divider({ strokeWidth: 0.5, color: '#E4EBE6', startMargin: ranked ? 49 : 12, endMargin: 12 })
      .backgroundColor(CARD).borderRadius(14).width('100%').layoutWeight(1)
  }

  @Builder
  searchPage() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索歌名或歌手', text: this.keyword })
          .layoutWeight(1).height(46).fontSize(16).fontColor(INK).backgroundColor('#EAF2ED')
          .enterKeyType(EnterKeyType.Search)
          .onChange(value => {
            if (!value && this.searching) this.clearSearch();
            else this.keyword = value;
          })
          .onSubmit(() => { void this.runSearch(); })
        Button('搜索').height(42).fontSize(14).fontWeight(FontWeight.Medium).backgroundColor(GREEN)
          .onClick(() => { void this.runSearch(); })
      }.width('100%')
      if (this.searching) {
        Row({ space: 8 }) {
          Text('歌曲').fontSize(20).fontWeight(FontWeight.Bold).fontColor(INK)
          Blank()
          Button('返回榜单').height(34).fontSize(13).fontColor(GREEN).backgroundColor(Color.Transparent)
            .onClick(() => this.clearSearch())
        }.width('100%')
        if (this.searchMessage) {
          Text(this.searchMessage).fontSize(14).fontColor(MUTED).padding(10).width('100%')
        }
        if (this.results.length) this.resultList(this.results, false)
      } else {
        this.chartHeader()
        if (this.chartMessage) {
          Text(this.chartMessage).fontSize(14).fontColor(MUTED).width('100%').padding(10)
        }
        if (this.chartMessage === '榜单加载失败，请重试') {
          Button('重试').backgroundColor(GREEN).onClick(() => { void this.showChart(this.chartId); })
        }
        if (this.chartSongs.length) this.resultList(this.chartSongs, true)
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  nameEditor() {
    Column({ space: 8 }) {
      TextInput({ text: this.listName, placeholder: '歌单名称' }).maxLength(60)
        .onChange(value => { this.listName = value; }).onSubmit(() => this.submitName())
      Row({ space: 8 }) {
        Button('取消').fontColor(GREEN).backgroundColor(CARD).onClick(() => { this.naming = false; })
        Button('保存歌单').backgroundColor(GREEN).enabled(this.ready).onClick(() => this.submitName())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  addTrackPage() {
    Column({ space: 10 }) {
      Text(this.addTrack?.name ?? '').fontSize(20).fontColor(INK).maxLines(2)
      Row({ space: 8 }) {
        Button('返回').fontColor(GREEN).backgroundColor(CARD)
          .onClick(() => { this.addTrack = undefined; this.naming = false; })
        Button('新建歌单').backgroundColor(GREEN).onClick(() => this.editName(false))
      }
      Row({ space: 8 }) {
        Button('下一首播放').backgroundColor(GREEN)
          .onClick(() => { if (this.addTrack) this.playNext(this.addTrack); })
        if (this.queueAction && this.addTrack?.id !== this.current()?.id) {
          Button('移出队列').fontColor(GREEN).backgroundColor(CARD)
            .onClick(() => { if (this.addTrack) this.removeFromQueue(this.addTrack); })
        }
      }
      if (this.naming) this.nameEditor()
      List({ space: 8 }) {
        ForEach(this.lists.filter(list => list.id !== 'audio'), (list: Playlist) => {
          ListItem() {
            Button(list.name).width('100%').fontColor(INK).backgroundColor(CARD)
              .onClick(() => {
                if (this.addTrack) this.addToList(this.addTrack, list.id);
              })
          }
        }, (list: Playlist) => list.id + ':' + list.name)
      }.width('100%').layoutWeight(1)
    }.alignItems(HorizontalAlign.Start).width('100%').height('100%')
  }

  @Builder
  libraryEditRow(track: Track, index: number) {
    Row({ space: 5 }) {
      Checkbox().select(this.checked.includes(track.id)).selectedColor(GREEN)
        .accessibilityText('选择' + track.name).onChange(selected => this.checkTrack(track.id, selected))
      Text(track.name).fontSize(16).fontColor(INK).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      Button('↑').enabled(index > 0).fontColor(GREEN).backgroundColor(CARD)
        .accessibilityText('上移' + track.name).onClick(() => this.moveTrack(track.id, -1))
      Button('↓').enabled(index + 1 < this.libraryTracks().length).fontColor(GREEN).backgroundColor(CARD)
        .accessibilityText('下移' + track.name).onClick(() => this.moveTrack(track.id, 1))
    }.padding(8).width('100%').backgroundColor(CARD).borderRadius(14)
  }

  @Builder
  backupPage() {
    Scroll() {
      Column({ space: 12 }) {
        Button('返回歌单').fontColor(GREEN).backgroundColor(CARD)
          .onClick(() => { this.backupOpen = false; this.davPassword = ''; })
        Button('导出歌单和收藏').backgroundColor(GREEN).enabled(this.ready && !this.busy)
          .onClick(() => { void this.exportBackup(); })
        Text('备份包含在线歌曲和歌单。本机音频文件留在此设备。').fontSize(13).fontColor(MUTED)
        Divider().color('#D7E3DC')
        Text('WebDAV 同步').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK)
        Text('两台设备使用同一个 JSON 文件地址。合并会保留本机顺序，应用远端可同步线上歌曲的顺序和移除。')
          .fontSize(13).fontColor(MUTED)
        TextInput({ placeholder: 'https://你的服务器/目录/lx-library.json', text: this.davUrl })
          .onChange(value => { this.davUrl = value; })
        TextInput({ placeholder: 'WebDAV 用户名', text: this.davAccount })
          .onChange(value => { this.davAccount = value; })
        TextInput({ placeholder: 'WebDAV 密码', text: this.davPassword }).type(InputType.Password)
          .onChange(value => { this.davPassword = value; })
        Row({ space: 8 }) {
          Button('下载并合并').backgroundColor(GREEN).enabled(this.ready && !this.busy)
            .onClick(() => { void this.syncBackup(false); })
          Button('上传备份').backgroundColor(GREEN).enabled(this.ready && !this.busy)
            .onClick(() => { void this.syncBackup(true); })
          Button('应用远端').backgroundColor(GREEN).enabled(this.ready && !this.busy)
            .onClick(() => { void this.syncBackup(false, true); })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 12 })
    }.width('100%').height('100%').align(Alignment.TopStart)
  }

  @Builder
  libraryPage() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('添加本地歌曲').layoutWeight(1).backgroundColor(GREEN).enabled(this.ready && !this.busy)
          .onClick(() => { void this.importAudio(); })
        Button('导入歌单').layoutWeight(1).backgroundColor(GREEN).enabled(this.ready && !this.busy)
          .onClick(() => { void this.importBackup(); })
      }.width('100%')
      Scroll() {
        Row({ space: 8 }) {
          Button('收藏 · ' + this.favorites.length).fontColor(INK)
            .backgroundColor(this.selectedList === 'favorites' ? SELECTED : CARD)
            .onClick(() => this.selectList('favorites'))
          ForEach(this.lists, (list: Playlist) => {
            Button(list.name + ' · ' + list.tracks.length).fontColor(INK)
              .backgroundColor(this.selectedList === list.id ? SELECTED : CARD)
              .onClick(() => this.selectList(list.id))
          }, (list: Playlist) => list.id + ':' + list.name + ':' + list.tracks.length)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      Row({ space: 8 }) {
        Button('新建').fontColor(GREEN).backgroundColor(CARD).enabled(this.ready)
          .onClick(() => this.editName(false))
        Button(this.editing ? '完成' : '编辑').fontColor(GREEN).backgroundColor(CARD)
          .enabled(this.ready).onClick(() => { this.editing = !this.editing; this.checked = []; })
        Button('备份与同步').fontColor(GREEN).backgroundColor(CARD)
          .onClick(() => { this.backupOpen = true; })
      }.width('100%')
      if (this.naming) this.nameEditor()
      if (this.editing) {
        Row({ space: 6 }) {
          Button('全选').backgroundColor(GREEN).enabled(this.libraryTracks().length > 0)
            .onClick(() => { this.checked = this.libraryTracks().map(track => track.id); })
          Button('移除 ' + this.checked.length).backgroundColor(GREEN).enabled(this.checked.length > 0)
            .onClick(() => this.removeChecked())
          if (this.selectedList !== 'favorites' && this.selectedList !== 'audio') {
            Button('更名').backgroundColor(GREEN).onClick(() => this.editName(true))
            Button('删除歌单').backgroundColor(GREEN).onClick(() => { void this.deleteList(); })
          }
        }.width('100%')
      } else if (this.libraryTracks().length) {
        Button('播放全部').backgroundColor(GREEN).onClick(() => this.play(this.libraryTracks(), 0))
      }
      if (!this.libraryTracks().length) {
        Text('这张歌单还没有歌曲').fontSize(14).fontColor(MUTED).padding(10).width('100%')
      }
      List({ space: 8 }) {
        ForEach(this.libraryTracks(), (track: Track, index: number) => {
          ListItem() {
            if (this.editing) this.libraryEditRow(track, index)
            else this.trackRow(track, this.libraryTracks(), index)
          }
        }, (track: Track, index: number) => this.selectedList + ':' + track.id + ':' + index + ':' + this.editing)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%')
  }

  @Builder
  controls() {
    Row({ space: 10 }) {
      Button('上一首').enabled(this.queueIndex(-1) >= 0).backgroundColor(GREEN).onClick(() => this.skip(-1))
      Button(this.playing === '正在播放' ? '暂停' : (this.playing === '无法播放' ? '重试' : '播放'))
        .backgroundColor(SELECTED).fontColor(INK).enabled(this.index >= 0 && this.playing !== '正在加载')
        .onClick(() => { void this.toggle(); })
      Button('下一首').enabled(this.queueIndex(1) >= 0)
        .backgroundColor(GREEN).onClick(() => this.skip(1))
    }.justifyContent(FlexAlign.Center).width('100%')
  }

  @Builder
  playerPage() {
    Column({ space: 10 }) {
      if (this.index >= 0) {
        Column({ space: 12 }) {
          Text('♫').fontSize(78).fontColor(GREEN).width('100%').textAlign(TextAlign.Center)
          Text(this.current()?.name ?? '').fontSize(26).fontWeight(FontWeight.Bold).fontColor(INK)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
          Text(this.current()?.singer ?? '').fontSize(14).fontColor(MUTED)
          Text(this.playing).fontSize(13).fontColor(MUTED)
          Slider({ value: this.elapsed, min: 0, max: Math.max(this.duration, 1), step: 1 })
            .selectedColor(GREEN).blockColor(GREEN).enabled(this.duration > 0)
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) this.seek(value);
            })
          Row() {
            Text(timeLabel(this.elapsed)).fontColor(MUTED).fontSize(12)
            Blank()
            Text(timeLabel(this.duration)).fontColor(MUTED).fontSize(12)
          }.width('100%')
          this.controls()
        }.backgroundColor(CARD).padding(22).width('100%').borderRadius(25)
      }
      Row({ space: 8 }) {
        Button('播放队列').fontSize(13).padding({ left: 13, right: 13 }).fontColor(INK)
          .backgroundColor(this.historyOpen ? CARD : SELECTED)
          .onClick(() => { this.historyOpen = false; })
        Button('播放历史').fontSize(13).padding({ left: 13, right: 13 }).fontColor(INK)
          .backgroundColor(this.historyOpen ? SELECTED : CARD)
          .onClick(() => { this.historyOpen = true; })
        Blank()
        if (this.historyOpen && this.history.length > 0) {
          Button('清空').fontSize(13).fontColor(GREEN).backgroundColor(CARD)
            .onClick(() => { void this.clearHistory(); })
        } else if (!this.historyOpen && this.index >= 0) {
          Button(['顺序播放', '列表循环', '单曲循环', '随机播放'][this.mode]).fontSize(13)
            .backgroundColor(CARD).fontColor(INK).onClick(() => this.changeMode())
        }
      }.width('100%').padding({ top: 6 })
      if (this.historyOpen) {
        if (this.history.length === 0) {
          Text('还没有播放记录').fontSize(14).fontColor(MUTED).padding(14).width('100%')
        } else {
          List({ space: 8 }) {
            ForEach(this.history, (track: Track, index: number) => {
              ListItem() { this.trackRow(track, this.history, index) }
            }, (track: Track, index: number) => track.id + ':' + index)
          }.width('100%').layoutWeight(1)
        }
      } else if (this.index >= 0) {
        List({ space: 8 }) {
          ForEach(this.displayedQueue(), (track: Track, index: number) => {
            ListItem() { this.trackRow(track, this.queue, index, true) }
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
        Row({ space: 8 }) {
          Text('播放音源').fontSize(19).fontWeight(FontWeight.Bold).fontColor(INK)
          Blank()
          Button('添加音源').height(36).backgroundColor(GREEN).enabled(this.ready)
            .onClick(() => this.editResolver())
        }.width('100%')

        Row({ space: 8 }) {
          Column({ space: 4 }) {
            Text('洛雪脚本源').fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK)
            Text(this.lastSource ? '最近播放成功：' + this.lastSource :
              PRESET_SOURCES.length + ' 个候选，播放时自动尝试')
              .fontSize(13).fontColor(MUTED)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button(this.showPresets ? '收起' : '查看').height(34).fontSize(13)
            .backgroundColor('#EAF2ED').fontColor(GREEN).onClick(() => { this.showPresets = !this.showPresets; })
        }.padding(12).width('100%').backgroundColor(CARD).borderRadius(14)
        if (this.showPresets) {
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Text('优先尝试脚本源').fontColor(INK).fontSize(14).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.preferScriptSources })
                .onChange(checked => { this.save(this.favorites, this.lists, this.activeResolver, this.resolvers, checked); })
            }.width('100%')
            GridRow({ columns: 3, gutter: { x: 6, y: 6 } }) {
              ForEach(PRESET_SOURCES, (source: PresetSource) => {
                GridCol() {
                  Text(source.name).fontSize(13)
                    .fontWeight(this.lastSource === source.name ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(INK).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .accessibilityDescription(this.lastSource === source.name ? '最近播放成功' : '')
                    .padding({ left: 8, right: 8 }).height(34).width('100%')
                    .backgroundColor(this.lastSource === source.name ? SELECTED : '#EAF2ED').borderRadius(8)
                }
              }, (source: PresetSource) => source.id)
            }.width('100%')
          }.width('100%').padding({ top: 4, bottom: 4, left: 4, right: 4 })
        }
        if (this.resolverForm) {
          Column({ space: 10 }) {
            TextInput({ placeholder: '音源名称（选填）', text: this.resolverName }).maxLength(40)
              .backgroundColor(CARD).onChange(value => { this.resolverName = value; })
            TextInput({ placeholder: 'https://…?source={source}&id={id}', text: this.resolver })
              .backgroundColor(CARD).onChange(value => { this.resolver = value; })
            Text('地址须为 HTTPS，歌曲 ID 用 {id}，音源代号可用 {source}。').fontSize(13).fontColor(MUTED)
            Row({ space: 8 }) {
              Button('保存接口').backgroundColor(GREEN).enabled(this.ready).onClick(() => this.saveResolver())
              Button('取消').fontColor(GREEN).backgroundColor(CARD)
                .onClick(() => { this.resolverForm = false; this.resolver = ''; })
            }
          }.alignItems(HorizontalAlign.Start).width('100%')
        }
        ForEach(this.resolvers, (profile: ResolverProfile) => {
          Column({ space: 8 }) {
            Text(profile.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: 7 }) {
              Button(this.isActiveResolver(profile.id) ? '当前音源' : '使用')
                .height(34).fontSize(13).backgroundColor(this.isActiveResolver(profile.id) ? SELECTED : GREEN)
                .fontColor(this.isActiveResolver(profile.id) ? INK : CARD)
                .onClick(() => this.useResolver(profile.id))
              Button('编辑').height(34).fontSize(13).fontColor(GREEN).backgroundColor('#EAF2ED')
                .onClick(() => this.editResolver(profile.id))
              Button('删除').height(34).fontSize(13).fontColor(GREEN).backgroundColor('#EAF2ED')
                .onClick(() => { void this.deleteResolver(profile.id); })
            }.width('100%')
          }.alignItems(HorizontalAlign.Start).padding(12).width('100%')
            .backgroundColor(CARD).borderRadius(14)
        }, (profile: ResolverProfile) => profile.id + ':' + profile.name)
        Divider().color('#D7E3DC')
        Button(this.showAudioLink ? '收起音频链接' : '播放音频链接')
          .height(36).fontSize(13).fontColor(GREEN).backgroundColor(Color.Transparent)
          .onClick(() => { this.showAudioLink = !this.showAudioLink; })
        if (this.showAudioLink) {
          TextInput({ placeholder: 'https://…', text: this.address }).backgroundColor(CARD)
            .onChange(value => { this.address = value; }).onSubmit(() => this.playLink(this.address))
          Row({ space: 8 }) {
            Button('播放链接').backgroundColor(GREEN).onClick(() => this.playLink(this.address))
            Button('播放测试音频').backgroundColor(SELECTED).fontColor(INK)
              .onClick(() => this.playLink(SAMPLE_AUDIO_URL, 'SoundHelix Song 1'))
          }.width('100%')
        }
        Button('关于我们').height(36).fontSize(14).fontColor(GREEN).backgroundColor(Color.Transparent)
          .onClick(() => { this.aboutOpen = true; })
      }.alignItems(HorizontalAlign.Start).width('100%')
    }.width('100%').height('100%').align(Alignment.TopStart)
  }

  @Builder
  aboutPage() {
    Scroll() {
      Column({ space: 12 }) {
        Button('返回音源').height(36).fontSize(14).fontColor(GREEN).backgroundColor(CARD)
          .onClick(() => { this.aboutOpen = false; })
        Column({ space: 12 }) {
          Image($r('app.media.app_icon')).width(58).height(58).borderRadius(13)
          Text($r('app.string.app_name')).fontSize(23).fontWeight(FontWeight.Bold).fontColor(INK)
          Text('曲间拾声是一款为 HarmonyOS 打造的原生音乐播放器，也是「栈里拾光」的姊妹应用。')
            .fontSize(15).fontColor(INK).lineHeight(24)
          Text('从搜索或排行榜点一首歌，把喜欢的音乐收藏进自己的歌单。也可以导入本地音频，切到后台继续听。')
            .fontSize(15).fontColor(INK).lineHeight(24)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor(CARD).borderRadius(16)
        Column({ space: 8 }) {
          Text('开源致谢').fontSize(17).fontWeight(FontWeight.Bold).fontColor(INK)
          Text('项目参考洛雪音乐手机版和桌面版开发，并兼容其歌单备份格式。内置音源来自 pdone/lx-music-source、Hei Music 和豆包定制。')
            .fontSize(14).fontColor(MUTED).lineHeight(23)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor(CARD).borderRadius(14)
      }.width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').align(Alignment.TopStart)
  }

  @Builder
  nav(label: string, index: number) {
    Button(label).fontSize(14).fontColor(this.tab === index ? GREEN : MUTED)
      .backgroundColor(this.tab === index ? SELECTED : Color.Transparent).layoutWeight(1)
      .onClick(() => {
        this.tab = index;
        this.addTrack = undefined;
        this.backupOpen = false;
        this.aboutOpen = false;
        this.naming = false;
        this.davPassword = '';
      })
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.aboutOpen ? '关于我们' : this.addTrack ? '歌曲操作' : (this.backupOpen ? '备份与同步' : ['搜索', '我的歌单', '正在播放', '音源'][this.tab])).fontSize(32)
          .fontWeight(FontWeight.Bold).fontColor(INK)
        Blank()
        Text($r('app.string.app_name')).fontSize(14).fontColor(GREEN)
      }.width('100%').padding({ top: 10 })
      if (this.notice) {
        Text(this.notice).fontSize(13).fontColor(INK).padding(10).width('100%')
          .backgroundColor('#E5F2EB').borderRadius(10).onClick(() => { this.notice = ''; })
      }
      Column() {
        if (this.aboutOpen) this.aboutPage()
        else if (this.addTrack) this.addTrackPage()
        else if (this.backupOpen) this.backupPage()
        else if (this.tab === 0) this.searchPage()
        else if (this.tab === 1) this.libraryPage()
        else if (this.tab === 2) this.playerPage()
        else this.sourcePage()
      }.width('100%').layoutWeight(1)
      if ((this.tab === 0 || this.tab === 1) && this.index >= 0) {
        Row({ space: 10 }) {
          Text(this.current()?.name ?? '').fontColor(INK).fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            .onClick(() => { this.tab = 2; this.addTrack = undefined; this.backupOpen = false; this.aboutOpen = false; this.naming = false; this.davPassword = ''; })
          Button(this.playing === '正在播放' ? '暂停' : (this.playing === '无法播放' ? '重试' : '播放'))
            .backgroundColor(SELECTED).fontColor(INK).enabled(this.playing !== '正在加载')
            .onClick(() => { void this.toggle(); })
        }.padding({ left: 14, right: 8, top: 6, bottom: 6 }).backgroundColor(CARD).borderRadius(14).width('100%')
      }
      Row({ space: 4 }) {
        this.nav('搜索', 0)
        this.nav('歌单', 1)
        this.nav('播放', 2)
        this.nav('音源', 3)
      }.width('100%').padding(5).backgroundColor(CARD).borderRadius(14)
      Web({ src: $rawfile('lx-source-worker.html'), controller: this.scriptSources.webController() })
        .width(1).height(1).opacity(0).hitTestBehavior(HitTestMode.None)
        .fileAccess(false).domStorageAccess(false).databaseAccess(false).javaScriptAccess(true)
        .onPageEnd(() => this.scriptSources.pageReady())
    }.padding({ left: 18, right: 18 }).width('100%').height('100%').backgroundColor(PAPER)
  }
}
