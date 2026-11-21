import { http } from '@kit.NetworkKit';
import { SODA_CLASSICS_ID } from './ChartCatalog';
import { Track, onlineUrl, parseChart, parseNeteaseChart, parseNeteaseSearch, parseQqChart, parseSearch,
  parseSodaChart, parseSodaClassics } from './Tracks';

interface ResolveResponse { url?: string; data?: ResolveData }
interface ResolveData { url?: string }

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

function artistKey(singer: string): string {
  return singer.normalize('NFKC').toLowerCase().split(/[、,，&/]/)
    .map(name => name.replace(/\s+/g, '')).filter(name => name).sort().join('/');
}

export async function matchSodaTrack(track: Track): Promise<Track | undefined> {
  const artists = artistKey(track.singer);
  if (!artists) return undefined;
  const title = track.name.normalize('NFKC').trim().toLowerCase();
  const keyword = track.name + ' ' + track.singer.split(' / ')[0];
  const results = await Promise.allSettled([
    get('https://music.163.com/api/search/get/web?type=1&offset=0&limit=20&s=' + encodeURIComponent(keyword))
      .then(parseNeteaseSearch),
    search(keyword)
  ]);
  for (const result of results) {
    if (result.status !== 'fulfilled') continue;
    const match = result.value.find(candidate =>
      candidate.name.normalize('NFKC').trim().toLowerCase() === title && artistKey(candidate.singer) === artists);
    if (match) return match;
  }
  return undefined;
}

export async function resolveTrack(track: Track, template: string): Promise<string> {
  if (!template || !track.songId) throw new Error('这首歌没有播放地址，可在音源页配置地址接口');
  const endpoint = template.replace(/\{source\}/g, encodeURIComponent(track.source))
    .replace(/\{id\}/g, encodeURIComponent(track.songId));
  const body = (await get(endpoint)).trim();
  if (onlineUrl(body)) return body;
  const response = JSON.parse(body) as ResolveResponse | null;
  const address = response?.url ?? response?.data?.url;
  if (typeof address !== 'string' || !onlineUrl(address)) throw new Error('音源未返回有效的音频地址');
  return address;
}

export async function loadChart(platform: string, id: string): Promise<Track[]> {
  const chartId = encodeURIComponent(id);
  if (platform === 'wy') {
    return parseNeteaseChart(await get('https://music.163.com/api/playlist/detail?id=' + chartId));
  }
  if (platform === 'tx') {
    const endpoint = 'https://c.y.qq.com/v8/fcg-bin/fcg_v8_toplist_cp.fcg?topid=' + chartId +
      '&format=json&tpl=3&page=detail&type=top';
    return parseQqChart(await get(endpoint));
  }
  if (platform === 'sd') {
    if (id === SODA_CLASSICS_ID) {
      const endpoint = 'https://api.qishui.com/luna/pc/playlist/detail?playlist_id=' + chartId +
        '&aid=386088&device_platform=windows';
      return parseSodaClassics(await get(endpoint));
    }
    return parseSodaChart(await get('https://api5-lf.qishui.com/luna/charts/' + chartId + '?charge=0'));
  }
  const endpoint = 'https://kbangserver.kuwo.cn/ksong.s?from=pc&fmt=json&pn=0&rn=30' +
    '&type=bang&data=content&pcmp4=1&isbang=1&id=' + chartId;
  return parseChart(await get(endpoint));
}
