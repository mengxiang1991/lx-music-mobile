export interface PresetSource {
  id: string;
  name: string;
  sha: string;
  hosts: string[];
  path?: string;
}

// Hashes pin the reviewed latest.js bytes, including when a download mirror is used.
export const PRESET_SOURCES: PresetSource[] = [
  { id: 'huibq', name: 'Huibq', sha: 'a9adeb456690b523008038224091cee31977606302d79082eb06adb3c75c9146', hosts: ['lxmusicapi.onrender.com'] },
  { id: 'huanyin', name: 'HuanYin', sha: '4a81129240ecae3ebf6b42f28c73e2d37bbcb6fccac9a73a401d90cdd36bee5f', hosts: ['api.xcvts.cn', 'music-dl.sayqz.com'] },
  { id: 'juhe', name: 'JuheApi', sha: 'f7a661f01af7ea23035d5fac3b89d7c756372fc8a64bbfd649918f8a101cbf33', hosts: ['api.music.lerd.dpdns.org'] },
  { id: 'ikun', name: 'ikun', sha: '8db6c45bc225f1f15fc2e96f7d9ad3bf2e49dd1f2a998cdf23704185ea41fe89', hosts: ['api.ikunshare.com'] },
  { id: 'changqing', name: 'ChangQing', sha: '6a942987c1e111a113376fbf8ff9fb677c487058f16ce792779c72f69c4ed6de', hosts: ['13413.kstore.vip', 'yinyue.haitangw.net'] },
  { id: 'feichangdao', name: 'FeiChangDao', sha: '49486cab064e64d5ad63723e670c44ee55eadadcc790ccf493351fbde64284d7', hosts: ['api-vehicle.volcengine.com', 'api.chksz.top', 'api.qishui.com', 'api.xcvts.cn', 'cp.chksz.top', 'music-api.gdstudio.xyz', 'music.haitangw.cc', 'music.nxinxz.com', 'musicapi.haitangw.net', 'oiapi.net'] },
  { id: 'fish', name: 'Fish', sha: 'a711e152c4f28c32fd46b38839a70f476e0b669905773a90e2ce63246136af47', hosts: ['m-api.ceseet.me'] },
  { id: 'flower', name: 'Flower', sha: '15c166987edde41cf5917b3160c0ab253ff17e5e6bc6765c9eaa11a822c4aa97', hosts: [] },
  { id: 'grass', name: 'Grass', sha: 'd694275f382427d3fef809fc77338ef014dc330af710cca6b3233ece8740510f', hosts: [] },
  { id: 'helloworld', name: 'HelloWorld', sha: '12d7a289647b4f4ff8b94d4b27d06a55b7ca9b9be6ac89c602cac2052eced723', hosts: ['a.aa.cab', 'c.wwwweb.top', 'mcp.nianxinxz.com', 'musicserver.haitangw.cc', 'nmobi.kuwo.cn', 'oiapi.net', 'tang.api.s01s.cn', 'yy.zddyr.top'] },
  { id: 'hyw', name: 'HYW', sha: '0f48bdab4205e4423397f970b926565085a5af4f3b8a8a19f4cdc0e755647cd5', hosts: [] },
  { id: 'jiexiang', name: 'JieXiang', sha: 'a4f25710ea8c993e20626df2345fb933607eb4b91b794bd323f954e7085b94df', hosts: ['88.lxmusic.xn--fiqs8s', 'api-v2.yuafeng.cn', 'api.317ak.cn', 'api.bugpk.com', 'api.canxiang.cn', 'api.cenguigui.cn', 'api.chksz.top', 'api.liuyunidc.cn', 'api.music.lerd.dpdns.org', 'api.nki.pw', 'api.vkeys.cn', 'api.vsaa.cn', 'api.xcvts.cn', 'api.xinghai-backend.cn', 'api.xinghai.com', 'api.yaohud.cn', 'api.ygking.cn', 'api.yunmge.com', 'app.c.nf.migu.cn', 'c.wwwweb.top', 'cp.chksz.top', 'cyapi.top', 'dl.stream.qqmusic.qq.com', 'interface3.music.163.com', 'isure.stream.qqmusic.qq.com', 'lxmusicapi.onrender.com', 'mcp.nianxinxz.com', 'mobi.kuwo.cn', 'music-api.gdstudio.xyz', 'music.163.com', 'music.haitangw.cc', 'music.migu.cn', 'music.nxinxz.com', 'musicapi.haitangw.net', 'musicserver.haitangw.cc', 'nmobi.kuwo.cn', 'oiapi.net', 'qm.qq.com', 'source.shiqianjiang.cn', 'tang.api.s01s.cn', 'u.y.qq.com', 'ut.y.qq.com', 'www.kugou.com', 'wwwapi.kugou.com', 'wyapi.toubiec.cn', 'y.qq.com', 'yy.zddyr.top', 'zrcdy.dpdns.org'] },
  { id: 'lx', name: 'LX', sha: '79a5c4703e060eaff6f8ffaac05d2fadf5e22b7729f6fe151d1cca2fa3935171', hosts: ['88.lxmusic.xn--fiqs8s'] },
  { id: 'qdy', name: 'QDY', sha: '213f73232562b528826dd97601e74212b517014e06fd614b28d8d8aa0dda400c', hosts: ['api.huibq.com', 'api.lingchuan.com', 'api.vsaa.cn', 'api.xcvts.cn', 'music-api.gdstudio.xyz', 'music-dl.sayqz.com', 'music.haitangw.cc', 'music.nxinxz.com', 'musicapi.haitangw.net', 'oiapi.net', 'proxy.qishui.vsaa.cn'] },
  { id: 'qingliang', name: 'QingLiang', sha: 'f5d589c4ebe583800b25fe12e35dfd4f807f1758bfbea83054df4b9a4f95aa29', hosts: ['api.bileizhen.top', 'api.xunhuisi.store', 'api.yutangxiaowu.cn', 'c.wwwweb.top', 'ffapi.cn', 'm.kugou.com', 'metings.qjqq.cn', 'music-api.gdstudio.xyz', 'music.163.com', 'music.lzmhhh.com', 'ncm.kangqiovo.com', 'nmobi.kuwo.cn', 'search.kuwo.cn', 'www.kugou.com', 'wwwapi.kugou.com'] },
  { id: 'sixyin', name: 'SixYin', sha: 'a407ffe0ab23c29cd32ce249b83e61c8e2b70719895f16034566ad7557282785', hosts: [] },
  { id: 'suyin', name: 'SuYin', sha: 'd10c9c28823b5c2ce4e3fef3b25b8ff16d2d165bd0883e2b866900ef7c0dc0ee', hosts: ['api.xcvts.cn', 'oiapi.net'] },
  { id: 'xinghai', name: 'XingHai', sha: 'd2f72c5c0dde51fbaa32c9ca5c634a1ae43eafa952abc1e5a83dab4f578487ab', hosts: ['gc.kxwa.top', 'yy.zddyr.top', 'zddyr.top'] },
  { id: 'xinglan', name: 'XingLan', sha: 'd186346cec8f813dc447bebcc4d5a29a5ad41f62c90102edb196d67cc870eaf2', hosts: ['api.vkeys.cn', 'c.wwwweb.top', 'ffapi.cn', 'music.163.com', 'music.migu.cn', 'musicserver.haitangw.cc', 'qt.haitangw.net', 'www.kugou.com', 'www.kuwo.cn', 'y.qq.com', 'yy.zddyr.top'] },
  { id: 'yuningxi', name: 'YuNingXi', sha: '5dd4752c16c17f7bab45dccf87dcd3f3c2a6e251e62bad68bde9554bfd275f79', hosts: [] },
  {
    id: 'hei', name: 'Hei Music', sha: '00c9bdbd57512d22d17874ccd7a0c079ca5ea9b1dee2dd4b861f1c44c42549c8',
    path: 'shellsec/lx-music-source/056fd55eec992c001ecbad3218c032b138af50dc/sources/hei/Hei%20Music%E8%81%9A%E5%90%88%E6%BA%90.js',
    hosts: ['a.aa.cab', 'api-v2.yuafeng.cn', 'api.cenguigui.cn', 'api.vkeys.cn', 'app.c.nf.migu.cn',
      'app.u.nf.migu.cn', 'c.wwwweb.top', 'cyapi.top', 'dl.stream.qqmusic.qq.com', 'mcp.nianxinxz.com',
      'music-api.gdstudio.xyz', 'music.migu.cn', 'musicserver.haitangw.cc', 'oiapi.net', 'tang.api.s01s.cn',
      'ut.y.qq.com', 'yy.zddyr.top']
  },
  {
    id: 'luanmuc', name: '豆包定制', sha: 'b81443617054c9ca5669bf4163a5679cb0354bfa3a03c6c033f431a068e80e15',
    path: 'luanmuc/backend-api/dd8cd91ef5c10aae36c8332b64b06c77e3ad6976/lx-source.js',
    hosts: ['antiserver.kuwo.cn', 'api.lingchuan.com', 'api.music.lerd.dpdns.org', 'api.xcvts.cn',
      'c.wwwweb.top', 'c.y.qq.com', 'lxmusicapi.onrender.com', 'music-api.gdstudio.xyz', 'music.163.com',
      'music.lzmhhh.com', 'musicapi.haitangw.net', 'musicserver.haitangw.cc', 'nmobi.kuwo.cn', 'oiapi.net',
      'search.kuwo.cn', 'y.qq.com', 'yy.zddyr.top']
  },
];

const REPOSITORY = 'pdone/lx-music-source/ed8328dbd1a77aee3ee0116d835eb9d907eeaad2/';
export const DOWNLOAD_MIRRORS: string[] = [
  '', 'gh-proxy.org/', 'gh.llkk.cc/', 'github.moeyy.xyz/', 'ghproxy.cn/',
  'gh.api.99988866.xyz/', 'ghp.ci/', 'ghproxy.net/'
];

export function downloadAddress(source: PresetSource, mirror: string): string {
  return 'https://' + mirror + 'raw.githubusercontent.com/' + (source.path ?? REPOSITORY + source.id + '/latest.js');
}
