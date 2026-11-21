export interface Chart {
  id: string;
  name: string;
}

export interface ChartPlatform {
  id: string;
  name: string;
  charts: Chart[];
}

export const SODA_CLASSICS_ID: string = '7557757394228772873';

export const CHART_PLATFORMS: ChartPlatform[] = [
  { id: 'kw', name: '酷我音乐', charts: [
    { id: '16', name: '热歌榜' }, { id: '17', name: '新歌榜' }, { id: '93', name: '飙升榜' },
    { id: '176', name: 'DJ 嗨歌榜' }, { id: '26', name: '经典老歌榜' }
  ] },
  { id: 'wy', name: '网易云音乐', charts: [
    { id: '3778678', name: '热歌榜' }, { id: '3779629', name: '新歌榜' }, { id: '19723756', name: '飙升榜' },
    { id: '2884035', name: '原创榜' }, { id: '6886768100', name: '中文 DJ 榜' }
  ] },
  { id: 'tx', name: 'QQ 音乐', charts: [
    { id: '26', name: '热歌榜' }, { id: '27', name: '新歌榜' }, { id: '62', name: '飙升榜' }
  ] },
  { id: 'sd', name: '汽水音乐', charts: [
    { id: '7036274230471712007', name: '热歌榜' }, { id: '7060812597884869927', name: '新歌榜' },
    { id: SODA_CLASSICS_ID, name: '经典老歌' }, { id: '7415959718721494311', name: '音乐人歌曲榜' }
  ] }
];
