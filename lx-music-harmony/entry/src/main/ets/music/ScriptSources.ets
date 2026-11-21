import { webview } from '@kit.ArkWeb';
import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { deviceInfo } from '@kit.BasicServicesKit';
import { Track, onlineUrl } from './Tracks';
import { matchSodaTrack, resolveTrack } from './Online';
import { downloadAddress, DOWNLOAD_MIRRORS, PRESET_SOURCES, PresetSource } from './SourceCatalog';

interface TrackInput {
  id: string;
  songmid: string;
  name: string;
  singer: string;
  source: string;
  hash?: string;
  meta: ScriptMeta;
}
interface ScriptMeta { songId: string; albumName: string }
interface JobInput { kind: string; code: string; source: string; track: TrackInput }
interface ScriptOptions { method?: string; headers?: Record<string, string>; body?: string | Object; form?: Record<string, string> }
interface ScriptMessage { kind: string; id?: number; url?: string; options?: ScriptOptions }
interface ScriptReply { id: number; status?: number; body?: string; headers?: Object; error?: string }

export class ResolvedSource {
  id: string;
  name: string;
  url: string;
  constructor(id: string, name: string, url: string) {
    this.id = id;
    this.name = name;
    this.url = url;
  }
}

function validHost(address: string): string {
  return address.match(/^https:\/\/([a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:[a-z]{2,}|xn--[a-z0-9-]+))(?::443)?(?:[/?#]|$)/i)?.[1]
    ?.toLowerCase() ?? '';
}

export class ScriptSources {
  private controller: webview.WebviewController = new webview.WebviewController();
  private ready: boolean = false;
  private serial: number = 0;
  private lastGood: string = '';
  private mirror: string = '';
  private readonly scripts: Map<string, string> = new Map();
  private readonly unavailable: Map<string, number> = new Map();

  webController(): webview.WebviewController {
    return this.controller;
  }

  pageReady(): void {
    this.ready = true;
  }

  remember(id: string): void {
    this.lastGood = id;
  }

  async resolve(track: Track, preferred: string, templates: string[], alive: () => boolean,
    excluded: string[], preferScripts: boolean): Promise<ResolvedSource> {
    if (!track.songId) throw new Error('这首歌没有可供音源匹配的歌曲 ID');
    if (track.source === 'sd') {
      const result = await this.resolveTemplates(track, preferred, templates, alive, excluded);
      if (result) return result;
      if (!alive()) throw new Error('播放已取消');
      const match = await matchSodaTrack(track);
      if (!match) throw new Error('当前音源未找到这首汽水歌曲的同版本');
      return this.resolve(match, preferred, templates, alive, excluded, preferScripts);
    }
    if (!preferScripts || deviceInfo.sdkApiVersion < 23) {
      const result = await this.resolveTemplates(track, preferred, templates, alive, excluded);
      if (result) return result;
    }
    if (deviceInfo.sdkApiVersion < 23) throw new Error('当前系统可使用 HTTPS 地址模板');
    for (let attempt = 0; !this.ready && attempt < 20 && alive(); attempt++) await this.delay(100);
    if (!this.ready && !preferScripts) throw new Error('脚本音源暂未就绪');
    const ordered = [...PRESET_SOURCES];
    const known = ordered.findIndex(source => source.id === this.lastGood);
    if (known > 0) ordered.unshift(ordered.splice(known, 1)[0]);
    for (let i = 0; i < ordered.length && this.ready && alive(); i += 3) {
      const group = ordered.slice(i, i + 3).filter(source =>
        !excluded.includes(source.id) && (this.unavailable.get(source.id) ?? 0) <= Date.now());
      if (!group.length) continue;
      let done = false;
      try {
        return await Promise.any(group.map(source => this.run(source, track, () => alive() && !done)));
      } catch {
        if (!alive()) break;
      } finally {
        done = true;
      }
    }
    if (preferScripts) {
      const result = await this.resolveTemplates(track, preferred, templates, alive, excluded);
      if (result) return result;
    }
    throw new Error('所有音源均未返回可播放地址');
  }

  private async resolveTemplates(track: Track, preferred: string, templates: string[], alive: () => boolean,
    excluded: string[]): Promise<ResolvedSource | undefined> {
    const configured = Array.from(new Set([preferred, ...templates].filter(item => item)));
    for (const template of configured) {
      if (!alive()) throw new Error('播放已取消');
      const id = 'template:' + (track.source === 'sd' ? 'sd:' : '') + configured.indexOf(template);
      if (excluded.includes(id)) continue;
      try {
        return new ResolvedSource(id, '自定义接口', await resolveTrack(track, template));
      } catch {
        // Try the next configured address.
      }
    }

    return undefined;
  }

  private async download(source: PresetSource, alive: () => boolean): Promise<string> {
    const cached = this.scripts.get(source.id);
    if (cached) return cached;
    const mirrors = Array.from(new Set([this.mirror, ...DOWNLOAD_MIRRORS]));
    for (let index = 0; index < mirrors.length && alive(); index += index === 0 ? 1 : 3) {
      try {
        const choices = mirrors.slice(index, index + (index === 0 ? 1 : 3));
        return await Promise.any(choices.map(async mirror => {
          const request = http.createHttp();
          try {
            const response = await request.request(downloadAddress(source, mirror), {
              expectDataType: http.HttpDataType.ARRAY_BUFFER,
              connectTimeout: 2400, readTimeout: 3200, maxLimit: 1024 * 1024, maxRedirects: 0,
              usingProxy: false
            });
            if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) {
              throw new Error('无法下载脚本');
            }
            const bytes = new Uint8Array(response.result);
            const md = cryptoFramework.createMd('SHA256');
            await md.update({ data: bytes });
            const digest = await md.digest();
            const hex = Array.from(digest.data).map(value => value.toString(16).padStart(2, '0')).join('');
            if (hex !== source.sha) throw new Error('音源脚本与已审核版本不一致');
            const script = util.TextDecoder.create('utf-8').decodeToString(bytes);
            this.scripts.set(source.id, script);
            this.mirror = mirror;
            return script;
          } finally {
            request.destroy();
          }
        }));
      } catch {
        // Try the remaining mirrors with the same integrity check.
      }
    }
    if (alive()) this.unavailable.set(source.id, Date.now() + 120000);
    throw new Error('无法获取音源脚本');
  }

  private async run(source: PresetSource, track: Track, alive: () => boolean): Promise<ResolvedSource> {
    const code = await this.download(source, alive);
    if (!alive()) throw new Error('播放已取消');
    const id = ++this.serial;
    const input: JobInput = {
      kind: 'start', code: code, source: track.source,
      track: { id: track.id, songmid: track.songId, hash: track.source === 'kg' ? track.songId : undefined,
        name: track.name, singer: track.singer, source: track.source, meta: { songId: track.songId, albumName: '' } }
    };
    const web = this.controller;
    let requests = 0;
    try {
      const ready = await web.runJavaScript('window.lxStart(' + id + ',' + JSON.stringify(input) + ')');
      if (ready !== 'true') throw new Error('音源运行环境未启动');
      const deadline = Date.now() + 6500;
      while (Date.now() < deadline && alive()) {
        const reply = await web.runJavaScript('window.lxPoll(' + id + ')');
        const messages = JSON.parse(JSON.parse(reply) as string) as ScriptMessage[];
        for (const message of messages) {
          if (message.kind === 'result') {
            const address = message.url ?? '';
            if (!/^https?:\/\/[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}(?:[/?#]|$)/i.test(address) ||
              address.length > 4096 || !onlineUrl(address)) throw new Error('音源未返回播放地址');
            return new ResolvedSource(source.id, source.name, address);
          }
          if (message.kind === 'request' && message.id !== undefined && requests++ < 12) {
            void this.relay(source, id, message, alive);
          }
        }
        await this.delay(100);
      }
      throw new Error('音源请求超时');
    } finally {
      try { await web.runJavaScript('window.lxStop(' + id + ')'); } catch {}
    }
  }

  private async relay(source: PresetSource, job: number, message: ScriptMessage, alive: () => boolean): Promise<void> {
    const requestId = message.id ?? 0;
    let reply: ScriptReply;
    try {
      const address = message.url ?? '';
      if (!alive() || address.length > 4096 || !source.hosts.includes(validHost(address))) {
        throw new Error('音源请求地址不受支持');
      }
      const request = http.createHttp();
      try {
        const spec = message.options;
        const method = (spec?.method ?? 'GET').toUpperCase();
        if (method !== 'GET' && method !== 'POST') throw new Error('不支持该请求方法');
        const headers: Record<string, string> = {};
        const incoming: Record<string, string> = spec?.headers ?? {};
        for (const key of Object.keys(incoming)) {
          if (!/^[a-z0-9-]{1,64}$/i.test(key) || /^(cookie|host|connection|origin|content-length)$/i.test(key)) continue;
          const value = incoming[key];
          if (typeof value === 'string' && value.length < 2048 && !/[\r\n]/.test(value)) headers[key] = value;
        }
        let body = spec?.body;
        const form = spec?.form;
        if (!body && form) {
          body = Object.keys(form).map(key => encodeURIComponent(key) + '=' + encodeURIComponent(form[key])).join('&');
          headers['Content-Type'] = 'application/x-www-form-urlencoded';
        }
        if (body && JSON.stringify(body).length > 65536) throw new Error('请求参数过长');
        const result = await request.request(address, {
          method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
          header: headers, extraData: body, expectDataType: http.HttpDataType.STRING,
          connectTimeout: 3200, readTimeout: 4200, maxLimit: 1024 * 1024, maxRedirects: 0,
          usingProxy: false
        });
        reply = { id: requestId, status: result.responseCode, body: result.result as string, headers: result.header };
      } finally {
        request.destroy();
      }
    } catch {
      reply = { id: requestId, error: '音源请求失败' };
    }
    if (!alive()) return;
    try {
      await this.controller.runJavaScript('window.lxReply(' + job + ',' + JSON.stringify(reply) + ')');
    } catch {}
  }

  private async delay(milliseconds: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, milliseconds));
  }
}
