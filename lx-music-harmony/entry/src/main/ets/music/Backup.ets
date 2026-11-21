import { Playlist, Track, onlineUrl } from './Tracks';

const BACKUP_TYPE: string = 'lx-harmony-library-v1';

export class LibraryBackup {
  type: string = BACKUP_TYPE;
  favorites: Track[] = [];
  playlists: Playlist[] = [];
}

export function mergeTracks(current: Track[], incoming: Track[]): Track[] {
  const result = [...current];
  const ids = new Set(current.map(track => track.id));
  for (const track of incoming) {
    if (ids.has(track.id)) continue;
    ids.add(track.id);
    result.push(track);
  }
  return result;
}

export function encodeBackup(favorites: Track[], playlists: Playlist[]): string {
  const backup = new LibraryBackup();
  backup.favorites = favorites.filter(track => track.source !== 'local');
  backup.playlists = playlists.filter(list => list.id !== 'audio').map(list =>
    new Playlist(list.id, list.name, list.tracks.filter(track => track.source !== 'local')));
  return JSON.stringify(backup);
}

function readTracks(tracks: Track[]): Track[] {
  if (!Array.isArray(tracks)) throw new Error('备份的歌曲列表无效');
  const valid = tracks.filter(track => track && typeof track.id === 'string' && track.id &&
    typeof track.name === 'string' && typeof track.singer === 'string' && typeof track.source === 'string' &&
    typeof track.songId === 'string' && typeof track.url === 'string' && track.source !== 'local' &&
    (!track.url || onlineUrl(track.url)));
  if (valid.length !== tracks.length) throw new Error('备份中包含无效歌曲');
  return mergeTracks([], valid);
}

export function decodeBackup(raw: string): LibraryBackup | undefined {
  const decoded = JSON.parse(raw.replace(/^\uFEFF/, '')) as LibraryBackup | null;
  if (decoded?.type !== BACKUP_TYPE) return undefined;
  if (!Array.isArray(decoded.playlists)) throw new Error('备份的歌单列表无效');
  const backup = new LibraryBackup();
  backup.favorites = readTracks(decoded.favorites);
  for (const list of decoded.playlists) {
    if (!list || typeof list.id !== 'string' || !list.id || list.id === 'audio' ||
      list.id === 'favorites' || typeof list.name !== 'string' || !list.name.trim()) {
      throw new Error('备份中的歌单信息无效');
    }
    if (backup.playlists.some(item => item.id === list.id)) throw new Error('备份中存在重复歌单 ID');
    backup.playlists.push(new Playlist(list.id, list.name, readTracks(list.tracks)));
  }
  return backup;
}

export function mergePlaylists(current: Playlist[], incoming: Playlist[]): Playlist[] {
  const result = [...current];
  for (const list of incoming) {
    const index = result.findIndex(existing => existing.id === list.id);
    if (index < 0) {
      result.push(list);
    } else {
      const existing = result[index];
      result[index] = new Playlist(existing.id, existing.name, mergeTracks(existing.tracks, list.tracks));
    }
  }
  return result;
}

export function replaceOnlinePlaylists(current: Playlist[], incoming: Playlist[]): Playlist[] {
  const result: Playlist[] = incoming.map(list => {
    const local = current.find(existing => existing.id === list.id)?.tracks.filter(track => track.source === 'local') ?? [];
    return new Playlist(list.id, list.name, mergeTracks(list.tracks, local));
  });
  for (const list of current) {
    if (result.some(item => item.id === list.id)) continue;
    const local = list.tracks.filter(track => track.source === 'local');
    if (list.id === 'audio' || local.length) result.push(new Playlist(list.id, list.name, local));
  }
  return result;
}
