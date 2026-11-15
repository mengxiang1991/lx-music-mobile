import { http } from '@kit.NetworkKit';
import { Track, onlineUrl, parseSearch } from './Tracks';

interface ResolveResponse { url?: string }

async function get(url: string): Promise<string> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 8000,
      readTimeout: 10000
    });
    if (response.responseCode !== 200 || typeof response.result !== 'string') {
      throw new Error('请求失败（HTTP ' + response.responseCode + '）');
    }
    return response.result;
  } finally {
    request.destroy();
  }
}

export async function search(keyword: string): Promise<Track[]> {
  const endpoint = 'https://search.kuwo.cn/r.s?client=kt&all=' + encodeURIComponent(keyword) +
    '&pn=0&rn=30&ver=kwplayer_ar_9.2.2.1&newver=1&ft=music&cluster=0&strategy=2012&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1';
  return parseSearch(await get(endpoint));
}

export async function resolveTrack(track: Track, template: string): Promise<string> {
  if (!template || !track.songId) throw new Error('这首歌没有播放地址，可在音源页配置地址接口');
  const endpoint = template.replace(/\{source\}/g, encodeURIComponent(track.source))
    .replace(/\{id\}/g, encodeURIComponent(track.songId));
  const body = (await get(endpoint)).trim();
  const address = onlineUrl(body) ? body : (JSON.parse(body) as ResolveResponse).url;
  if (typeof address !== 'string' || !onlineUrl(address)) throw new Error('音源未返回有效的音频地址');
  return address;
}
