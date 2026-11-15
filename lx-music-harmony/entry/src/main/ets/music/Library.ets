import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { zlib } from '@kit.BasicServicesKit';
import { Playlist, Track, parseBackup } from './Tracks';

const MAX_BACKUP_BYTES = 16 * 1024 * 1024;

export class LibraryData {
  favorites: Track[] = [];
  playlists: Playlist[] = [];
  resolver: string = '';
}

export class Library {
  private file: string = '';
  private audioDir: string = '';

  open(context: common.UIAbilityContext): LibraryData {
    this.file = context.filesDir + '/library.json';
    this.audioDir = context.filesDir + '/audio';
    if (!fs.accessSync(this.audioDir)) fs.mkdirSync(this.audioDir);
    if (!fs.accessSync(this.file)) return new LibraryData();
    return JSON.parse(fs.readTextSync(this.file, { encoding: 'utf-8' })) as LibraryData;
  }

  save(data: LibraryData): void {
    const temp = this.file + '.tmp';
    const file = fs.openSync(temp, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, JSON.stringify(data));
    } finally {
      fs.closeSync(file);
    }
    fs.renameSync(temp, this.file);
  }

  async pickAudio(context: common.UIAbilityContext): Promise<Track[]> {
    const selector = new picker.AudioViewPicker(context);
    const options = new picker.AudioSelectOptions();
    options.maxSelectNumber = 30;
    const uris = await selector.select(options);
    const tracks: Track[] = [];
    try {
      for (let i = 0; i < uris.length; i++) {
        const uri = uris[i];
        const name = new fileUri.FileUri(uri).name;
        const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
        const id = util.generateRandomUUID();
        const path = this.audioDir + '/' + id;
        try {
          await fs.copyFile(file.fd, path);
        } catch (error) {
          if (fs.accessSync(path)) fs.unlinkSync(path);
          throw new Error('复制音频失败，请检查存储空间');
        } finally {
          await fs.close(file);
        }
        tracks.push(new Track('local:' + id, name.replace(/\.[^.]+$/, '') || name, '本地音频', 'local', '', path));
      }
    } catch (error) {
      this.removeCopies(tracks);
      throw new Error(String(error));
    }
    return tracks;
  }

  removeCopies(tracks: Track[]): void {
    for (const track of tracks) {
      if (track.source === 'local' && track.url.startsWith(this.audioDir + '/') && fs.accessSync(track.url)) {
        fs.unlinkSync(track.url);
      }
    }
  }

  async pickBackup(context: common.UIAbilityContext): Promise<Playlist[]> {
    const selector = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['洛雪歌单|.lxmc,.json'];
    const files = await selector.select(options);
    if (!files.length) return [];
    const file = await fs.open(files[0], fs.OpenMode.READ_ONLY);
    let bytes: ArrayBuffer;
    try {
      const stat = await fs.stat(file.fd);
      if (stat.size < 1 || stat.size > MAX_BACKUP_BYTES) throw new Error('歌单文件为空或超过 16 MB');
      bytes = new ArrayBuffer(stat.size);
      const length = await fs.read(file.fd, bytes);
      if (length !== stat.size) throw new Error('歌单文件读取不完整');
    } finally {
      await fs.close(file);
    }
    const header = new Uint8Array(bytes);
    if (header[0] === 31 && header[1] === 139) bytes = await this.gunzip(bytes);
    const result = parseBackup(util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(bytes)));
    if (result.length === 0) throw new Error('歌单文件内容无效');
    return result;
  }

  private async gunzip(bytes: ArrayBuffer): Promise<ArrayBuffer> {
    const output = new ArrayBuffer(MAX_BACKUP_BYTES);
    const stream: zlib.ZStream = {
      nextIn: bytes, availableIn: bytes.byteLength, nextOut: output, availableOut: output.byteLength
    };
    const zip = await zlib.createZip();
    const init = await zip.inflateInit2(stream, 31);
    if (init !== zlib.ReturnStatus.OK) throw new Error('无法初始化歌单解压');
    try {
      const result = await zip.inflate(stream, zlib.CompressFlushMode.FINISH);
      if (result !== zlib.ReturnStatus.STREAM_END) throw new Error('歌单损坏或解压后超过 16 MB');
      return (stream.nextOut ?? output).slice(0, stream.totalOut ?? 0);
    } finally {
      await zip.inflateEnd(stream);
    }
  }
}
