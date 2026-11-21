import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Track } from './Tracks';
import { ResolvedSource } from './ScriptSources';

export interface PlayerEvents {
  state: (state: string) => void;
  time: (position: number, duration: number) => void;
  ended: () => void;
  resumeFailed: () => void;
  sourceReady: (source: ResolvedSource) => void;
  error: (message: string) => void;
}

export type SourceLookup = (alive: () => boolean, excluded: string[]) => Promise<ResolvedSource>;

export class Player {
  private generation = 0;
  private active?: media.AVPlayer;
  private file?: fs.File;
  private pending: Promise<void> = Promise.resolve();

  start(track: Track, resolve: SourceLookup, events: PlayerEvents, resumePosition: number = 0, excluded: string[] = []): void {
    const generation = ++this.generation;
    this.pending = this.pending.then(async () => {
      await this.close();
      if (generation !== this.generation) return;
      events.state('正在加载');
      const source = track.url ? undefined : await resolve(() => generation === this.generation, excluded);
      const address = source?.url ?? track.url;
      if (generation !== this.generation) return;
      const player = await media.createAVPlayer();
      this.active = player;
      if (generation !== this.generation) {
        await this.close();
        return;
      }
      const current = (): boolean => generation === this.generation && this.active === player;
      let started = false;
      const fail = (message: string): void => {
        if (!current()) return;
        if (!started && source) this.start(track, resolve, events, resumePosition, [...excluded, source.id]);
        else events.error(message);
      };
      player.on('error', error => fail('播放失败（' + error.code + '）'));
      if (source) {
        setTimeout(() => {
          if (!started) fail('音源加载超时');
        }, 12000);
      }
      let resumeTarget: number = 0;
      let resumeSeeking: boolean = false;
      const progress = (position: number): void => {
        if (!current()) return;
        if (resumeSeeking && Math.abs(resumeTarget - position) > 3000) return;
        if (resumeSeeking) {
          resumeSeeking = false;
          resumeTarget = 0;
        }
        events.time(position, player.duration);
      };
      player.on('timeUpdate', progress);
      player.on('seekDone', progress);
      player.on('stateChange', async state => {
        if (!current()) return;
        try {
          switch (state) {
            case 'initialized':
              await player.prepare();
              break;
            case 'prepared':
              resumeTarget = resumePosition > 0 && resumePosition < player.duration ? resumePosition : 0;
              events.time(resumeTarget, player.duration);
              if (current()) await player.play();
              break;
            case 'playing':
              if (!started && source) events.sourceReady(source);
              started = true;
              if (resumeTarget > 0 && !resumeSeeking) {
                resumeSeeking = true;
                try {
                  player.seek(resumeTarget, media.SeekMode.SEEK_PREV_SYNC);
                  setTimeout(() => {
                    if (!current() || !resumeSeeking || player.state !== 'playing') return;
                    events.resumeFailed();
                    this.start(track, resolve, events);
                  }, 8000);
                } catch {
                  resumeSeeking = false;
                  resumeTarget = 0;
                  events.resumeFailed();
                }
              }
              events.state('正在播放');
              break;
            case 'paused':
              if (resumeSeeking) {
                resumeSeeking = false;
                resumeTarget = 0;
              }
              events.state('已暂停');
              break;
            case 'completed':
              events.state('播放完成');
              events.ended();
              break;
          }
        } catch (error) {
          fail('播放失败：' + String(error));
        }
      });
      if (track.source === 'local') {
        this.file = await fs.open(address, fs.OpenMode.READ_ONLY);
        if (!current()) {
          await this.close();
          return;
        }
        player.url = 'fd://' + this.file.fd;
      } else {
        player.url = address;
      }
    }).catch(async (error: Error) => {
      if (generation !== this.generation) return;
      await this.close();
      if (generation === this.generation) events.error(error.message || '无法播放');
    });
  }

  async resume(): Promise<void> {
    const player = this.active;
    if (player?.state === 'paused' || player?.state === 'completed') await player.play();
  }

  async pause(): Promise<void> {
    const player = this.active;
    if (player?.state === 'playing') await player.pause();
  }

  seek(position: number): void {
    const player = this.active;
    if (player?.state === 'playing' || player?.state === 'paused' || player?.state === 'completed') {
      player.seek(position, media.SeekMode.SEEK_CLOSEST);
    }
  }

  release(): void {
    this.generation++;
    this.pending = this.pending.then(() => this.close());
  }

  private async close(): Promise<void> {
    const player = this.active;
    const file = this.file;
    this.active = undefined;
    this.file = undefined;
    try {
      await player?.release();
    } catch {
      // A failed player can already have released its native instance.
    }
    try {
      if (file) await fs.close(file);
    } catch {
      // The handle is no longer used by this controller.
    }
  }
}
