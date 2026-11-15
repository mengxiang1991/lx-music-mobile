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
