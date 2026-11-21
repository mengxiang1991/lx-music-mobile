import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Track } from './Tracks';

export interface PlaybackCommands {
  play: () => void;
  pause: () => void;
  next: () => void;
  previous: () => void;
  seek: (position: number) => void;
}

export class SystemPlayback {
  private session?: avSession.AVSession;
  private taskRunning: boolean = false;
  private launchAgent?: WantAgent;
  private context?: common.UIAbilityContext;
  private commands?: PlaybackCommands;
  private pending: Promise<void> = Promise.resolve();
  private asset: string = '';
  private assetId: number = 0;
  private publishedDuration: number = -1;

  bind(context: common.UIAbilityContext, commands: PlaybackCommands): void {
    this.context = context;
    this.commands = commands;
  }

  private enqueue(work: () => Promise<void>): void {
    this.pending = this.pending.then(work).catch((error: BusinessError) => {
      hilog.warn(0x1020, 'LxSystemPlayback', 'System media or background task update failed, code: %{public}d', error.code ?? 0);
    });
  }

  private async create(): Promise<avSession.AVSession | undefined> {
    const context = this.context;
    const commands = this.commands;
    if (!context || !commands) return undefined;
    const session = await avSession.createAVSession(context, '曲间拾声', 'audio');
    try {
      session.on('play', commands.play);
      session.on('pause', commands.pause);
      session.on('stop', commands.pause);
      session.on('playNext', commands.next);
      session.on('playPrevious', commands.previous);
      session.on('seek', commands.seek);
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: context.abilityInfo.bundleName, abilityName: context.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 1,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      this.launchAgent = await wantAgent.getWantAgent(info);
      await session.setLaunchAbility(this.launchAgent);
      await session.activate();
      hilog.info(0x1020, 'LxSystemPlayback', 'Media session activated');
      return session;
    } catch {
      await session.destroy();
      throw new Error('媒体会话初始化失败');
    }
  }

  publish(track: Track, state: avSession.PlaybackState, position: number, duration: number): void {
    this.enqueue(async () => {
      if (!this.session) this.session = await this.create();
      const session = this.session;
      if (!session) return;
      if (this.asset !== track.id || this.publishedDuration !== duration) {
        if (this.asset !== track.id) this.assetId++;
        await session.setAVMetadata({ assetId: String(this.assetId), title: track.name, artist: track.singer, duration: duration });
        this.asset = track.id;
        this.publishedDuration = duration;
      }
      const playing = state === avSession.PlaybackState.PLAYBACK_STATE_PLAY;
      await session.setAVPlaybackState({
        state: state,
        speed: 1,
        position: { elapsedTime: position, updateTime: Date.now() },
        duration: duration
      });
      if (playing) await this.startTask();
      else if (state !== avSession.PlaybackState.PLAYBACK_STATE_PREPARE) await this.stopTask();
    });
  }

  private async startTask(): Promise<void> {
    const context = this.context;
    const agent = this.launchAgent;
    if (!context || !agent || this.taskRunning) return;
    try {
      await backgroundTaskManager.startBackgroundRunning(context, ['audioPlayback'], agent);
      hilog.info(0x1020, 'LxSystemPlayback', 'Background audio task started');
    } catch (error) {
      const failure = error as BusinessError;
      hilog.warn(0x1020, 'LxSystemPlayback', 'Background audio task rejected: %{public}d %{public}s',
        failure.code, failure.message);
      return;
    }
    this.taskRunning = true;
  }

  private async stopTask(): Promise<void> {
    if (!this.context || !this.taskRunning) return;
    this.taskRunning = false;
    await backgroundTaskManager.stopBackgroundRunning(this.context);
  }

  dispose(): void {
    this.enqueue(async () => {
      try {
        await this.stopTask();
      } finally {
        await this.session?.destroy();
        this.session = undefined;
        this.asset = '';
        this.publishedDuration = -1;
      }
    });
  }
}
