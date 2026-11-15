import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Track } from './Tracks';
import { resolveTrack } from './Online';

export interface PlayerEvents {
  state: (state: string) => void;
  time: (position: number, duration: number) => void;
  ended: () => void;
  error: (message: string) => void;
}

export class Player {
  private generation = 0;
  private active?: media.AVPlayer;
  private file?: fs.File;
  private pending: Promise<void> = Promise.resolve();

  start(track: Track, resolver: string, events: PlayerEvents): void {
    const generation = ++this.generation;
    this.pending = this.pending.then(async () => {
      await this.close();
      if (generation !== this.generation) return;
      events.state('正在加载');
      const address = track.url || await resolveTrack(track, resolver);
      if (generation !== this.generation) return;
      const player = await media.createAVPlayer();
      this.active = player;
      if (generation !== this.generation) {
        await this.close();
        return;
      }
      const current = (): boolean => generation === this.generation && this.active === player;
      player.on('error', error => {
        if (current()) events.error('播放失败（' + error.code + '）');
      });
      player.on('timeUpdate', position => {
        if (current()) events.time(position, player.duration);
      });
      player.on('stateChange', async state => {
        if (!current()) return;
        try {
          switch (state) {
            case 'initialized':
              await player.prepare();
              break;
            case 'prepared':
              events.time(0, player.duration);
              if (current()) await player.play();
              break;
            case 'playing':
              events.state('正在播放');
              break;
            case 'paused':
              events.state('已暂停');
              break;
            case 'completed':
              events.state('播放完成');
              events.ended();
              break;
          }
        } catch (error) {
          if (current()) events.error('播放失败：' + String(error));
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

  async toggle(): Promise<void> {
    const player = this.active;
    if (player?.state === 'playing') await player.pause();
    else if (player?.state === 'paused' || player?.state === 'completed') await player.play();
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
