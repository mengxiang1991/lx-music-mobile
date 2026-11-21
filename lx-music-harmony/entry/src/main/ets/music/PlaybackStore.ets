import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Track } from './Tracks';
import { PlaybackMode } from './PlaybackOrder';

const HISTORY_LIMIT: number = 100;

export function rememberPlayed(history: Track[], track: Track): Track[] {
  return [track, ...history.filter(item => item.id !== track.id)].slice(0, HISTORY_LIMIT);
}

export class PlaybackSnapshot {
  queue: Track[] = [];
  index: number = -1;
  elapsed: number = 0;
  duration: number = 0;
  mode: PlaybackMode = PlaybackMode.Sequential;
  shuffled: number[] = [];
}

export class PlaybackStore {
  private path: string = '';
  private historyPath: string = '';

  open(context: common.UIAbilityContext): PlaybackSnapshot | undefined {
    this.path = context.filesDir + '/playback.json';
    this.historyPath = context.filesDir + '/playback-history.json';
    if (!fs.accessSync(this.path)) return undefined;
    const state = JSON.parse(fs.readTextSync(this.path, { encoding: 'utf-8' })) as PlaybackSnapshot;
    if (!Array.isArray(state.queue) || !Number.isInteger(state.index) || !state.queue[state.index] ||
      !Number.isFinite(state.elapsed) || !Number.isFinite(state.duration) ||
      !Number.isInteger(state.mode) || state.mode < PlaybackMode.Sequential || state.mode > PlaybackMode.Shuffle) {
      return undefined;
    }
    state.duration = Math.max(0, state.duration);
    state.elapsed = Math.max(0, Math.min(state.elapsed, state.duration));
    return state;
  }

  save(state: PlaybackSnapshot): void {
    this.write(this.path, JSON.stringify(state));
  }

  openHistory(): Track[] {
    if (!this.historyPath || !fs.accessSync(this.historyPath)) return [];
    const history = JSON.parse(fs.readTextSync(this.historyPath, { encoding: 'utf-8' })) as Track[];
    if (!Array.isArray(history)) return [];
    return history.filter(track => track && typeof track.id === 'string' && track.id &&
      typeof track.name === 'string' && typeof track.singer === 'string' && typeof track.source === 'string' &&
      typeof track.songId === 'string' && typeof track.url === 'string').slice(0, HISTORY_LIMIT);
  }

  saveHistory(history: Track[]): void {
    this.write(this.historyPath, JSON.stringify(history));
  }

  private write(path: string, data: string): void {
    if (!path) return;
    const temp = path + '.tmp';
    const file = fs.openSync(temp, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, data);
    } finally {
      fs.closeSync(file);
    }
    fs.renameSync(temp, path);
  }
}
