export class Track {
  id: string;
  name: string;
  singer: string;
  source: string;
  songId: string;
  url: string;

  constructor(id: string, name: string, singer: string, source: string, songId: string = '', url: string = '') {
    this.id = id;
    this.name = name;
    this.singer = singer;
    this.source = source;
    this.songId = songId;
    this.url = url;
  }
}

export class Playlist {
  id: string;
  name: string;
  tracks: Track[];

  constructor(id: string, name: string, tracks: Track[]) {
    this.id = id;
    this.name = name;
    this.tracks = tracks;
  }
}
interface LXMeta { songId?: string | number }
interface LXTrack {
  name?: string;
  singer?: string;
  source?: string;
  meta?: LXMeta;
  songmid?: string | number;
}
interface LXList { id?: string; name?: string; list?: LXTrack[] }
interface LXBackup { type: string; data?: LXList | LXList[]; playList?: LXList[] }
interface KwRow { MUSICRID?: string; SONGNAME?: string; ARTIST?: string }
interface KwResponse { abslist?: KwRow[]; TOTAL?: string }

export function onlineUrl(value: string): boolean {
  return /^https?:\/\/[^\s/?#]+[^\s]*$/i.test(value);
}

export function parseBackup(raw: string): Playlist[] {
  let decoded = JSON.parse(raw.replace(/^\uFEFF/, '')) as LXBackup | string;
  if (typeof decoded === 'string') decoded = JSON.parse(decoded) as LXBackup;
  const backup = decoded as LXBackup;
  let lists: LXList[] = [];
  switch (backup.type) {
    case 'playList':
    case 'playList_v2':
      if (Array.isArray(backup.data)) lists = backup.data;
      break;
    case 'playListPart':
    case 'playListPart_v2':
      if (backup.data && !Array.isArray(backup.data)) lists = [backup.data];
      break;
    case 'allData':
    case 'allData_v2':
      if (Array.isArray(backup.playList)) lists = backup.playList;
      break;
  }
  if (lists.length === 0) throw new Error('文件中没有可导入的洛雪歌单');
  return lists.filter(list => list && Array.isArray(list.list)).map((list, index) => {
    const tracks: Track[] = [];
    for (const row of list.list ?? []) {
      if (!row || typeof row.name !== 'string' || !row.name.trim()) continue;
      const source = typeof row.source === 'string' ? row.source : 'unknown';
      const songId = String(row.meta?.songId ?? row.songmid ?? '');
      const id = songId ? source + ':' + songId : 'import:' + tracks.length;
      if (tracks.some(track => track.id === id)) continue;
      tracks.push(new Track(id, row.name, typeof row.singer === 'string' ? row.singer : '',
        source, source === 'local' ? '' : songId));
    }
    return new Playlist('lx:' + (list.id ?? index), list.name || '导入歌单', tracks);
  });
}

function cleanLabel(text: string): string {
  return text.replace(/&amp;/g, '&').replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>');
}

export function parseSearch(raw: string): Track[] {
  const data = JSON.parse(raw) as KwResponse;
  if (!Array.isArray(data.abslist)) {
    if (String(data.TOTAL) === '0') return [];
    throw new Error('酷我搜索返回了无法识别的数据');
  }
  const tracks: Track[] = [];
  for (const row of data.abslist) {
    if (!row || typeof row.MUSICRID !== 'string' || typeof row.SONGNAME !== 'string') continue;
    const id = row.MUSICRID.replace(/^MUSIC_/, '');
    if (!id || tracks.some(track => track.songId === id)) continue;
    tracks.push(new Track('kw:' + id, cleanLabel(row.SONGNAME), cleanLabel(row.ARTIST ?? '').replace(/&/g, ' / '),
      'kw', id));
  }
  return tracks;
}

export function timeLabel(ms: number): string {
  const seconds = Math.floor(Math.max(0, ms) / 1000);
  return String(Math.floor(seconds / 60)).padStart(2, '0') + ':' + String(seconds % 60).padStart(2, '0');
}

interface ChartRow { id?: string | number; name?: string; artist?: string }
interface ChartResponse { musiclist?: ChartRow[] }

export function parseChart(raw: string): Track[] {
  const data = JSON.parse(raw) as ChartResponse;
  if (!Array.isArray(data?.musiclist)) throw new Error('榜单数据无效');
  const songs: Track[] = [];
  const seen = new Set<string>();
  for (const item of data.musiclist) {
    if (!item || typeof item.name !== 'string' || !item.name.trim() ||
      (typeof item.id !== 'string' && typeof item.id !== 'number')) continue;
    const id = String(item.id).replace(/^MUSIC_/, '');
    if (!id || seen.has(id)) continue;
    seen.add(id);
    songs.push(new Track('kw:' + id, cleanLabel(item.name),
      typeof item.artist === 'string' ? cleanLabel(item.artist).replace(/&/g, ' / ') : '', 'kw', id));
  }
  return songs;
}

interface ChartArtist { name?: string }
interface NeteaseChartSong { id?: number; name?: string; artists?: ChartArtist[] }
interface NeteaseChartResponse { result?: NeteaseChartResult }
interface NeteaseChartResult { tracks?: NeteaseChartSong[]; songs?: NeteaseChartSong[] }
interface QqChartSong { songmid?: string; songname?: string; singer?: ChartArtist[] }
interface QqChartEntry { data?: QqChartSong }
interface QqChartResponse { songlist?: QqChartEntry[] }
interface SodaChartSong { id?: string; name?: string; artists?: ChartArtist[] }
interface SodaChartEntry { track?: SodaChartSong }
interface SodaChartResult { track_ranks?: SodaChartEntry[] }
interface SodaChartResponse { chart?: SodaChartResult }
interface SodaPlaylistEntity { track_wrapper?: SodaChartEntry }
interface SodaPlaylistItem { entity?: SodaPlaylistEntity }
interface SodaPlaylistResponse { media_resources?: SodaPlaylistItem[] }

function chartArtistNames(artists?: ChartArtist[]): string {
  return Array.isArray(artists) ? artists.filter(artist => typeof artist?.name === 'string')
    .map(artist => cleanLabel(artist.name ?? '')).filter(name => name).join(' / ') : '';
}

export function parseNeteaseChart(raw: string): Track[] {
  const data = JSON.parse(raw) as NeteaseChartResponse;
  return neteaseTracks(data?.result?.tracks);
}

export function parseNeteaseSearch(raw: string): Track[] {
  const data = JSON.parse(raw) as NeteaseChartResponse;
  return neteaseTracks(data?.result?.songs ?? []);
}

function neteaseTracks(rows: NeteaseChartSong[] | undefined): Track[] {
  if (!Array.isArray(rows)) throw new Error('网易云榜单数据无效');
  const songs: Track[] = [];
  for (const item of rows) {
    if (typeof item?.name !== 'string' || !item.name.trim() ||
      typeof item.id !== 'number' || !Number.isSafeInteger(item.id) || item.id <= 0) continue;
    const id = String(item.id);
    if (songs.some(song => song.songId === id)) continue;
    songs.push(new Track('wy:' + id, cleanLabel(item.name), chartArtistNames(item.artists), 'wy', id));
    if (songs.length === 30) break;
  }
  return songs;
}

export function parseQqChart(raw: string): Track[] {
  const data = JSON.parse(raw) as QqChartResponse;
  if (!Array.isArray(data?.songlist)) throw new Error('QQ 音乐榜单数据无效');
  const songs: Track[] = [];
  for (const entry of data.songlist) {
    const item = entry?.data;
    if (typeof item?.songname !== 'string' || !item.songname.trim() ||
      typeof item.songmid !== 'string' || !item.songmid || songs.some(song => song.songId === item.songmid)) continue;
    songs.push(new Track('tx:' + item.songmid, cleanLabel(item.songname), chartArtistNames(item.singer), 'tx', item.songmid));
    if (songs.length === 30) break;
  }
  return songs;
}

export function parseSodaChart(raw: string): Track[] {
  const data = JSON.parse(raw) as SodaChartResponse;
  const rows = data?.chart?.track_ranks;
  if (!Array.isArray(rows)) throw new Error('汽水音乐榜单数据无效');
  return sodaTracks(rows.map(entry => entry?.track));
}

export function parseSodaClassics(raw: string): Track[] {
  const data = JSON.parse(raw) as SodaPlaylistResponse;
  const rows = data?.media_resources;
  if (!Array.isArray(rows)) throw new Error('汽水音乐歌单数据无效');
  return sodaTracks(rows.map(entry => entry?.entity?.track_wrapper?.track));
}

function sodaTracks(rows: (SodaChartSong | undefined)[]): Track[] {
  const songs: Track[] = [];
  for (const item of rows) {
    if (typeof item?.name !== 'string' || !item.name.trim() ||
      typeof item.id !== 'string' || !item.id || songs.some(song => song.songId === item.id)) continue;
    songs.push(new Track('sd:' + item.id, cleanLabel(item.name), chartArtistNames(item.artists), 'sd', item.id));
    if (songs.length === 30) break;
  }
  return songs;
}
